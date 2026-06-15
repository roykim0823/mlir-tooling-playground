#!/usr/bin/env bash
# Runs the "Try it" commands from 04-filecheck-variables.md.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

cd "$EXAMPLE"

section "Chapter 4 — patterns and variables"

section "1) The capture-and-reuse test (both returns share one value after CSE)"
run "cat test/cse.mlir"
run "mlir-opt test/cse.mlir -cse | FileCheck test/cse.mlir && echo PASS"

section "2) Experiment: point one use at an undefined variable -> error"
TMP="$(mktemp --suffix=.mlir)"
trap 'rm -f "$TMP"' EXIT
run "sed 's/%\[\[RESULT\]\], %\[\[RESULT\]\]/%[[RESULT]], %[[OTHER]]/' test/cse.mlir > '$TMP'"
run_expect_fail "mlir-opt test/cse.mlir -cse | FileCheck '$TMP'"
echo ">> Note the 'undefined variable: OTHER' — captures are real bindings, not decoration."

echo; echo ">> Chapter 4 examples complete."
