import json, collections

F = r"E:/novel-voice-reader/tools/telemetry.jsonl"
lines = [l for l in open(F, encoding="utf-8").read().split("\n") if l.strip()]
sessions = collections.OrderedDict(); meta = {}; recv = {}
for l in lines:
    try:
        r = json.loads(l)
    except Exception:
        continue
    b = r.get("body")
    if not isinstance(b, dict):
        continue
    sess = b.get("session") or {}
    batch_lid = sess.get("launchId", "?")
    for e in (b.get("events") or []):
        if not isinstance(e, dict):
            continue
        lid = e.get("lid", batch_lid)
        meta.setdefault(lid, sess)
        recv.setdefault(lid, []).append(r.get("recv_ts"))
        sessions.setdefault(lid, []).append(e)

print("records", len(lines), "sessions", len(sessions))
KEYS = ("active", "attempts", "kind", "shouldRender", "playing",
        "processingState", "state", "error", "message", "recoverOnError")
for lid, evs in sessions.items():
    s = meta.get(lid, {})
    if s.get("platform") != "ios":
        print("--- skip", lid, s.get("platform"), len(evs), "events"); continue
    evs.sort(key=lambda e: (e.get("seq", 0), e.get("mono_us", 0)))
    print("=" * 78)
    print("launch", lid, "|", s.get("osVersion"),
          "| recv", recv[lid][0], "->", recv[lid][-1], "| events", len(evs))
    prev = None; seen = collections.Counter()
    for e in evs:
        seq = e.get("seq"); mono = e.get("mono_us"); seen[seq] += 1
        gap = ""
        if prev is not None and isinstance(mono, (int, float)):
            d = (mono - prev) / 1e6
            if d >= 5:
                gap = "   <<<<< GAP %.1fs" % d
        if isinstance(mono, (int, float)):
            prev = mono
        dup = " DUP" if seen[seq] > 1 else ""
        f = e.get("fields", {}) or {}
        info = {k: f[k] for k in KEYS if k in f}
        t = ("%.2f" % (mono / 1e6)) if isinstance(mono, (int, float)) else "?"
        print("  seq%4s%-4s t=%9s %-26s %s%s" % (
            seq, dup, t, e.get("name"), info, gap))
    if evs:
        le = evs[-1]
        print("LAST:", le.get("name"), "| ts", le.get("ts"), "| mono_us", le.get("mono_us"))
