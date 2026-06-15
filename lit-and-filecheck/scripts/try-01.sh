#!/usr/bin/env bash
# Runs the "Try it" commands from 01-lit-basics.md.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

ensure_built
cd "$EXAMPLE"

section "Chapter 1 — lit basics"

section "1) List every discovered test without running anything"
run "llvm-lit --show-tests build/test"

section "2) Run just one test, verbosely"
run "llvm-lit -v build/test --filter='cse\.mlir'"

section "3) Run all tests and time each one"
run "llvm-lit -v --time-tests build/test"

echo; echo ">> Chapter 1 examples complete."
