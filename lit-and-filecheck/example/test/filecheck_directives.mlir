// A runnable demonstration of the FileCheck directive family (see the
// top-level README, Tutorial 3), written in the standard upstream idiom:
// ONE input file, several RUN pipelines, each verified by its own group of
// check directives selected with --check-prefix. The prefixes are named
// after the configuration they check — CSE for `-cse`, CANON for
// `-canonicalize`, ERR for the error path — exactly as real suites do.

// RUN: mlir-opt %s | FileCheck %s
// RUN: mlir-opt %s -cse | FileCheck %s --check-prefix=CSE
// RUN: mlir-opt %s -canonicalize | FileCheck %s --check-prefix=CANON
// RUN: not mlir-opt %s -pass-pipeline='builtin.module(no-such-pass)' 2>&1 | FileCheck %s --check-prefix=ERR

// Two functions; only the SECOND contains an arith.addi.
func.func @dup_constants() -> (i32, i32) {
  %0 = arith.constant 1 : i32
  %1 = arith.constant 1 : i32
  return %0, %1 : i32, i32
}

func.func @add_zero(%arg0: i32) -> i32 {
  %c0 = arith.constant 0 : i32
  %0 = arith.addi %arg0, %c0 : i32
  return %0 : i32
}

// The default CHECK group (first RUN line: no pass, mlir-opt just re-prints)
// is DELIBERATELY BROKEN as a lesson: it claims @dup_constants contains an
// arith.addi — false — yet it passes, because a plain check may skip any
// number of lines, including the end of @dup_constants, so it finds the
// arith.addi inside @add_zero. Real tests prevent this with CHECK-LABEL,
// as the two groups below do.
// CHECK: func.func @dup_constants
// CHECK: arith.addi

// The CSE group checks `-cse`: the two identical constants collapse into
// one. CHECK-LABEL confines the group to @dup_constants; the capture
// %[[C1:...]] is reused to prove both returned values are that single
// surviving constant.
// CSE-LABEL: func.func @dup_constants
// CSE-NEXT: %[[C1:.*]] = arith.constant 1
// CSE-NEXT: return %[[C1]], %[[C1]]

// The CANON group checks `-canonicalize`: x + 0 folds away entirely and the
// function returns its own argument. The label can't hold a capture, so the
// CANON-SAME continuation captures %[[ARG]] from the same signature line;
// CANON-NOT proves the addi is gone.
// CANON-LABEL: func.func @add_zero(
// CANON-SAME: %[[ARG:.*]]: i32
// CANON-NOT: arith.addi
// CANON: return %[[ARG]]

// The ERR group checks the ERROR PATH: `not` inverts mlir-opt's failing exit
// code (the test passes only if mlir-opt fails), and FileCheck verifies the
// message on stderr (2>&1). This not-plus-ERR pattern is how real suites
// lock in "this must be rejected" behavior.
// ERR: 'no-such-pass' does not refer to a registered pass
