#!/usr/bin/env python3
"""Build a --lit-test session for a REAL file (its text must be embedded in the
didOpen message, so hand-writing one is impractical for anything but toys).

  make-session.py FILE [--hover LINE:COL]... [--definition LINE:COL]... [--references LINE:COL]...

LINE:COL are 1-based, as an editor shows them. The file's URI is file://<abs path>,
which is what the tablegen/pdll servers look up in their compilation database
to find include paths. Prints the session to stdout; pipe it into a server.
"""
import argparse, json, os, sys

ap = argparse.ArgumentParser()
ap.add_argument("file")
ap.add_argument("--hover", action="append", default=[])
ap.add_argument("--definition", action="append", default=[])
ap.add_argument("--references", action="append", default=[])
a = ap.parse_args()

path = os.path.abspath(a.file)
uri = "file://" + path
lang = {".td": "tablegen", ".pdll": "pdll"}.get(os.path.splitext(path)[1], "mlir")
text = open(path).read()

def pos(s):
    line, col = s.split(":")
    return {"line": int(line) - 1, "character": int(col) - 1}

msgs = [{"jsonrpc": "2.0", "id": 0, "method": "initialize",
         "params": {"processId": 1, "rootUri": "file://" + os.path.dirname(path), "capabilities": {}}},
        {"jsonrpc": "2.0", "method": "textDocument/didOpen",
         "params": {"textDocument": {"uri": uri, "languageId": lang, "version": 1, "text": text}}}]
rid = 1
for method, plist in (("hover", a.hover), ("definition", a.definition), ("references", a.references)):
    for p in plist:
        params = {"textDocument": {"uri": uri}, "position": pos(p)}
        if method == "references":
            params["context"] = {"includeDeclaration": True}
        msgs.append({"jsonrpc": "2.0", "id": rid, "method": "textDocument/" + method, "params": params})
        rid += 1
msgs.append({"jsonrpc": "2.0", "id": 99, "method": "shutdown"})   # 99: summarize.py hides this ack
msgs.append({"jsonrpc": "2.0", "method": "exit"})
print("\n// -----\n".join(json.dumps(m) for m in msgs))
