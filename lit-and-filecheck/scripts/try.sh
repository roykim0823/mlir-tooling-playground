#!/usr/bin/env bash
# Runnable "Try it" commands for the lit & FileCheck tutorial (see ../README.md).
#
#   scripts/try.sh            # run every chapter, in order (same as 'all')
#   scripts/try.sh all
#   scripts/try.sh 3          # run just Chapter 3   (1..6; leading zero ok)
#
# Each command is echoed before it runs, so the output reads like a transcript
# of that chapter's "Try it" section. Override the toolchain with:
#   LLVM_BIN=/path/to/llvm-build/bin scripts/try.sh
#
# This script only drives the *chapter* commands; it delegates building the
# example project to example/run.sh (via ensure_built).
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
EXAMPLE="$TUT_DIR/example"

# Locate the LLVM/MLIR bin dir. Order: explicit LLVM_BIN, a from-source build at
# externals/llvm-project/build, then llvm-config on PATH (e.g. Homebrew's llvm@20).
DEFAULT_BIN="$TUT_DIR/../../externals/llvm-project/build/bin"
if [[ -z "${LLVM_BIN:-}" ]]; then
  if [[ -x "$DEFAULT_BIN/mlir-opt" ]]; then
    LLVM_BIN="$DEFAULT_BIN"
  elif command -v llvm-config >/dev/null 2>&1; then
    LLVM_BIN="$(llvm-config --bindir)"
  fi
fi
if [[ -z "${LLVM_BIN:-}" || ! -x "$LLVM_BIN/mlir-opt" || ! -x "$LLVM_BIN/FileCheck" ]]; then
  echo "ERROR: mlir-opt/FileCheck not found${LLVM_BIN:+ in: $LLVM_BIN}." >&2
  echo "Point LLVM_BIN at your LLVM build's bin dir:  LLVM_BIN=/path/to/llvm-build/bin $0" >&2
  exit 1
fi
export PATH="$LLVM_BIN:$PATH"

# Resolve a lit runner. A from-source build ships `llvm-lit`; an installed/Homebrew
# LLVM does not, so fall back to `lit` on PATH (brew install lit), or to the private
# venv example/run.sh bootstraps. `LIT` is an absolute path; the llvm-lit() function
# below lets the chapter transcripts keep calling `llvm-lit` verbatim.
if [[ -x "$LLVM_BIN/llvm-lit" ]]; then
  LIT="$LLVM_BIN/llvm-lit"
elif command -v llvm-lit >/dev/null 2>&1; then
  LIT="$(command -v llvm-lit)"
elif command -v lit >/dev/null 2>&1; then
  LIT="$(command -v lit)"
else
  VENV="$EXAMPLE/.lit-venv"
  if [[ ! -x "$VENV/bin/lit" ]]; then
    echo ">> Installing 'lit' into $VENV (this LLVM ships no llvm-lit)"
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install --quiet --upgrade pip lit
  fi
  LIT="$VENV/bin/lit"
fi
llvm-lit() { "$LIT" "$@"; }

# --- helpers ----------------------------------------------------------------
section() {
  echo
  echo "==================================================================="
  echo "==  $*"
  echo "==================================================================="
}

# Echo a command, then run it (via the shell so pipes/redirs/subs work).
run() { echo; echo "\$ $1"; eval "$1"; }

# Like run(), but the command is EXPECTED to fail (e.g. a FileCheck mismatch).
# Non-zero exit is reported as success.
run_expect_fail() {
  echo; echo "\$ $1   # (expected to fail — this is the lesson)"
  if eval "$1"; then echo "!! UNEXPECTEDLY SUCCEEDED"; return 1; else echo "(failed as expected ✓)"; fi
}

# Build the example project once if its generated lit config isn't present.
ensure_built() {
  if [[ ! -f "$EXAMPLE/build/test/lit.site.cfg.py" ]]; then
    echo ">> Example not built yet; running example/run.sh (one-time)…"
    local mlir_dir="$(cd "$LLVM_BIN/.." && pwd)/lib/cmake/mlir"
    ( cd "$EXAMPLE" && MLIR_DIR="$mlir_dir" ./run.sh >/dev/null 2>&1 )
    echo ">> Built."
  fi
}

# Chapter 6 mutates test files; this restores them however the script exits.
# The trap is always registered but a no-op until chapter_06 sets CH6_INVALID_BAK.
CH6_INVALID_BAK=""
ch6_cleanup() {
  [[ -n "$CH6_INVALID_BAK" ]] || return 0
  rm -f "$EXAMPLE/test/double_negate.mlir"
  [[ -f "$CH6_INVALID_BAK" ]] && cp "$CH6_INVALID_BAK" "$EXAMPLE/test/invalid.mlir" && rm -f "$CH6_INVALID_BAK"
  rm -f /tmp/lit_ex_out.mlir
}
trap ch6_cleanup EXIT

# --- per-chapter "Try it" blocks --------------------------------------------
chapter_01() {
  cd "$EXAMPLE"
  section "Chapter 1 — lit basics"
  section "1) List every discovered test without running anything"
  run "llvm-lit --show-tests build/test"
  section "2) Run just one test, verbosely"
  run "llvm-lit -v build/test --filter='cse\.mlir'"
  section "3) Run all tests and time each one"
  run "llvm-lit -v --time-tests build/test"
  echo; echo ">> Chapter 1 examples complete."
}

chapter_02() {
  cd "$EXAMPLE"
  section "Chapter 2 — FileCheck basics"
  section "1) See the raw transformed IR (what FileCheck will receive)"
  run "mlir-opt test/cse.mlir -cse"
  section "2) Verify it — silence + exit 0 means pass"
  run "mlir-opt test/cse.mlir -cse | FileCheck test/cse.mlir && echo 'exit code: '\$?"
  section "3) Make it FAIL on purpose to read the diagnostic"
  run_expect_fail "mlir-opt test/cse.mlir -cse | FileCheck <(echo '// CHECK: arith.muli')"
  echo; echo ">> Chapter 2 examples complete."
}

chapter_03() {
  cd "$EXAMPLE"
  section "Chapter 3 — FileCheck directives"
  section "Inspect the output, then watch the directives match it (--dump-input=fail)"
  run "mlir-opt test/cse.mlir -cse | FileCheck test/cse.mlir --dump-input=fail && echo PASS"
  section "Bonus: the same on canonicalize.mlir (CHECK-NOT + plain CHECK)"
  run "mlir-opt test/canonicalize.mlir -canonicalize | FileCheck test/canonicalize.mlir && echo PASS"
  echo; echo ">> Chapter 3 examples complete."
}

chapter_04() {
  cd "$EXAMPLE"
  section "Chapter 4 — patterns and variables"
  section "1) The capture-and-reuse test (both returns share one value after CSE)"
  run "cat test/cse.mlir"
  run "mlir-opt test/cse.mlir -cse | FileCheck test/cse.mlir && echo PASS"
  section "2) Experiment: point one use at an undefined variable -> error"
  local BROKEN; BROKEN="$(mktemp)"
  run "sed 's/%\[\[RESULT\]\], %\[\[RESULT\]\]/%[[RESULT]], %[[OTHER]]/' test/cse.mlir > '$BROKEN'"
  run_expect_fail "mlir-opt test/cse.mlir -cse | FileCheck '$BROKEN'"
  rm -f "$BROKEN"
  echo ">> Note the 'undefined variable: OTHER' — captures are real bindings, not decoration."
  echo; echo ">> Chapter 4 examples complete."
}

chapter_05() {
  cd "$EXAMPLE"
  section "Chapter 5 — MLIR testing conventions"
  section "A check test (canonicalize)"
  run "llvm-lit -v build/test --filter='canonicalize\.mlir'"
  section "A diagnostic test — note -verify-diagnostics in its RUN line"
  run "grep -nE 'RUN:|expected-' test/invalid.mlir"
  run "llvm-lit -v build/test --filter='invalid\.mlir'"
  echo; echo ">> Chapter 5 examples complete."
}

chapter_06() {
  cd "$EXAMPLE"
  # Back up the files Labs 4–5 add/append; ch6_cleanup (EXIT trap) restores them.
  CH6_INVALID_BAK="$(mktemp)"
  cp test/invalid.mlir "$CH6_INVALID_BAK"

  section "Chapter 6 — hands-on"

  section "Lab 1 — run a single test three ways"
  run "cmake --build build --target check"
  run "llvm-lit -v build/test --filter='cse\.mlir'"
  run "mlir-opt test/cse.mlir -cse > /tmp/lit_ex_out.mlir && FileCheck test/cse.mlir < /tmp/lit_ex_out.mlir && echo PASS"
  run "cat /tmp/lit_ex_out.mlir"

  section "Lab 2 — read a failure"
  run_expect_fail "mlir-opt test/cse.mlir -cse | FileCheck <(printf '// CHECK: arith.muli\n') --dump-input=fail"

  section "Lab 3 — break a captured variable (expect 'undefined variable')"
  local BROKEN; BROKEN="$(mktemp)"
  run "sed 's/%\[\[RESULT\]\], %\[\[RESULT\]\]/%[[RESULT]], %[[OTHER]]/' test/cse.mlir > '$BROKEN'"
  run_expect_fail "mlir-opt test/cse.mlir -cse | FileCheck '$BROKEN'"
  rm -f "$BROKEN"

  section "Lab 4 — write a new test (auto-discovered, no CMake edit)"
  cat > test/double_negate.mlir <<'EOF'
// RUN: mlir-opt %s -canonicalize | FileCheck %s

// CHECK-LABEL: func.func @double_negate
// CHECK-NOT: arith.subi
// CHECK: return %arg0
func.func @double_negate(%arg0: i32) -> i32 {
  %c0 = arith.constant 0 : i32
  %0 = arith.subi %c0, %arg0 : i32   // -x
  %1 = arith.subi %c0, %0 : i32      // -(-x) == x
  return %1 : i32
}
EOF
  echo ">> created test/double_negate.mlir"
  run "mlir-opt test/double_negate.mlir -canonicalize | FileCheck test/double_negate.mlir && echo PASS"
  run "./run.sh"

  section "Lab 5 — add a diagnostic case"
  cat >> test/invalid.mlir <<'EOF'

// -----

func.func @bad_return2() -> f32 {
  %0 = arith.constant 1 : i32
  // expected-error @+1 {{doesn't match function result type ('f32')}}
  return %0 : i32
}
EOF
  echo ">> appended a sub-test to test/invalid.mlir"
  run "llvm-lit -v build/test --filter='invalid\.mlir'"

  section "Lab 6 — cleanup (handled automatically on exit)"
  echo ">> test/double_negate.mlir removed, test/invalid.mlir restored."

  echo; echo ">> Chapter 6 labs complete."
}

run_chapter() {
  case "$1" in
    1|01) chapter_01 ;;
    2|02) chapter_02 ;;
    3|03) chapter_03 ;;
    4|04) chapter_04 ;;
    5|05) chapter_05 ;;
    6|06) chapter_06 ;;
    *) echo "Unknown chapter: '$1' (expected 1..6 or 'all')" >&2; exit 2 ;;
  esac
}

# --- dispatch ---------------------------------------------------------------
ensure_built

target="${1:-all}"
if [[ "$target" == "all" ]]; then
  for n in 01 02 03 04 05 06; do
    echo
    echo "###################################################################"
    echo "###  Chapter $n"
    echo "###################################################################"
    run_chapter "$n"
  done
  echo; echo ">> All chapter examples completed successfully."
else
  run_chapter "$target"
fi
