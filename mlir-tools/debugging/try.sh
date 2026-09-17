#!/usr/bin/env bash
# Runnable transcript for the debugging & introspection tutorial.
#
#   ./try.sh            # run every section, in order (same as 'all')
#   ./try.sh 3          # run just one section (1..7)
#
# Sections mirror README.md. Each command is echoed before it runs so the
# output reads like a transcript. Only stock mlir-opt / llvm-tblgen are needed;
# the toy-opt lines are skipped (with a hint) if the capstone is not built.
# Override the toolchain with:  LLVM_BIN=/path/to/llvm/bin ./try.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/examples"

# --- toolchain ---------------------------------------------------------------
if [[ -z "${LLVM_BIN:-}" ]]; then
  if command -v llvm-config >/dev/null 2>&1; then LLVM_BIN="$(llvm-config --bindir)"; fi
fi
if [[ -z "${LLVM_BIN:-}" || ! -x "$LLVM_BIN/mlir-opt" ]]; then
  echo "ERROR: mlir-opt not found${LLVM_BIN:+ in: $LLVM_BIN}. Set LLVM_BIN=/path/to/llvm/bin" >&2; exit 1
fi
export PATH="$LLVM_BIN:$PATH"
MLIR_INC="$(cd "$LLVM_BIN/../include" && pwd)"
CAPSTONE="../../../mlir-capstone"          # relative to examples/, so transcripts stay short
TOY_OPT="$CAPSTONE/build/toy-opt"
export PATH="$PWD/$CAPSTONE/build:$PATH"             # lets the transcript say plain `toy-opt`
FOLD="$CAPSTONE/test/fold.mlir"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# --- helpers -----------------------------------------------------------------
section() { printf '\n\033[1m==== Section %s — %s ====\033[0m\n' "$1" "$2"; }
run()     { printf '\n\033[36m$ %s\033[0m\n' "$*"; eval "$@"; }          # must succeed
run_fail(){ printf '\n\033[36m$ %s\033[0m  \033[33m(expected to fail)\033[0m\n' "$*"; eval "$@" || printf '\033[33m[exit %s]\033[0m\n' "$?"; }
PLUGIN="$(ls "$CAPSTONE"/build/ToyPlugin.* 2>/dev/null | head -1 || true)"
plugin()  { if [[ -n "$PLUGIN" ]]; then run "$@"; else printf '\n\033[33m(skipped: no ToyPlugin built in %s/build)\033[0m\n  %s\n' "$CAPSTONE" "$*"; fi; }
toy()     { if [[ -x "$TOY_OPT" ]]; then run "$@"; else printf '\n\033[33m(skipped: build the capstone first — see %s/README.md)\033[0m\n  %s\n' "$CAPSTONE" "$*"; fi; }

s1() { section 1 "Watching a pipeline"
  run "mlir-opt pipeline.mlir -cse -canonicalize --mlir-print-ir-after-all -o /dev/null"
  run "mlir-opt pipeline.mlir -cse -canonicalize --mlir-print-ir-before=canonicalize -o /dev/null"
  run "mlir-opt pipeline.mlir -cse -cse --mlir-print-ir-after-all --mlir-print-ir-after-change -o /dev/null"
  run "mlir-opt pipeline.mlir -pass-pipeline='builtin.module(func.func(cse))' --mlir-print-ir-after-all -o /dev/null 2>&1 | head -3"
  run "mlir-opt pipeline.mlir -pass-pipeline='builtin.module(func.func(cse))' --mlir-print-ir-after-all --mlir-print-ir-module-scope --mlir-disable-threading -o /dev/null 2>&1 | head -3"
  run "mlir-opt pipeline.mlir -cse -canonicalize --mlir-print-ir-after-all --mlir-print-ir-tree-dir=$TMP/tree -o /dev/null && find $TMP/tree -type f | sed \"s|$TMP/||\""
  run "mlir-opt pipeline.mlir -cse -canonicalize --dump-pass-pipeline -o /dev/null"
  run "mlir-opt --show-dialects"
  run "mlir-opt --list-passes | grep -A3 -- '--canonicalize'"
  toy "toy-opt $FOLD -toy-fold --mlir-print-ir-after-all -o /dev/null 2>&1 | head -8"
  toy "toy-opt --show-dialects"
  toy "toy-opt --list-passes | grep -A2 -- '--toy-fold'"
  plugin "mlir-opt --load-dialect-plugin=$PLUGIN --show-dialects | tr ',' '\\n' | grep toy"
  plugin "mlir-opt --load-pass-plugin=$PLUGIN --list-passes | grep -A1 -- '--toy-fold'"
}
s2() { section 2 "Reading the IR you get"
  run "mlir-opt pipeline.mlir --mlir-print-op-generic | head -6"
  run "mlir-opt pipeline.mlir -cse --mlir-print-debuginfo"
  run "mlir-opt pipeline.mlir -cse --mlir-print-debuginfo --mlir-pretty-debuginfo | head -6"
  run "mlir-opt big_constant.mlir --mlir-print-value-users"
  run "mlir-opt big_constant.mlir --mlir-elide-elementsattrs-if-larger=4"
  run "mlir-opt pipeline.mlir --mlir-print-unique-ssa-ids | head -5"
  run "mlir-opt pipeline.mlir -cse --mlir-print-debuginfo --mlir-print-local-scope | head -5"
  run "mlir-opt pipeline.mlir --mlir-print-skip-regions"
}
s3() { section 3 "When a pass fails"
  run_fail "mlir-opt pipeline.mlir -canonicalize='max-iterations=1 test-convergence=true' -o /dev/null"
  run_fail "mlir-opt pipeline.mlir -cse -canonicalize='max-iterations=1 test-convergence=true' --mlir-print-ir-after-failure -o /dev/null"
  run_fail "mlir-opt pipeline.mlir -cse -canonicalize='max-iterations=1 test-convergence=true' --mlir-pass-pipeline-crash-reproducer=$TMP/crash.mlir -o /dev/null"
  run "sed -n '/{-#/,/#-}/p' $TMP/crash.mlir"
  run_fail "mlir-opt $TMP/crash.mlir --run-reproducer -o /dev/null"
  run_fail "mlir-opt pipeline.mlir -cse -canonicalize='max-iterations=1 test-convergence=true' --mlir-pass-pipeline-crash-reproducer=$TMP/local.mlir --mlir-pass-pipeline-local-reproducer --mlir-disable-threading -o /dev/null"
  run "grep 'pipeline:' $TMP/local.mlir"
  run "mlir-opt pipeline.mlir -cse -canonicalize --mlir-generate-reproducer=$TMP/repro.mlir -o /dev/null && grep -A3 'mlir_reproducer' $TMP/repro.mlir"
  run "mlir-opt pipeline.mlir -cse -canonicalize --verify-each --verify-roundtrip -o /dev/null && echo 'verify-each + verify-roundtrip: OK'"
}
s4() { section 4 "Diagnostics"
  run_fail "mlir-opt invalid.mlir"
  run_fail "mlir-opt invalid.mlir --mlir-print-op-on-diagnostic=false"
  run_fail "mlir-opt invalid.mlir --mlir-print-stacktrace-on-diagnostic 2>&1 | head -8"
  run "mlir-opt invalid.mlir -verify-diagnostics && echo 'verify-diagnostics: the expected-error matched'"
  toy "toy-opt $FOLD -toy-fold='report=true' -o /dev/null"
  toy "toy-opt $FOLD -toy-fold='report=true' --mlir-diagnostic-verbosity-level=errors -o /dev/null && echo '(remark suppressed)'"
}
s5() { section 5 "Timing and statistics"
  run "mlir-opt pipeline.mlir -cse -canonicalize --mlir-timing -o /dev/null"
  run "mlir-opt pipeline.mlir -cse -canonicalize --mlir-timing --mlir-timing-display=list -o /dev/null"
  run "mlir-opt pipeline.mlir -cse --mlir-pass-statistics -o /dev/null"
  toy "toy-opt $FOLD -toy-fold --mlir-timing -o /dev/null"
}
s6() { section 6 "TableGen and PDLL introspection"
  local TD="$CAPSTONE/include/Toy/ToyOps.td" INC="-I $MLIR_INC -I $CAPSTONE/include"
  run "llvm-tblgen --print-records $INC $TD | sed -n '/^def AddOp {/,/^}/p'"
  run "llvm-tblgen --print-detailed-records $INC $TD | grep -A6 '^AddOp '"
  run "llvm-tblgen --dump-json $INC $TD | jq '.AddOp | {opName, summary, traits: [.traits[].def], assemblyFormat}'"
  run "llvm-tblgen --dump-json $INC $TD | jq -r 'to_entries[] | select(.value | type == \"object\" and (.[\"!superclasses\"] // [] | index(\"Op\"))) | .key'"
  run "mlir-tblgen --print-records $INC $TD | grep -c '^def '"
  run "mlir-pdll -x=ast $INC $CAPSTONE/include/Toy/ToyPatterns.pdll | grep -A4 'PatternDecl' | head -16"
}
s7() { section 7 "What needs a debug build"
  run_fail "mlir-opt pipeline.mlir -canonicalize -debug-only=greedy-rewriter -o /dev/null"
  run "mlir-opt pipeline.mlir -cse --mlir-pass-statistics -o /dev/null 2>&1 | head -3"
  echo; echo "Both need LLVM built with -DLLVM_ENABLE_ASSERTIONS=ON (or -DLLVM_FORCE_ENABLE_STATS=ON for statistics). See README section 7."
}

which=${1:-all}
case "$which" in
  all) for i in 1 2 3 4 5 6 7; do s$i; done ;;
  [1-7]) s"$which" ;;
  *) echo "usage: $0 [all|1..7]" >&2; exit 2 ;;
esac
