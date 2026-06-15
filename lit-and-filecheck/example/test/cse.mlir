// RUN: mlir-opt %s -cse | FileCheck %s

// Demonstrates: CHECK-LABEL (block boundary), CHECK-NEXT (adjacency), and a
// captured string variable reused to prove a data-flow relationship.
//
// After common-subexpression elimination the two identical constants collapse
// into one SSA value, and BOTH returns must reference that same value.

// CHECK-LABEL: func.func @simple_constant
func.func @simple_constant() -> (i32, i32) {
  // CHECK-NEXT: %[[RESULT:.*]] = arith.constant 1
  // CHECK-NEXT: return %[[RESULT]], %[[RESULT]]
  %0 = arith.constant 1 : i32
  %1 = arith.constant 1 : i32
  return %0, %1 : i32, i32
}
