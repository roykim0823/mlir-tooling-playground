#!/usr/bin/env bash
# Runnable transcript for the lit & FileCheck tutorial.
#
#   scripts/try.sh            # run every section, in order (same as 'all')
#   scripts/try.sh all
#   scripts/try.sh 3          # run just one section  (1..6; leading zero ok)
#
# Sections 1-6 mirror Tutorials 1-6 in ../README.md. Each command is echoed
# before it runs, so the output reads like a transcript. Override the toolchain
# with:  LLVM_BIN=/path/to/llvm-build/bin scripts/try.sh
#
# This script only drives the example commands; it delegates building the
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

# Tutorial 6 writes test/double_negate.mlir; remove it however we exit, so the
# script is safe to re-run.
cleanup() {
  rm -f "$EXAMPLE/test/double_negate.mlir"
}
trap cleanup EXIT

# --- per-chapter "Try it" blocks --------------------------------------------
chapter_01() {
  cd "$EXAMPLE"
  section "Tutorial 1 — lit basics"
  section "Step 1 — run the suite"
  run "llvm-lit build/test"
  section "Step 2 — see what lit discovered (and why: the .mlir suffix)"
  run "llvm-lit --show-tests build/test"
  section "Step 3 — watch one RUN line expand (note %s and the tool paths)"
  run "llvm-lit -a build/test --filter='canonicalize\.mlir'"
  echo; echo ">> Tutorial 1 examples complete."
}

chapter_02() {
  cd "$EXAMPLE"
  section "Tutorial 2 — FileCheck basics"
  section "Step 1 — smallest check: ordered patterns match (exit 0)"
  run "printf 'alpha\nbeta\ngamma\n' | FileCheck <(printf 'CHECK: alpha\nCHECK: gamma\n') && echo 'exit: '\$?"
  section "Step 2 — order is enforced: the wrong order fails"
  run_expect_fail "printf 'alpha\nbeta\ngamma\n' | FileCheck <(printf 'CHECK: gamma\nCHECK: alpha\n')"
  section "Step 3 — a missing pattern fails (read the diagnostic)"
  run_expect_fail "printf 'alpha\nbeta\ngamma\n' | FileCheck <(printf 'CHECK: delta\n')"
  section "Step 3 (real IR) — the same failure via broken/expects_muli.mlir"
  run_expect_fail "mlir-opt broken/expects_muli.mlir -cse | FileCheck broken/expects_muli.mlir --dump-input=fail"
  section "Step 4 — whitespace is canonicalized"
  run "printf 'a      b\n' | FileCheck <(printf 'CHECK: a b\n') && echo PASS"
  echo; echo ">> Tutorial 2 examples complete."
}

chapter_03() {
  cd "$EXAMPLE"
  section "Tutorial 3 — FileCheck directives"
  section "CHECK-NEXT — adjacent lines match"
  run "printf 'alpha\nbeta\n' | FileCheck <(printf 'CHECK: alpha\nCHECK-NEXT: beta\n') && echo PASS"
  section "CHECK-NEXT — a gap between them fails"
  run_expect_fail "printf 'alpha\nbeta\ngamma\n' | FileCheck <(printf 'CHECK: alpha\nCHECK-NEXT: gamma\n')"
  section "CHECK-NOT — a forbidden pattern is present, so it fails"
  run_expect_fail "printf 'alpha\nbeta\ngamma\n' | FileCheck <(printf 'CHECK: alpha\nCHECK-NOT: beta\nCHECK: gamma\n')"
  section "CHECK-COUNT-3 — exactly three in a row"
  run "printf 'x\nx\nx\n' | FileCheck <(printf 'CHECK-COUNT-3: x\n') && echo PASS"
  section "CHECK-DAG — matches in any order (both inputs pass)"
  run "printf 'one\ntwo\n' | FileCheck <(printf 'CHECK-DAG: one\nCHECK-DAG: two\n') && echo PASS"
  run "printf 'two\none\n' | FileCheck <(printf 'CHECK-DAG: one\nCHECK-DAG: two\n') && echo PASS"

  section "The directive demo file — test/filecheck_directives.mlir"
  echo ">> One input, four RUN pipelines — each prefix named after the configuration"
  echo ">> it checks (CSE, CANON, ERR), the standard upstream idiom. Read the comments."
  run "cat test/filecheck_directives.mlir"

  section "CHECK-LABEL — the loophole, on real IR (the default CHECK group)"
  echo ">> The default CHECK group is deliberately broken: it claims @dup_constants"
  echo ">> contains arith.addi — false, yet it PASSES: the plain check skips past the"
  echo ">> function's end and matches inside @add_zero."
  run "mlir-opt test/filecheck_directives.mlir | FileCheck test/filecheck_directives.mlir && echo 'PASS (but the assertion is wrong!)'"
  echo; echo ">> Wrap the same bogus assertion in CHECK-LABELs — now it's caught. (Note the"
  echo ">> second label: a block only ends at the NEXT label.)"
  run_expect_fail "mlir-opt test/filecheck_directives.mlir | FileCheck <(printf 'CHECK-LABEL: func.func @dup_constants\nCHECK: arith.addi\nCHECK-LABEL: func.func @add_zero\n')"

  section "The labeled groups done right — CSE and CANON"
  run "mlir-opt test/filecheck_directives.mlir -cse | FileCheck test/filecheck_directives.mlir --check-prefix=CSE && echo 'PASS (-cse collapses the duplicate constants)'"
  run "mlir-opt test/filecheck_directives.mlir -canonicalize | FileCheck test/filecheck_directives.mlir --check-prefix=CANON && echo 'PASS (-canonicalize folds x+0 away)'"

  section "CHECK-SAME rejects a next-line match"
  echo ">> Demand arith.addi on @add_zero's signature line — it exists, but on the"
  echo ">> NEXT line, so -SAME rejects it ('not on the same line as the previous match'):"
  run_expect_fail "mlir-opt test/filecheck_directives.mlir | FileCheck <(printf 'CHECK-LABEL: func.func @add_zero(\nCHECK-SAME: arith.addi\n')"

  section "\`not\` — testing the error path (the ERR group)"
  run "grep -n 'RUN:' test/filecheck_directives.mlir"
  echo ">> Replay the ERR RUN line exactly as lit would — \`not\` requires mlir-opt to"
  echo ">> FAIL, and FileCheck verifies the error message on stderr (2>&1):"
  run "not mlir-opt test/filecheck_directives.mlir -pass-pipeline='builtin.module(no-such-pass)' 2>&1 | FileCheck test/filecheck_directives.mlir --check-prefix=ERR && echo 'exit 0 — the required failure happened, with the right message'"
  echo; echo ">> Tutorial 3 examples complete."
}

chapter_04() {
  cd "$EXAMPLE"
  section "Tutorial 4 — patterns and variables"
  section "Step 1 — embed a regex with {{ ... }}"
  run "printf 'register r42\n' | FileCheck <(printf 'CHECK: register {{r[0-9]+}}\n') && echo PASS"

  section "Step 2 — capture a string variable and reuse it (the cse.mlir idiom)"
  run "mlir-opt test/cse.mlir -cse | FileCheck test/cse.mlir && echo 'PASS (both returns share one value)'"

  section "Step 2b — break the binding: a use with no definition (broken/undefined_var.mlir)"
  run_expect_fail "mlir-opt broken/undefined_var.mlir -cse | FileCheck broken/undefined_var.mlir"
  echo ">> Note 'undefined variable: OTHER' — captures are real bindings, not decoration."

  section "Step 2c — a capture attached to a label via -SAME (the CANON group)"
  echo ">> A CHECK-LABEL can't define variables; the -SAME continuation captures the"
  echo ">> argument from the signature line, and the folded function must return it:"
  run "mlir-opt test/filecheck_directives.mlir -canonicalize | FileCheck test/filecheck_directives.mlir --check-prefix=CANON && echo 'PASS (x+0 folds to returning the captured argument)'"

  section "Step 3 — numeric capture and arithmetic"
  run "printf 'load r3\nload r4\n' | FileCheck <(printf 'CHECK: load r[[#REG:]]\nCHECK: load r[[#REG+1]]\n') && echo PASS"
  echo; echo ">> Tutorial 4 examples complete."
}

chapter_05() {
  cd "$EXAMPLE"
  section "Tutorial 5 — MLIR testing conventions"
  section "A check test (canonicalize) via the lit runner"
  run "llvm-lit -v build/test --filter='canonicalize\.mlir'"
  section "A diagnostic test — note -verify-diagnostics in its RUN line"
  run "grep -nE 'RUN:|expected-' test/invalid.mlir"
  run "llvm-lit -v build/test --filter='invalid\.mlir'"
  echo; echo ">> Tutorial 5 examples complete."
}

chapter_06() {
  cd "$EXAMPLE"
  section "Tutorial 6 — write your own test (auto-discovered, no CMake edit)"
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

  section "Step 2 — draft exhaustive checks with generate-test-checks.py"
  local gtc="/tmp/generate-test-checks.py"
  if [[ ! -f "$gtc" ]]; then
    echo ">> fetching generate-test-checks.py (single self-contained script)…"
    curl -sLo "$gtc" \
      "https://raw.githubusercontent.com/llvm/llvm-project/release/20.x/mlir/utils/generate-test-checks.py" \
      || { echo ">> (offline? skipping this step — see Tutorial 6 in the README)"; gtc=""; }
  fi
  if [[ -n "$gtc" ]]; then
    echo ">> The script drafts CHECK lines from one concrete pass output;"
    echo ">> FileCheck then enforces them on every run. Review before pasting!"
    run "mlir-opt test/double_negate.mlir -canonicalize | python3 $gtc"
  fi
  echo ">> (test/double_negate.mlir is removed automatically on exit)"
  echo; echo ">> Tutorial 6 examples complete."
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
    echo "###  Tutorial $n"
    echo "###################################################################"
    run_chapter "$n"
  done
  echo; echo ">> All chapter examples completed successfully."
else
  run_chapter "$target"
fi
