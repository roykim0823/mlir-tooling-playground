#!/usr/bin/env python3
"""Turn a server's --lit-test output (Content-Length framed JSON-RPC) into a few
readable lines: capabilities, diagnostics, and each reply's payload.
Usage:  <server> --lit-test < session | summarize.py
"""
import json, re, sys

raw = sys.stdin.read()
i = 0
while True:
    m = re.search(r"Content-Length: (\d+)\r?\n\r?\n", raw[i:])
    if not m:
        break
    start = i + m.end()
    n = int(m.group(1))
    body = raw[start:start + n]
    i = start + n
    msg = json.loads(body)
    if msg.get("method") == "textDocument/publishDiagnostics":
        p = msg["params"]
        ds = p["diagnostics"]
        print(f"diagnostics for {p['uri']}: {len(ds)}")
        for d in ds:
            s = d["range"]["start"]
            print(f"  line {s['line'] + 1}, col {s['character'] + 1}: {d['message']}")
    elif msg.get("id") == 0:
        caps = msg["result"]["capabilities"]
        print("capabilities:", ", ".join(k for k, v in caps.items() if v))
    elif msg.get("id") == 99:
        pass                                                       # shutdown acknowledgement
    elif "id" in msg and "result" in msg:
        r = msg["result"]
        if r is None:
            print(f"reply {msg['id']}: null (nothing at that position)")
        elif isinstance(r, dict) and "contents" in r:            # hover
            print(f"reply {msg['id']} (hover):")
            for line in r["contents"]["value"].strip().splitlines():
                print("  |", line)
        elif isinstance(r, list) and r and "uri" in r[0]:        # locations
            print(f"reply {msg['id']} (locations):")
            for loc in r:
                s = loc["range"]["start"]
                print(f"  {loc['uri']} line {s['line'] + 1}, col {s['character'] + 1}")
        elif isinstance(r, list) and r and "name" in r[0]:       # symbols
            print(f"reply {msg['id']} (symbols):", ", ".join(s["name"] for s in r))
        elif r == {} or r == []:
            print(f"reply {msg['id']}: (empty)")
        else:
            print(f"reply {msg['id']}:", json.dumps(r)[:200])
