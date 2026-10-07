#!/usr/bin/env bash
# Build the three CMake projects of the track, then run every RUN: line in it
# with lit. Extra arguments go to lit, e.g. `./check.sh -v language`.
#
# Tests that need the fetched X86 sources report UNSUPPORTED until
# ./fetch-x86.sh has run.
set -euo pipefail
cd "$(dirname "$0")"

export LLVM_BIN=${LLVM_BIN:-/opt/homebrew/opt/llvm@20/bin}
LLVM_DIR=${LLVM_DIR:-$(dirname "$LLVM_BIN")/lib/cmake/llvm}

build() {
  local dir=$1 log=$1/build/build.log
  mkdir -p "$dir/build"
  echo "building $dir"
  if ! { cmake -S "$dir" -B "$dir/build" -DLLVM_DIR="$LLVM_DIR" \
           -DCMAKE_BUILD_TYPE=Release && cmake --build "$dir/build" -j; } >"$log" 2>&1; then
    tail -n 40 "$log"
    echo "build of $dir failed; full log: $log" >&2
    exit 1
  fi
}
build backend/writing
build backend/stock
build backend/json

if [[ $# -eq 0 ]]; then set -- .; fi
lit -sv "$@"
