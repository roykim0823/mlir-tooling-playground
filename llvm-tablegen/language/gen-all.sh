#!/usr/bin/env bash
# Convert every .td file in the lesson directories into generated C++.
#
#   * Generic lesson files   -> generated/<name>.gen.h   (via --dump-json, td2cpp.py)
#   * 16_searchable_table.td -> generated/16_searchable_table.inc
#                               (via the real --gen-searchable-tables backend)
#
# All lesson .td files live flat in solution/ (numbered 01-16 in reading order).
#
# See td2cpp.py for what the generic conversion produces. For a *proper* CMake
# build of the C++ examples (lessons 14/15/16), see codegen-demo/CMakeLists.txt.
set -euo pipefail

cd "$(dirname "$0")"

LLVM_PREFIX=/opt/homebrew/opt/llvm@20
TBLGEN="$LLVM_PREFIX/bin/llvm-tblgen"
LLVM_INC="$LLVM_PREFIX/include"
OUT=generated
mkdir -p "$OUT"

# The file driven by a dedicated LLVM backend rather than the generic converter.
BACKEND_FILE=solution/16_searchable_table.td

# 1) Generic lesson files -> C++ headers via --dump-json (sorted by lesson no.).
generic=()
while IFS= read -r f; do
  [ "$f" = "$BACKEND_FILE" ] && continue
  generic+=("$f")
done < <(find solution -name '*.td' | sort)

echo "Converting ${#generic[@]} file(s) via --dump-json -> $OUT/*.gen.h"
python3 td2cpp.py "${generic[@]}"

# 2) Real backend: a binary-searchable table emitted as C++.
if [ -f "$BACKEND_FILE" ]; then
  echo "Running --gen-searchable-tables -> $OUT/16_searchable_table.inc"
  "$TBLGEN" --gen-searchable-tables -I "$LLVM_INC" \
    "$BACKEND_FILE" -o "$OUT/16_searchable_table.inc"
fi
