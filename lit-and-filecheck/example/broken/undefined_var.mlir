// An intentionally FAILING test, used by Tutorial 2 in ../../README.md.
// It lives in broken/ (NOT test/) so lit never discovers it — the real suite
// stays green. Run it by hand to read FileCheck's diagnostic:
//
//   mlir-opt broken/undefined_var.mlir -cse | FileCheck broken/undefined_var.mlir
//
// The first CHECK-NEXT defines RESULT; the second *uses* %[[OTHER]], which was
// never defined. FileCheck reports "undefined variable: OTHER" — proving captured
// variables are real bindings, not decoration.

// CHECK-LABEL: func.func @simple_constant
// CHECK-NEXT: %[[RESULT:.*]] = arith.constant 1
// CHECK-NEXT: return %[[RESULT]], %[[OTHER]]
func.func @simple_constant() -> (i32, i32) {
  %0 = arith.constant 1 : i32
  %1 = arith.constant 1 : i32
  return %0, %1 : i32, i32
}
