#!/usr/bin/env bash
# Runs the six labs from 06-hands-on.md. Labs 4 and 5 add/append test files;
# this script backs them up and restores them on exit so it is safe to re-run.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

ensure_built
cd "$EXAMPLE"

# --- Restore any files the labs touch, no matter how the script exits. --------
INVALID_BAK="$(mktemp)"
cp test/invalid.mlir "$INVALID_BAK"
cleanup() {
  rm -f test/double_negate.mlir
  [[ -f "$INVALID_BAK" ]] && cp "$INVALID_BAK" test/invalid.mlir && rm -f "$INVALID_BAK"
  rm -f /tmp/lit_ex_out.mlir
}
trap cleanup EXIT

section "Chapter 6 — hands-on"

section "Lab 1 — run a single test three ways"
run "cmake --build build --target check"
run "llvm-lit -v build/test --filter='cse\.mlir'"
run "mlir-opt test/cse.mlir -cse > /tmp/lit_ex_out.mlir && FileCheck test/cse.mlir < /tmp/lit_ex_out.mlir && echo PASS"
run "cat /tmp/lit_ex_out.mlir"

section "Lab 2 — read a failure"
run_expect_fail "mlir-opt test/cse.mlir -cse | FileCheck <(printf '// CHECK: arith.muli\n') --dump-input=fail"

section "Lab 3 — break a captured variable (expect 'undefined variable')"
BROKEN="$(mktemp --suffix=.mlir)"
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
