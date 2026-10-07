#!/usr/bin/env python3
"""A TableGen backend written in Python, on top of `llvm-tblgen --dump-json`.

The TableGen overview names two ways to write a backend: extend TableGen in
C++ (../writing), or write a script in any language that reads the JSON that
`--dump-json` prints. This is the second kind. It turns any `.td` file into a
plain C++ header:

  * each TableGen record  ->  a `constexpr` struct instance
  * record fields         ->  struct members (bit/int/string/list -> C++ types)
  * each class               ->  a `std::array` of the names of its records
                                 (from the JSON's "!instanceof" table)

It is schema-agnostic: it mirrors whatever records the `.td` defines. A real
backend instead knows its schema (which classes and fields mean what) and
emits exactly the tables its consumer needs.
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

TBLGEN = os.path.join(os.environ.get("LLVM_BIN", "/opt/homebrew/opt/llvm@20/bin"),
                      "llvm-tblgen")


def run_tblgen(td_path: Path) -> dict:
    """Return the parsed `--dump-json` output for a `.td` file."""
    out = subprocess.run(
        [TBLGEN, "--dump-json", str(td_path)],
        check=True, capture_output=True, text=True,
    ).stdout
    return json.loads(out)


def cpp_string_literal(text: str) -> str:
    """Escape a Python string into a safe C++ double-quoted literal."""
    escaped = (
        text.replace("\\", "\\\\")
            .replace('"', '\\"')
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t")
    )
    return '"' + escaped + '"'


def sanitize(name: str) -> str:
    """Make a TableGen identifier safe to use as a C++ identifier."""
    ident = re.sub(r"[^A-Za-z0-9_]", "_", name)
    if ident and ident[0].isdigit():
        ident = "_" + ident
    return ident


def cpp_type_and_value(value):
    """Map a JSON field value to a (C++ type, C++ literal) pair."""
    if value is None:                       # uninitialized `?`
        return "const char*", "nullptr"
    if isinstance(value, bool):
        return "bool", "true" if value else "false"
    if isinstance(value, int):
        return "int64_t", str(value)
    if isinstance(value, str):
        return "const char*", cpp_string_literal(value)
    if isinstance(value, list):
        elem_types, elem_vals = [], []
        for item in value:
            t, v = cpp_type_and_value(item)
            elem_types.append(t)
            elem_vals.append(v)
        elem_t = elem_types[0] if elem_types else "int64_t"
        if any(t != elem_t for t in elem_types):
            elem_t = "const char*"           # mixed list -> fall back to strings
            elem_vals = [json_to_str(v) for v in value]
        # std::array<T,N> wraps a C array, so use double braces (no reliance on
        # brace elision — important for nested list<list<...>> values).
        init = "{}" if not elem_vals else "{{ " + ", ".join(elem_vals) + " }}"
        return f"std::array<{elem_t}, {len(value)}>", init
    if isinstance(value, dict):              # dag / record-ref / complex value
        return "const char*", json_to_str(value)
    return "const char*", json_to_str(value)


def json_to_str(value) -> str:
    """Render an arbitrary JSON value as a C++ string literal (debug fallback)."""
    text = json.dumps(value) if not isinstance(value, str) else value
    return cpp_string_literal(text)


def scalar_field(value) -> bool:
    """Fields we can emit as struct members (skip dag/record-ref objects)."""
    return value is None or isinstance(value, (bool, int, str, list))


def emit_header(data: dict, stem: str) -> str:
    guard = f"TDGEN_{sanitize(stem).upper()}_H"
    lines = [
        f"// Generated from {stem}.td by td2cpp.py — DO NOT EDIT.",
        f"#ifndef {guard}",
        f"#define {guard}",
        "",
        "#include <array>",
        "#include <cstdint>",
        "",
        f"namespace tdgen_{sanitize(stem)} {{",
        "",
    ]

    instanceof = data.get("!instanceof", {})
    reserved = {"!instanceof", "!tablegen_json_version"}
    records = {k: v for k, v in data.items() if k not in reserved}

    # One struct + constexpr instance per record.
    for rec_name, rec in records.items():
        if not isinstance(rec, dict):
            continue
        ident = sanitize(rec_name)
        supers = rec.get("!superclasses", [])
        comment = f"  // {', '.join(supers)}" if supers else ""
        members = [
            (fname, fval) for fname, fval in rec.items()
            if not fname.startswith("!") and scalar_field(fval)
        ]
        lines.append(f"struct {ident}_t {{{comment}")
        for fname, fval in members:
            ctype, _ = cpp_type_and_value(fval)
            lines.append(f"  {ctype} {sanitize(fname)};")
        lines.append("};")
        init = ", ".join(cpp_type_and_value(fval)[1] for _, fval in members)
        lines.append(f"constexpr {ident}_t {ident} = {{ {init} }};")
        lines.append("")

    # The names of the records that derive from each class. (Every record has
    # its own struct type, so the records themselves cannot share an array.)
    for cls, members in sorted(instanceof.items()):
        concrete = [m for m in members if m in records]
        if not concrete:
            continue
        names = ", ".join(cpp_string_literal(m) for m in concrete)
        lines.append(
            f"constexpr std::array<const char*, {len(concrete)}> All{sanitize(cls)} = {{{{ {names} }}}};"
        )
        lines.append("")

    lines.append(f"}} // namespace tdgen_{sanitize(stem)}")
    lines.append("")
    lines.append(f"#endif // {guard}")
    lines.append("")
    return "\n".join(lines)


def convert(td_path: Path, out_dir: Path) -> Path:
    data = run_tblgen(td_path)
    stem = td_path.stem
    header = emit_header(data, stem)
    out_path = out_dir / f"{stem}.gen.h"
    out_path.write_text(header)
    return out_path


def main(argv):
    args = argv[1:]
    out_dir = Path(__file__).parent / "generated"
    # Optional: --out-dir DIR  (lets CMake redirect output into its build tree).
    if args and args[0] in ("--out-dir", "-o"):
        if len(args) < 2:
            print(f"{argv[0]}: {args[0]} requires a directory", file=sys.stderr)
            return 2
        out_dir = Path(args[1])
        args = args[2:]
    if not args:
        print(f"usage: {argv[0]} [--out-dir DIR] <file.td> [more.td ...]", file=sys.stderr)
        return 2
    out_dir.mkdir(parents=True, exist_ok=True)
    for arg in args:
        td_path = Path(arg)
        out_path = convert(td_path, out_dir)
        rel = out_path.relative_to(Path.cwd()) if out_path.is_relative_to(Path.cwd()) else out_path
        print(f"{td_path.name} -> {rel}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
