#!/usr/bin/env bash
# Convert every .td file in solution/ into a generated C++ header
# (generated/<name>.gen.h) via --dump-json + td2cpp.py.
#
# All lesson .td files live flat in solution/ (numbered 01-15 in reading order).
#
# See td2cpp.py for what the conversion produces. For a *proper* CMake build of
# the C++ examples (lessons 14/15), see codegen-demo/CMakeLists.txt. For a real
# --gen-* LLVM backend pipeline, see ../backend Lesson 6.
set -euo pipefail

cd "$(dirname "$0")"

OUT=generated
mkdir -p "$OUT"

# Generic lesson files -> C++ headers via --dump-json (sorted by lesson no.).
files=()
while IFS= read -r f; do
  files+=("$f")
done < <(find solution -name '*.td' | sort)

echo "Converting ${#files[@]} file(s) via --dump-json -> $OUT/*.gen.h"
python3 td2cpp.py "${files[@]}"
