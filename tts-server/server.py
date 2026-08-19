#!/usr/bin/env python3
import base64
import json
import ipaddress
import os
import queue
import re
import secrets
import socket
import sqlite3
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DATA = os.environ.get('TTS_DATA', '/data')
PORT = int(os.environ.get('TTS_PORT', '8000'))
DEFAULT_BASE = os.environ.get('TTS_BASE_URL', 'https://api.xiaomimimo.com')
DEFAULT_PROVIDER = os.environ.get('TTS_PROVIDER', 'mimo').strip().lower()
DEFAULT_HOST = urllib.parse.urlsplit(DEFAULT_BASE).hostname
DB = os.path.join(DATA, 'jobs.sqlite3')
WORK = queue.Queue()
STOP = object()

def db():
    c = sqlite3.connect(DB, timeout=30)
    c.row_factory = sqlite3.Row
    return c

def init_db():
    os.makedirs(DATA, exist_ok=True)
    with db() as c:
        c.execute('''CREATE TABLE IF NOT EXISTS jobs (
            id TEXT PRIMARY KEY, status TEXT NOT NULL, total INTEGER NOT NULL,
            completed INTEGER NOT NULL DEFAULT 0, error TEXT, created INTEGER NOT NULL,
            model TEXT, voice TEXT, fmt TEXT, speed REAL)''')
        c.execute('''CREATE TABLE IF NOT EXISTS segments (
            job_id TEXT NOT NULL, idx INTEGER NOT NULL, text TEXT NOT NULL,
            status TEXT NOT NULL, error TEXT, PRIMARY KEY(job_id, idx))''')

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
                    {'role': 'user', 'content': '使用自然、沉稳、清晰的小说旁白语气朗读，根据正文情绪自然调整语速、停顿和语气，不要过度夸张。'},
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
            c.execute("UPDATE jobs SET status='failed', error=? WHERE id=?", (message, job))
    except Exception as e:
        with db() as c:
            c.execute("UPDATE segments SET status='failed', error=? WHERE job_id=? AND idx=?", (str(e)[:500], job, idx))
            c.execute("UPDATE jobs SET status='failed', error=? WHERE id=?", (str(e)[:500], job))

def worker():
    while True:
        item = WORK.get()
        if item is STOP: return
        synth(*item)
        WORK.task_done()

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def send_json(self, code, obj):
        raw = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code); self.send_header('Content-Type', 'application/json'); self.send_header('Content-Length', str(len(raw))); self.end_headers(); self.wfile.write(raw)
    def body(self):
        n = int(self.headers.get('Content-Length', '0')); return json.loads(self.rfile.read(n) or b'{}')
    def do_GET(self):
        if self.path == '/healthz': return self.send_json(200, {'ok': True})
        m = re.fullmatch(r'/v1/jobs/([a-f0-9]{24})', self.path)
        if m:
            with db() as c:
                j = c.execute('SELECT * FROM jobs WHERE id=?', (m.group(1),)).fetchone()
                s = c.execute('SELECT idx,text,status,error FROM segments WHERE job_id=? ORDER BY idx', (m.group(1),)).fetchall()
            if not j: return self.send_json(404, {'error': 'job not found'})
            return self.send_json(200, {'id': j['id'], 'status': j['status'], 'completed': j['completed'], 'total': j['total'], 'error': j['error'], 'segments': [{'index': x['idx'], 'text': x['text'], 'status': x['status'], 'error': x['error'], 'url': f'/v1/jobs/{j["id"]}/segments/{x["idx"]}'} for x in s]})
        m = re.fullmatch(r'/v1/jobs/([a-f0-9]{24})/segments/(\d+)', self.path)
        if m:
            with db() as c: row = c.execute('SELECT fmt FROM jobs WHERE id=?', (m.group(1),)).fetchone()
            path = os.path.join(DATA, 'jobs', m.group(1), m.group(2) + '.' + (row['fmt'] if row else 'mp3'))
            if not os.path.isfile(path): return self.send_json(404, {'error': 'segment not ready'})
            data = open(path, 'rb').read(); self.send_response(200); self.send_header('Content-Type', {'mp3': 'audio/mpeg', 'wav': 'audio/wav', 'opus': 'audio/ogg', 'aac': 'audio/aac'}.get(row['fmt'], 'application/octet-stream')); self.send_header('Content-Length', str(len(data))); self.end_headers(); self.wfile.write(data); return
        self.send_json(404, {'error': 'not found'})
    def do_POST(self):
        if self.path != '/v1/jobs': return self.send_json(404, {'error': 'not found'})
        try: p = self.body(); text = str(p.get('text', '')).strip(); limit = max(10, min(1000, int(p.get('max_characters', 360))))
        except Exception: return self.send_json(400, {'error': 'invalid JSON'})
        key = self.headers.get('Authorization', '')[7:].strip() if self.headers.get('Authorization', '').startswith('Bearer ') else ''
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
        with db() as c:
            c.execute('INSERT INTO jobs(id,status,total,created,model,voice,fmt,speed) VALUES(?,?,?,?,?,?,?,?)', (jid, 'running', len(segs), int(time.time()), p.get('model', default_model), p.get('voice', default_voice), fmt, float(p.get('speed', 1))))
            c.executemany('INSERT INTO segments(job_id,idx,text,status) VALUES(?,?,?,?)', [(jid, i, s, 'queued') for i, s in enumerate(segs)])
        for i in range(len(segs)): WORK.put((jid, i, token))
        self.send_json(202, {'id': jid, 'status': 'running', 'total': len(segs), 'url': f'/v1/jobs/{jid}'})

if __name__ == '__main__':
    init_db()
    for _ in range(2): threading.Thread(target=worker, daemon=True).start()
    ThreadingHTTPServer(('0.0.0.0', PORT), Handler).serve_forever()
