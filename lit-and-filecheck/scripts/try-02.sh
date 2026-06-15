#!/usr/bin/env bash
# Runs the "Try it" commands from 02-filecheck-basics.md.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

cd "$EXAMPLE"

section "Chapter 2 — FileCheck basics"

section "1) See the raw transformed IR (what FileCheck will receive)"
run "mlir-opt test/cse.mlir -cse"

section "2) Verify it — silence + exit 0 means pass"
run "mlir-opt test/cse.mlir -cse | FileCheck test/cse.mlir && echo 'exit code: '\$?"

section "3) Make it FAIL on purpose to read the diagnostic"
run_expect_fail "mlir-opt test/cse.mlir -cse | FileCheck <(echo '// CHECK: arith.muli')"

echo; echo ">> Chapter 2 examples complete."
