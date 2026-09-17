#!/usr/bin/env bash
# Interestingness test for mlir-reduce.
#
# Contract: mlir-reduce runs this with ONE argument, the path of a candidate
# file, and treats exit code 1 as "interesting" (the candidate still shows the
# symptom) and 0 as "not interesting". (llvm-reduce uses the OPPOSITE
# convention — see interesting-ll.sh.)
#
# The symptom here: after -canonicalize the IR still contains an arith.divui in
# @suspect. FileCheck reads its CHECK lines from THIS file ($0), so the script
# is self-contained; `2>/dev/null` makes a candidate that does not even parse
# count as "not interesting" instead of erroring out.
mlir-opt "$1" -canonicalize 2>/dev/null | FileCheck "$0" >/dev/null 2>&1 && exit 1
exit 0
# CHECK: func.func @suspect
# CHECK: arith.divui
