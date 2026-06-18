#!/usr/bin/env bash
# Build every tutorial backend and run it on its .td input, showing the output.
set -euo pipefail
cd "$(dirname "$0")"

LLVM_DIR_HINT=/opt/homebrew/opt/llvm@20/lib/cmake/llvm

cmake -S . -B build -DLLVM_DIR="$LLVM_DIR_HINT" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build build >/dev/null

run() { echo "===== $* ====="; ./build/"$@"; echo; }

run 01-skeleton        1-entry-point/01_skeleton.td
run 02-walk-records    2-records-and-values/02_walk_records.td
run 03-init-types      3-init-values/03_init_types.td
run 04-enum-emitter    4-emitting-and-errors/04_enum_emitter.td
run 05-registered-tool --gen-names 5-registration/05_registered_tool.td
run 05-registered-tool --gen-count 5-registration/05_registered_tool.td
