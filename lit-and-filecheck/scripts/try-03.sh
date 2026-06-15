#!/usr/bin/env bash
# Runs the "Try it" commands from 03-filecheck-directives.md.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

cd "$EXAMPLE"

section "Chapter 3 — FileCheck directives"

section "Inspect the output, then watch the directives match it (--dump-input=fail)"
run "mlir-opt test/cse.mlir -cse | FileCheck test/cse.mlir --dump-input=fail && echo PASS"

section "Bonus: the same on canonicalize.mlir (CHECK-NOT + plain CHECK)"
run "mlir-opt test/canonicalize.mlir -canonicalize | FileCheck test/canonicalize.mlir && echo PASS"

echo; echo ">> Chapter 3 examples complete."
