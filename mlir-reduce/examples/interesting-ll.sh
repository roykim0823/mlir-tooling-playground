#!/usr/bin/env bash
# Interestingness test for llvm-reduce.
#
# Contract: llvm-reduce runs this with the candidate .ll path as the LAST
# argument (extra arguments from --test-arg come first) and treats exit code 0
# as "interesting" — the opposite of mlir-reduce.
#
# The symptom: instcombine keeps a udiv in the output. (Note the divisor in
# big.ll is 3, not 2: a division by a power of two becomes a shift and the
# symptom would vanish on the ORIGINAL input, which llvm-reduce rejects with
# "Input isn't interesting!".)
opt -passes=instcombine -S "$1" 2>/dev/null | grep -q 'udiv'
