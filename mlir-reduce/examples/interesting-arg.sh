#!/usr/bin/env bash
# Parameterised tester: the pattern comes from mlir-reduce's `test-arg=...`.
# Extra arguments are passed BEFORE the candidate path, so $1 = pattern,
# $2 = candidate file.
mlir-opt "$2" -canonicalize 2>/dev/null | grep -q "$1" && exit 1
exit 0
