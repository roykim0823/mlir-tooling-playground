#!/usr/bin/env bash
# Runnable transcript for the test-case reduction tutorial.
#
#   ./try.sh            # every section, in order
#   ./try.sh 3          # one section (2..6 — numbered like README.md)
#
# Needs a prebuilt LLVM/MLIR (mlir-opt, mlir-reduce, llvm-reduce, opt,
# FileCheck). Section 5 uses the capstone's toy-reduce and is skipped with a
# hint if it is not built. Override the toolchain: LLVM_BIN=/path/to/bin ./try.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/examples"

if [[ -z "${LLVM_BIN:-}" ]] && command -v llvm-config >/dev/null 2>&1; then LLVM_BIN="$(llvm-config --bindir)"; fi
if [[ -z "${LLVM_BIN:-}" || ! -x "$LLVM_BIN/mlir-reduce" ]]; then
  echo "ERROR: mlir-reduce not found${LLVM_BIN:+ in: $LLVM_BIN}. Set LLVM_BIN=/path/to/llvm/bin" >&2; exit 1
fi
export PATH="$LLVM_BIN:$PATH"
CAPSTONE="../../mlir-tablegen/capstone-toy"
export PATH="$PWD/$CAPSTONE/build:$PATH"       # toy-reduce / toy-opt, if built
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

section() { printf '\n\033[1m==== Section %s — %s ====\033[0m\n' "$1" "$2"; }
run()     { printf '\n\033[36m$ %s\033[0m\n' "$*"; eval "$@"; }
run_fail(){ printf '\n\033[36m$ %s\033[0m  \033[33m(expected to fail)\033[0m\n' "$*"; eval "$@" || printf '\033[33m[exit %s]\033[0m\n' "$?"; }

s2() { section 2 "mlir-reduce on a stock-dialect input"
  run "./interesting.sh crash.mlir && echo 'tester exit 0 = NOT interesting' || echo 'tester exit 1 = interesting'"
  run "mlir-reduce crash.mlir -reduction-tree='traversal-mode=0 test=./interesting.sh' -o $TMP/reduced.mlir 2>$TMP/noise.txt; echo \"exit \$?\""
  run "cat $TMP/reduced.mlir"
  run "sort $TMP/noise.txt | uniq -c | sort -rn | head -3     # verifier noise from rejected candidates"
  run_fail "mlir-reduce crash.mlir -reduction-tree='traversal-mode=1 test=./interesting.sh' -o $TMP/x.mlir"
  run_fail "mlir-reduce crash.mlir -reduction-tree='traversal-mode=0 test=/usr/bin/true' -o $TMP/never.mlir; ls $TMP/never.mlir"
}
s3() { section 3 "Reducing with optimization passes"
  run "mlir-reduce crash.mlir -opt-reduction-pass='opt-pass=canonicalize test=./interesting.sh' -o $TMP/canon.mlir 2>/dev/null && cat $TMP/canon.mlir"
  run "mlir-reduce crash.mlir -opt-reduction-pass='opt-pass=canonicalize test=./interesting.sh' -reduction-tree='traversal-mode=0 test=./interesting.sh' -o $TMP/both.mlir 2>/dev/null && cat $TMP/both.mlir"
  run "mlir-reduce calls.mlir -reduction-tree='traversal-mode=0 test=./interesting.sh' -o $TMP/calls_tree.mlir 2>/dev/null && grep 'func.func' $TMP/calls_tree.mlir"
  run "mlir-reduce calls.mlir -opt-reduction-pass='opt-pass=symbol-dce test=./interesting.sh' -o $TMP/calls_dce.mlir 2>/dev/null && grep 'func.func' $TMP/calls_dce.mlir"
}
s4() { section 4 "Writing the interestingness test"
  run "cat interesting.sh"
  run "mlir-reduce crash.mlir -reduction-tree='traversal-mode=0 test=./interesting-arg.sh test-arg=arith.divui' -o $TMP/arg.mlir 2>/dev/null && grep -c 'func.func' $TMP/arg.mlir"
}
s5() { section 5 "Your own dialect: toy-reduce"
  if command -v toy-reduce >/dev/null 2>&1; then
    run "cat $CAPSTONE/test/Inputs/interesting.sh"
    run "toy-reduce $CAPSTONE/test/reduce.mlir -reduction-tree='traversal-mode=0 test=$CAPSTONE/test/Inputs/interesting.sh' -o $TMP/toy.mlir 2>/dev/null && cat $TMP/toy.mlir"
  else
    printf '\n\033[33m(skipped: build the capstone first — see %s/README.md)\033[0m\n' "$CAPSTONE"
  fi
}
s6() { section 6 "llvm-reduce"
  run "./interesting-ll.sh big.ll && echo 'tester exit 0 = interesting' || echo 'tester exit 1 = NOT interesting'"
  run "llvm-reduce --test=./interesting-ll.sh big.ll -o $TMP/reduced.ll 2>$TMP/ll.txt; echo \"exit \$?\""
  run "cat $TMP/reduced.ll"
  run "grep -E '^\*\*\*|SUCCESS' $TMP/ll.txt | head -8      # progress log (stderr)"
  run "llvm-reduce --test=./interesting-ll.sh --delta-passes=functions,instructions big.ll -o $TMP/partial.ll 2>/dev/null && grep -E 'define|udiv' $TMP/partial.ll"
  run "llvm-reduce --print-delta-passes 2>&1 | tr -s ' \n' ' ' | cut -c1-300; echo"
  run_fail "sed 's/udiv i32 %diff, 3/udiv i32 %diff, 2/' big.ll > $TMP/pow2.ll && llvm-reduce --test=./interesting-ll.sh $TMP/pow2.ll -o $TMP/never.ll"
}

which=${1:-all}
case "$which" in
  all) for i in 2 3 4 5 6; do s$i; done ;;
  [2-6]) s"$which" ;;
  *) echo "usage: $0 [all|2..6]" >&2; exit 2 ;;
esac
