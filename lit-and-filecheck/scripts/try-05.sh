#!/usr/bin/env bash
# Runs the "Try it" commands from 05-mlir-testing.md.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

ensure_built
cd "$EXAMPLE"

section "Chapter 5 — MLIR testing conventions"

section "A check test (canonicalize)"
run "llvm-lit -v build/test --filter='canonicalize\.mlir'"

section "A diagnostic test — note -verify-diagnostics in its RUN line"
run "grep -nE 'RUN:|expected-' test/invalid.mlir"
run "llvm-lit -v build/test --filter='invalid\.mlir'"

echo; echo ">> Chapter 5 examples complete."
