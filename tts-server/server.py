#!/usr/bin/env python3
import base64
import io
import json
import hashlib
import ipaddress
import math
import os
import queue
import re
import secrets
import socket
import sqlite3
import struct
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DATA = os.environ.get('TTS_DATA', '/data')
PORT = int(os.environ.get('TTS_PORT', '8000'))
DEFAULT_BASE = os.environ.get('TTS_BASE_URL', 'https://api.xiaomimimo.com')
DEFAULT_PROVIDER = os.environ.get('TTS_PROVIDER', 'mimo').strip().lower()
DEFAULT_HOST = urllib.parse.urlsplit(DEFAULT_BASE).hostname
DB = os.path.join(DATA, 'jobs.sqlite3')
# Optional server-stored upstream key. When a client omits the Authorization
# header, requests fall back to this key so callers need not carry one.
# Precedence: env TTS_UPSTREAM_KEY, else the /data/upstream_key file (re-read
# per use so the key can be rotated by editing the file, no restart needed).
UPSTREAM_KEY_ENV = os.environ.get('TTS_UPSTREAM_KEY', '').strip()
UPSTREAM_KEY_FILE = os.path.join(DATA, 'upstream_key')
# Diagnostics collector: the app POSTs buffered playback telemetry to
# /nvr/collect so locked-screen playback failures can be inspected server-side.
# Gated by a shared token matching the client's built-in default. Diagnostic
# metadata only (playback state, error types, timestamps) — never book text or
# secrets — so the token is not sensitive. Overridable via TTS_TELEMETRY_TOKEN.
TELEMETRY_TOKEN = os.environ.get(
    'TTS_TELEMETRY_TOKEN', 'zBoaef6P9R9MQV39ZVE7Kolh6NaLuURo').strip()
DIAG_DIR = os.path.join(DATA, 'diagnostics')
DIAG_LOG = os.path.join(DIAG_DIR, 'events.jsonl')
DIAG_LOCK = threading.Lock()
WORK = queue.Queue()
STOP = object()

def db():
    c = sqlite3.connect(DB, timeout=30)
    c.row_factory = sqlite3.Row
    return c

def init_db():
    os.makedirs(DATA, exist_ok=True)
    os.makedirs(DIAG_DIR, exist_ok=True)
    with db() as c:
        c.execute('''CREATE TABLE IF NOT EXISTS jobs (
            id TEXT PRIMARY KEY, status TEXT NOT NULL, total INTEGER NOT NULL,
            completed INTEGER NOT NULL DEFAULT 0, error TEXT, created INTEGER NOT NULL,
            model TEXT, voice TEXT, fmt TEXT, speed REAL)''')
        c.execute('''CREATE TABLE IF NOT EXISTS segments (
            job_id TEXT NOT NULL, idx INTEGER NOT NULL, text TEXT NOT NULL,
            status TEXT NOT NULL, error TEXT, PRIMARY KEY(job_id, idx))''')

# Completed jobs are retained on disk for a while (so recently-synthesized
# segments can be re-fetched), then their audio files are purged to keep the
# data volume from growing without bound. The SQLite rows are kept for history.
JOB_RETENTION_SECONDS = int(os.environ.get('TTS_JOB_RETENTION', str(7 * 24 * 3600)))

def cleanup_old_jobs():
    """Removes audio files of completed jobs older than JOB_RETENTION_SECONDS.

    Called opportunistically after each new job is created; cheap (a single
    indexed query) and idempotent. Never touches in-flight jobs, and never
    fails synthesis: any error is swallowed.
    """
    try:
        cutoff = int(time.time()) - JOB_RETENTION_SECONDS
        with db() as c:
            stale = c.execute(
                'SELECT id FROM jobs WHERE status=? AND created < ?',
                ('completed', cutoff),
            ).fetchall()
        for row in stale:
            path = os.path.join(DATA, 'jobs', row['id'])
            if os.path.isdir(path):
                for name in os.listdir(path):
                    try:
                        os.unlink(os.path.join(path, name))
                    except OSError:
                        pass
                try:
                    os.rmdir(path)
                except OSError:
                    pass
    except Exception:
        # Cleanup is best-effort; never let it break job creation or synthesis.
        pass

def stored_upstream_key():
    if UPSTREAM_KEY_ENV:
        return UPSTREAM_KEY_ENV
    try:
        with open(UPSTREAM_KEY_FILE, 'r') as f:
            return f.read().strip()
    except OSError:
        return ''

def telemetry_ok(provided):
    # Constant-time compare; an empty configured token disables the collector.
    return bool(TELEMETRY_TOKEN) and bool(provided) and secrets.compare_digest(provided, TELEMETRY_TOKEN)

def split_text(text, limit):
    endings = '。！？!?；;'
    sentences, start = [], 0
    for i, ch in enumerate(text):
        if ch in endings:
            sentences.append(text[start:i + 1]); start = i + 1
    if start < len(text): sentences.append(text[start:])
    out, buf = [], ''
    for s in sentences:
        if len(s) > limit:
            if buf: out.append(buf); buf = ''
            out.extend(s[i:i + limit] for i in range(0, len(s), limit))
        elif len(buf) + len(s) <= limit: buf += s
        else: out.append(buf); buf = s
    if buf: out.append(buf)
    return out

# ---- Chinese number normalization -------------------------------------------
# TTS engines otherwise read ASCII digits with English pronunciation (e.g. 123
# becomes "one hundred twenty-three"). Rewrite them as a Chinese narrator
# would: 123 -> 一百二十三, 1990年 -> 一九九零年, 3.14 -> 三点一四, 50% -> 百分之五十.
# Idempotent: the output contains no ASCII digits, so it is safe for a client
# that already normalized the text to send it again.
_CN_DIGITS = '零一二三四五六七八九'
_CN_SMALL_UNITS = ('', '十', '百', '千')
_CN_BIG_UNITS = ('', '万', '亿')

def _cn_section(n):
    """1-9999 block: 1 -> 一, 10 -> 十, 15 -> 十五, 101 -> 一百零一."""
    if n < 10:
        return _CN_DIGITS[n]
    if n < 20:
        return '十' if n == 10 else '十' + _CN_DIGITS[n % 10]
    s = str(n)
    out = []
    for i, ch in enumerate(s):
        d = int(ch)
        place = len(s) - 1 - i
        if d == 0:
            if any(c != '0' for c in s[i + 1:]):
                if not out or out[-1] != '零':
                    out.append('零')
        else:
            out.append(_CN_DIGITS[d])
            if place > 0:
                out.append(_CN_SMALL_UNITS[place])
    return ''.join(out)

def _cn_int(value):
    if value == 0:
        return '零'
    if value < 0:
        return '负' + _cn_int(-value)
    raw = str(value)
    if len(raw) > 12:
        return ''.join(_CN_DIGITS[int(c)] for c in raw)
    sections = []
    while value > 0:
        sections.append(value % 10000)
        value //= 10000
    parts = []
    for idx in range(len(sections) - 1, -1, -1):
        section = sections[idx]
        if section == 0:
            if any(s != 0 for s in sections[:idx]) and parts and not parts[-1].endswith('零'):
                parts.append('零')
            continue
        need_zero = bool(parts) and section < 1000 and not parts[-1].endswith('零')
        parts.append(('零' if need_zero else '') + _cn_section(section) + _CN_BIG_UNITS[idx])
    return ''.join(parts)

def _cn_digits(digits):
    return ''.join(_CN_DIGITS[int(c)] for c in digits)

def _cn_number(value):
    if '.' in value:
        whole, frac = value.split('.', 1)
        return _cn_int(int(whole)) + '点' + _cn_digits(frac)
    return _cn_int(int(value))

def normalize_cn_text(text):
    if not text:
        return text
    # 省略号(……或 3+ 个点)统一为破折号——TTS 看到纯停顿符不会再发出拟声音
    text = re.sub(r'\.{3,}|…{2,}', '——', text)
    # 叠字压缩:3+ 个连续同字(如嗖嗖嗖、啊啊啊)→ 2 个,
    # 避免 TTS 拉长或拟声化
    text = re.sub(r'([\u4e00-\u9fa5])\1{2,}', lambda m: m.group(1) * 2, text)
    text = re.sub(r'(\d+(?:\.\d+)?)%', lambda m: '百分之' + _cn_number(m.group(1)), text)
    text = re.sub(r'\d+\.\d+', lambda m: _cn_number(m.group(0)), text)
    text = re.sub(r'(\d{4})年', lambda m: _cn_digits(m.group(1)) + '年', text)
    text = re.sub(r'-?\d+', lambda m: _cn_int(int(m.group(0))), text)
    return text

# ---- Content classification -------------------------------------------------
# Some book paragraphs are not worth speaking out loud:
#   - Pure punctuation / whitespace (e.g. "……", "——", "   ").
#   - Single-character SFX (e.g. "哔！", "轰", "啊") - the TTS engine tends
#     to play these with an exaggerated burst that overwhelms the surrounding
#     narration. Returning a short silent clip and marking the segment
#     'silent' keeps the cursor advancing and the playback flow steady.
_SILENT_RE = re.compile(r'[\s\W_]+', re.UNICODE)
# Whitelist of interjections and onomatopoeia whose TTS bursts sound jarring
# (loud, long, with reverb) compared to the surrounding narration. Anything
# not in this set is treated as real prose and synthesised normally, so words
# like "你好" or "哈哈" - in context - are still spoken.
_SFX_WHITELIST = frozenset({
    '啊', '呀', '哦', '嗯', '唉', '哎', '呕', '喔', '诶', '呜', '呵', '嘿', '哼',
    '哔', '轰', '砰', '咚', '啪', '嗖', '嘶', '咻', '哧', '鸣', '嘀', '嗒', '嘭',
    '嗞', '嘎', '咔', '嗨', '嚯', '吼', '啸', '唰',
})

def _is_silent_text(text):
    """True for paragraphs that are only punctuation, dashes, or whitespace."""
    if not text:
        return True
    return not _SILENT_RE.sub('', text)

def _is_short_sfx_text(text):
    """True for short paragraphs whose body is a whitelisted SFX / interjection.

    The TTS engine tends to dramatise single-character onomatopoeia with a
    loud, long burst. Replacing the body with a short silent clip removes
    the jolt while still advancing the cursor. Real prose (e.g. "你好",
    "哈哈" as a name) is left to the TTS to read.
    """
    if not text:
        return False
    stripped = text.strip()
    core = _SILENT_RE.sub('', stripped)
    if not core or len(core) > 2:
        return False
    return core in _SFX_WHITELIST

# Pre-render a 0.5 s mono 16 kHz 16-bit silent WAV. Used as the audio body for
# 'silent' segments so the client keeps advancing without a jarring gap or a
# stylised SFX that overpowers the surrounding narration.
_SILENT_WAV_CACHE = None

def _silent_wav_bytes():
    global _SILENT_WAV_CACHE
    if _SILENT_WAV_CACHE is not None:
        return _SILENT_WAV_CACHE
    buf = io.BytesIO()
    with wave.open(buf, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(16000)
        w.writeframes(b'\x00\x00' * 8000)  # 0.5 s
    _SILENT_WAV_CACHE = buf.getvalue()
    return _SILENT_WAV_CACHE

# ---- WAV loudness normalisation ---------------------------------------------
# Different TTS providers / voices return wildly different perceived volumes:
# a whispery passage can be near-silent, while a single "啊!" can clip. The
# coordinator stitches the segments back-to-back, so a loud segment right
# after a quiet one sounds like the volume "suddenly jumped". We normalise
# each WAV to a target RMS while capping the gain to avoid pumping noise, and
# also clip the peak to 0.95 to remove harsh transients.
def _normalize_wav(data, target_rms=0.05, max_gain_db=12.0, peak_clip=0.95):
    if not data or len(data) < 64:
        return data
    try:
        with wave.open(io.BytesIO(data), 'rb') as w:
            channels = w.getnchannels()
            sampwidth = w.getsampwidth()
            framerate = w.getframerate()
            nframes = w.getnframes()
            raw = w.readframes(nframes)
    except (wave.Error, EOFError, struct.error):
        return data
    if sampwidth != 2 or channels not in (1, 2):
        return data
    # Convert to mono int16 samples in [-1.0, 1.0).
    samples = struct.unpack('<' + 'h' * (len(raw) // 2), raw)
    if channels == 2:
        samples = samples[0::2]
    n = len(samples)
    if n == 0:
        return data
    peak = max(abs(s) for s in samples) / 32768.0
    if peak <= 0.001:
        return data  # already effectively silent
    sq = sum(s * s for s in samples)
    rms = math.sqrt(sq / n) / 32768.0
    if rms <= 0.0001:
        return data
    gain = target_rms / rms
    # Cap gain so a very quiet segment is boosted at most max_gain_db (~4x).
    gain = min(gain, 10 ** (max_gain_db / 20.0))
    # After gain, ensure peak stays under peak_clip; if it would clip, scale
    # down to peak_clip.
    new_peak = peak * gain
    if new_peak > peak_clip:
        gain = peak_clip / peak
    if abs(gain - 1.0) < 0.05:
        return data  # already in a reasonable range
    new_samples = [max(-32768, min(32767, int(s * gain))) for s in samples]
    out = io.BytesIO()
    with wave.open(out, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(framerate)
        w.writeframes(struct.pack('<' + 'h' * len(new_samples), *new_samples))
    return out.getvalue()

def validated_base(base):
    base = (base or DEFAULT_BASE).strip().rstrip('/')
    p = urllib.parse.urlsplit(base)
    if p.scheme not in ('http', 'https') or not p.netloc or p.username or p.query:
        raise ValueError('invalid base_url')
    if p.hostname != DEFAULT_HOST:
        for info in socket.getaddrinfo(p.hostname, p.port or (443 if p.scheme == 'https' else 80)):
            address = info[4][0]
            ip = ipaddress.ip_address(address)
            if (ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved or
                    ip.is_multicast or ip.is_unspecified or ip in ipaddress.ip_network('100.64.0.0/10')):
                raise ValueError('private base_url is not allowed')
    return base

def endpoint(base, path):
    base = validated_base(base)
    if urllib.parse.urlsplit(base).path.rstrip('/').endswith('/v1') and path.startswith('/v1/'):
        path = path[3:]
    return base + path

# ---- Book cover proxy -------------------------------------------------------
# Imported TXT/EPUB novels rarely carry cover art, so the app asks THIS server
# for a cover by title and we look one up from a public source, returning the
# image bytes. Keeping the lookup server-side means the client only ever talks
# to the user's own server (reliable from mainland China) and the matching can
# be improved here without an app update. A miss returns 404 and the client
# falls back to a generated placeholder cover.
COVER_DIR = os.path.join(DATA, 'covers')
COVER_UA = ('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36')
# Image URLs are only fetched from these hosts, so a crafted source response
# cannot steer the server at an internal address (SSRF guard).
COVER_HOST_SUFFIXES = (
    'doubanio.com', 'douban.com',
    'books.google.com', 'books.googleusercontent.com',
    'googleusercontent.com', 'ggpht.com',
)
COVER_MAX_BYTES = 5 * 1024 * 1024

def _cover_key(title, author):
    raw = (title + '|' + author).strip('|')
    return hashlib.sha1(raw.encode('utf-8')).hexdigest()

def _host_allowed(url):
    host = (urllib.parse.urlsplit(url).hostname or '').lower()
    return any(host == s or host.endswith('.' + s) for s in COVER_HOST_SUFFIXES)

def _http_bytes(url, referer=None):
    if url.startswith('http://'):
        url = 'https://' + url[len('http://'):]
    headers = {'User-Agent': COVER_UA}
    if referer:
        headers['Referer'] = referer
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.headers.get('Content-Type', ''), resp.read(COVER_MAX_BYTES + 1)

def _cover_candidates(title, author):
    q = title if not author else title + ' ' + author
    # Douban suggest: best coverage for Chinese books and web novels.
    try:
        url = 'https://book.douban.com/j/subject_suggest?q=' + urllib.parse.quote(q)
        _, data = _http_bytes(url, referer='https://book.douban.com/')
        for item in json.loads(data):
            if isinstance(item, dict) and item.get('type') == 'b' and item.get('pic'):
                yield item['pic']
    except Exception:
        pass
    # Google Books fallback: clean JSON, weaker on web novels / may be geo-limited.
    try:
        url = ('https://www.googleapis.com/books/v1/volumes?country=US&maxResults=1&q='
               + urllib.parse.quote('intitle:' + q))
        _, data = _http_bytes(url)
        for vol in (json.loads(data).get('items') or []):
            links = (vol.get('volumeInfo') or {}).get('imageLinks') or {}
            pic = links.get('thumbnail') or links.get('smallThumbnail')
            if pic:
                yield pic
    except Exception:
        pass

def fetch_cover(title, author=''):
    """Returns (content_type, image_bytes) for a book cover, or None.

    Successful lookups are cached on disk so a repeated title never re-hits the
    upstream source. Best-effort throughout: any upstream failure falls through
    to the next candidate and ultimately to None (the client shows a generated
    cover), never an error.
    """
    title = (title or '').strip()
    if not title:
        return None
    os.makedirs(COVER_DIR, exist_ok=True)
    cached = os.path.join(COVER_DIR, _cover_key(title, author))
    if os.path.isfile(cached):
        with open(cached, 'rb') as f:
            return 'image/jpeg', f.read()
    for pic in _cover_candidates(title, author):
        if not _host_allowed(pic):
            continue
        try:
            ctype, data = _http_bytes(pic, referer='https://book.douban.com/')
        except Exception:
            continue
        if not ctype.startswith('image/') or not (200 <= len(data) <= COVER_MAX_BYTES):
            continue
        try:
            with open(cached, 'wb') as f:
                f.write(data)
        except OSError:
            pass
        return ctype, data
    return None

def synth(job, idx, token):
    with db() as c: row = c.execute('SELECT * FROM jobs WHERE id=?', (job,)).fetchone()
    with db() as c: seg = c.execute('SELECT text FROM segments WHERE job_id=? AND idx=?', (job, idx)).fetchone()
    if not row or not seg: return
    path = os.path.join(DATA, 'jobs', job, f'{idx}.{row["fmt"]}')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        if DEFAULT_PROVIDER == 'mimo':
            url = endpoint(token['base'], '/v1/chat/completions')
            payload = {
                'model': row['model'],
                'messages': [
                    {'role': 'user', 'content': '使用自然、沉稳、清晰的小说旁白语气朗读，根据正文情绪自然调整语速、停顿和语气，不要过度夸张。正文处理规则：1) 语气词（啊、呀、哦、嗯、唉、哎）和拟声词（轰、砰、咚、啪、嗖、嘶、咻、哧、鸣、呜）一律用平稳、克制的叙述语气带过，不要夸张演绎、拉长音或模拟音效；2) 叠字描写（如嗖嗖嗖、啊啊啊、哈哈哈、砰砰砰）按字逐个平稳读出，音长一致，禁止拟声化或拉长；3) 破折号"——"代表正常停顿（约 0.3 至 0.5 秒），不要发出任何音；4) 遇到长串标点或重复符号按自然停顿处理，不要发出异常噪音或拟声音效。'},
                    {'role': 'assistant', 'content': seg['text']},
                ],
                'audio': {'format': row['fmt'], 'voice': row['voice']},
            }
            headers = {'api-key': token['key'], 'Content-Type': 'application/json'}
        else:
            url = endpoint(token['base'], '/v1/audio/speech')
            payload = {
                'model': row['model'], 'voice': row['voice'], 'input': seg['text'],
                'response_format': row['fmt'], 'speed': row['speed'],
            }
            headers = {'Authorization': 'Bearer ' + token['key'], 'Content-Type': 'application/json'}
        req = urllib.request.Request(url, data=json.dumps(payload).encode(),
            headers=headers, method='POST')
        with urllib.request.urlopen(req, timeout=180) as resp:
            data = resp.read()
        if DEFAULT_PROVIDER == 'mimo':
            response = json.loads(data)
            data = base64.b64decode(response['choices'][0]['message']['audio']['data'], validate=True)
        # Smooth out TTS volume swings so a loud SFX right after a quiet line
        # does not sound like the volume "suddenly jumped". wav only; mp3/opus
        # decoding would need extra deps that the image does not ship with.
        if row['fmt'] == 'wav':
            data = _normalize_wav(data)
        with open(path, 'wb') as f: f.write(data)
        with db() as c:
            c.execute("UPDATE segments SET status='done', error=NULL WHERE job_id=? AND idx=?", (job, idx))
            c.execute('UPDATE jobs SET completed=completed+1 WHERE id=?', (job,))
            if c.execute('SELECT completed FROM jobs WHERE id=?', (job,)).fetchone()[0] == row['total']:
                c.execute("UPDATE jobs SET status='completed' WHERE id=?", (job,))
    except urllib.error.HTTPError as e:
        # Keep upstream failures actionable without exposing response bodies or
        # credentials in the public job status.
        if e.code in (401, 403):
            message = 'upstream authentication failed'
        elif e.code == 429:
            message = 'upstream rate limited the request'
        elif e.code >= 500:
            message = f'upstream server error (HTTP {e.code})'
        else:
            message = f'upstream request failed (HTTP {e.code})'
        with db() as c:
            c.execute("UPDATE segments SET status='failed', error=? WHERE job_id=? AND idx=?", (message, job, idx))
            # A single failed segment must NOT mark the whole job failed: the
            # client stops pulling remaining segments on job failure, which
            # stalls playback mid-chapter. Keep the job running until every
            # segment has settled, then finish it (with the last error noted).
            if _job_has_unsettled(c, job):
                pass
            else:
                c.execute("UPDATE jobs SET status='completed', error=? WHERE id=?", (message, job))
    except Exception as e:
        with db() as c:
            c.execute("UPDATE segments SET status='failed', error=? WHERE job_id=? AND idx=?", (str(e)[:500], job, idx))
            if not _job_has_unsettled(c, job):
                c.execute("UPDATE jobs SET status='completed', error=? WHERE id=?", (str(e)[:500], job))

def worker():
    while True:
        item = WORK.get()
        if item is STOP: return
        synth(*item)
        WORK.task_done()

def _job_has_unsettled(c, job):
    """True while a job still has segments queued/running.

    Used by the failure path: a job only reaches a terminal state once every
    segment has settled (done / silent / failed), so one flaky segment does
    not sink the whole chapter.
    """
    row = c.execute(
        'SELECT COUNT(*) FROM segments WHERE job_id=? AND status IN ("queued","running")',
        (job,),
    ).fetchone()
    return row is not None and row[0] > 0

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def send_json(self, code, obj):
        raw = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code); self.send_header('Content-Type', 'application/json'); self.send_header('Content-Length', str(len(raw))); self.end_headers(); self.wfile.write(raw)
    def body(self):
        n = int(self.headers.get('Content-Length', '0')); return json.loads(self.rfile.read(n) or b'{}')
    def do_GET(self):
        if self.path == '/healthz': return self.send_json(200, {'ok': True})
        parsed = urllib.parse.urlsplit(self.path)
        if parsed.path == '/nvr/diagnostics/tail': return self.tail_diagnostics(parsed)
        if parsed.path == '/cover': return self.serve_cover(parsed)
        m = re.fullmatch(r'/v1/jobs/([a-f0-9]{24})', self.path)
        if m:
            with db() as c:
                j = c.execute('SELECT * FROM jobs WHERE id=?', (m.group(1),)).fetchone()
                s = c.execute('SELECT idx,text,status,error FROM segments WHERE job_id=? ORDER BY idx', (m.group(1),)).fetchall()
            if not j: return self.send_json(404, {'error': 'job not found'})
            return self.send_json(200, {'id': j['id'], 'status': j['status'], 'completed': j['completed'], 'total': j['total'], 'error': j['error'], 'segments': [{'index': x['idx'], 'text': x['text'], 'status': x['status'], 'error': x['error'], 'url': f'/v1/jobs/{j["id"]}/segments/{x["idx"]}'} for x in s]})
        m = re.fullmatch(r'/v1/jobs/([a-f0-9]{24})/segments/(\d+)', self.path)
        if m:
            with db() as c:
                row = c.execute('SELECT fmt FROM jobs WHERE id=?', (m.group(1),)).fetchone()
                seg = c.execute('SELECT status FROM segments WHERE job_id=? AND idx=?', (m.group(1), m.group(2))).fetchone()
            # Silent segments (pure punctuation or short SFX) were never
            # synthesised. Stream a cached short silent clip so the client
            # keeps the cursor advancing without an over-dramatic SFX burst.
            if seg and seg['status'] == 'silent':
                data = _silent_wav_bytes()
                self.send_response(200)
                self.send_header('Content-Type', 'audio/wav')
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)
                return
            path = os.path.join(DATA, 'jobs', m.group(1), m.group(2) + '.' + (row['fmt'] if row else 'mp3'))
            if not os.path.isfile(path): return self.send_json(404, {'error': 'segment not ready'})
            data = open(path, 'rb').read(); self.send_response(200); self.send_header('Content-Type', {'mp3': 'audio/mpeg', 'wav': 'audio/wav', 'opus': 'audio/ogg', 'aac': 'audio/aac'}.get(row['fmt'], 'application/octet-stream')); self.send_header('Content-Length', str(len(data))); self.end_headers(); self.wfile.write(data); return
        self.send_json(404, {'error': 'not found'})
    def do_POST(self):
        if self.path == '/nvr/collect': return self.collect_diagnostics()
        if self.path != '/v1/jobs': return self.send_json(404, {'error': 'not found'})
        try: p = self.body(); text = str(p.get('text', '')).strip(); limit = max(10, min(1000, int(p.get('max_characters', 360))))
        except Exception: return self.send_json(400, {'error': 'invalid JSON'})
        text = normalize_cn_text(text)
        key = self.headers.get('Authorization', '')[7:].strip() if self.headers.get('Authorization', '').startswith('Bearer ') else ''
        if not key: key = stored_upstream_key()
        if not key: return self.send_json(401, {'error': 'missing API key'})
        if not text: return self.send_json(400, {'error': 'text is required'})
        if len(text) > 200000: return self.send_json(413, {'error': 'text exceeds 200000 characters'})
        segs = split_text(text, limit); jid = secrets.token_hex(12)
        fmt = p.get('format', 'wav' if DEFAULT_PROVIDER == 'mimo' else 'mp3')
        if fmt not in ('mp3', 'opus', 'aac', 'wav'): return self.send_json(400, {'error': 'unsupported format'})
        token = {'key': key, 'base': p.get('base_url') or DEFAULT_BASE}
        try: validated_base(token['base'])
        except ValueError as e: return self.send_json(400, {'error': str(e)})
        default_model = 'mimo-v2.5-tts' if DEFAULT_PROVIDER == 'mimo' else 'gpt-4o-mini-tts'
        default_voice = '冰糖' if DEFAULT_PROVIDER == 'mimo' else 'alloy'
        # Mark pure-punctuation / single-character SFX paragraphs as 'silent'
        # so the client receives a short silent clip instead of an
        # over-dramatic burst of SFX audio. The job's total reflects the
        # raw split count; only the segments that need synthesis are queued.
        seg_rows = []
        queued = 0
        for i, s in enumerate(segs):
            if _is_silent_text(s) or _is_short_sfx_text(s):
                seg_rows.append((jid, i, s, 'silent'))
            else:
                seg_rows.append((jid, i, s, 'queued'))
                queued += 1
        with db() as c:
            c.execute('INSERT INTO jobs(id,status,total,created,model,voice,fmt,speed) VALUES(?,?,?,?,?,?,?,?)', (jid, 'running' if queued else 'completed', len(segs), int(time.time()), p.get('model', default_model), p.get('voice', default_voice), fmt, float(p.get('speed', 1))))
            c.executemany('INSERT INTO segments(job_id,idx,text,status) VALUES(?,?,?,?)', seg_rows)
        for i, s in enumerate(segs):
            if not (_is_silent_text(s) or _is_short_sfx_text(s)):
                WORK.put((jid, i, token))
        # Opportunistic sweep: purge audio files of jobs completed > 7 days ago
        # so the data volume does not grow without bound (657 MB and counting).
        cleanup_old_jobs()
        self.send_json(202, {'id': jid, 'status': 'running', 'total': len(segs), 'url': f'/v1/jobs/{jid}'})

    def collect_diagnostics(self):
        if not telemetry_ok(self.headers.get('X-Telemetry-Token', '')):
            return self.send_json(401, {'error': 'unauthorized'})
        try: n = int(self.headers.get('Content-Length', '0'))
        except ValueError: return self.send_json(400, {'error': 'invalid length'})
        if n > 2000000: return self.send_json(413, {'error': 'payload too large'})
        try: payload = json.loads(self.rfile.read(n) or b'{}')
        except Exception: return self.send_json(400, {'error': 'invalid JSON'})
        if not isinstance(payload, dict): payload = {}
        events = payload.get('events')
        record = {
            'received': int(time.time()),
            'ip': self.client_address[0] if self.client_address else None,
            'session': payload.get('session'),
            'events': events if isinstance(events, list) else [],
        }
        line = json.dumps(record, ensure_ascii=False)
        with DIAG_LOCK:
            os.makedirs(DIAG_DIR, exist_ok=True)
            with open(DIAG_LOG, 'a') as f: f.write(line + '\n')
        self.send_json(200, {'ok': True, 'stored': len(record['events'])})

    def serve_cover(self, parsed):
        params = urllib.parse.parse_qs(parsed.query)
        title = (params.get('title', [''])[0]).strip()
        author = (params.get('author', [''])[0]).strip()
        if not title:
            return self.send_json(400, {'error': 'title is required'})
        result = fetch_cover(title, author)
        if not result:
            return self.send_json(404, {'error': 'no cover found'})
        ctype, data = result
        self.send_response(200)
        self.send_header('Content-Type', ctype if ctype.startswith('image/') else 'image/jpeg')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'public, max-age=604800')
        self.end_headers()
        self.wfile.write(data)

    def tail_diagnostics(self, parsed):
        params = urllib.parse.parse_qs(parsed.query)
        token = self.headers.get('X-Telemetry-Token', '') or params.get('token', [''])[0]
        if not telemetry_ok(token): return self.send_json(401, {'error': 'unauthorized'})
        try: limit = max(1, min(500, int(params.get('n', ['50'])[0])))
        except ValueError: limit = 50
        try:
            with open(DIAG_LOG, 'r') as f: lines = f.readlines()
        except OSError: lines = []
        records = []
        for ln in lines[-limit:]:
            ln = ln.strip()
            if not ln: continue
            try: records.append(json.loads(ln))
            except Exception: records.append({'raw': ln})
        self.send_json(200, {'count': len(records), 'total': len(lines), 'records': records})

if __name__ == '__main__':
    init_db()
    for _ in range(2): threading.Thread(target=worker, daemon=True).start()
    ThreadingHTTPServer(('0.0.0.0', PORT), Handler).serve_forever()
