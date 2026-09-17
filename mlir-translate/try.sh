#!/usr/bin/env bash
# Runnable transcript for the mlir-translate tutorial.
#   ./try.sh          # all sections
#   ./try.sh 2        # one section (1..3, numbered like README.md)
# Needs a prebuilt LLVM/MLIR (mlir-translate, mlir-opt). Section 3 uses the
# capstone's toy-translate and is skipped with a hint if it is not built.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE/examples"
if [[ -z "${LLVM_BIN:-}" ]] && command -v llvm-config >/dev/null 2>&1; then LLVM_BIN="$(llvm-config --bindir)"; fi
if [[ -z "${LLVM_BIN:-}" || ! -x "$LLVM_BIN/mlir-translate" ]]; then
  echo "ERROR: mlir-translate not found${LLVM_BIN:+ in: $LLVM_BIN}. Set LLVM_BIN=/path/to/llvm/bin" >&2; exit 1
fi
export PATH="$LLVM_BIN:$PATH"
CAPSTONE="../../mlir-tablegen/capstone-toy"
export PATH="$PWD/$CAPSTONE/build:$PATH"
section() { printf '\n\033[1m==== Section %s — %s ====\033[0m\n' "$1" "$2"; }
run()     { printf '\n\033[36m$ %s\033[0m\n' "$*"; eval "$@"; }
run_fail(){ printf '\n\033[36m$ %s\033[0m  \033[33m(expected to fail)\033[0m\n' "$*"; eval "$@" || printf '\033[33m[exit %s]\033[0m\n' "$?"; }

s1() { section 1 "The stock tool: export and import LLVM IR"
  run "mlir-translate --help | grep -E -- '--(mlir-to|import|serialize|deserialize)'"
  run "mlir-translate --mlir-to-llvmir llvm_dialect.mlir"
  run "mlir-translate --import-llvm add.ll"
  run "mlir-translate --import-llvm add.ll | mlir-translate --mlir-to-llvmir | grep -E 'define|add|ret'     # round trip"
}
s2() { section 2 "A translation only knows its own dialects"
  run_fail "mlir-translate --mlir-to-llvmir arith.mlir"
  run "mlir-opt arith.mlir -convert-arith-to-llvm -convert-func-to-llvm | mlir-translate --mlir-to-llvmir | grep -E 'define|add|ret'"
}
s3() { section 3 "Your own format: toy-translate"
  if ! command -v toy-translate >/dev/null 2>&1; then printf '\n\033[33m(skipped: build the capstone first — see %s/README.md)\033[0m\n' "$CAPSTONE"; return 0; fi
  run "toy-translate --help | grep -A1 -- '--mlir-to-toytext'"
  run "grep -v '^//' $CAPSTONE/test/translate.mlir | grep '^%\\|^toy'"
  run "toy-translate --mlir-to-toytext $CAPSTONE/test/translate.mlir"
  run "toy-translate --mlir-to-toytext $CAPSTONE/test/translate.mlir | toy-translate --toytext-to-mlir"
  run "toy-translate --toytext-to-mlir $CAPSTONE/test/translate-import.toytext --mlir-print-debuginfo"
  run_fail "toy-translate --toytext-to-mlir $CAPSTONE/test/Inputs/bad.toytext"
  run_fail "toy-translate --mlir-to-toytext $CAPSTONE/test/Inputs/unexportable.mlir 2>&1 | head -1"
}
which=${1:-all}
case "$which" in all) for i in 1 2 3; do s$i; done ;; [1-3]) s"$which" ;; *) echo "usage: $0 [all|1..3]" >&2; exit 2 ;; esac
