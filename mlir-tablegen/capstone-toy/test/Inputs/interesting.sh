#!/usr/bin/env bash
# Interestingness test for test/reduce.mlir. mlir-reduce convention: exit 1 =
# interesting. "Interesting" = after -toy-fold the IR still contains a toy.sub
# (pretend that is the symptom we are chasing).
#
# toy-opt is found, in order: $TOY_OPT, `toy-opt` on PATH (lit.cfg.py puts the
# build dir there), or the default build directory next to this test tree.
HERE="$(cd "$(dirname "$0")" && pwd)"
TOY_OPT="${TOY_OPT:-$(command -v toy-opt || echo "$HERE/../../build/toy-opt")}"
"$TOY_OPT" "$1" -toy-fold 2>/dev/null | grep -q 'toy.sub' && exit 1
exit 0
