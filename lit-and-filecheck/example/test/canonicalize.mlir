// RUN: mlir-opt %s -canonicalize | FileCheck %s

// Demonstrates: CHECK-NOT (a pattern must NOT appear) plus a plain CHECK.
//
// Canonicalization folds `x + 0` into `x`, so the add (and the now-dead
// constant) disappear entirely and the function just returns its argument.

// CHECK-LABEL: func.func @add_zero
// CHECK-NOT:   arith.addi
// CHECK:       return %arg0
func.func @add_zero(%arg0: i32) -> i32 {
  %0 = arith.constant 0 : i32
  %1 = arith.addi %arg0, %0 : i32
  return %1 : i32
}
