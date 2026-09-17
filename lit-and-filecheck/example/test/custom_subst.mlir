// Custom `%{name}` substitutions, defined in lit.cfg.py:
//
//   %{canon}         -> mlir-opt %s -canonicalize
//   %{canon-generic} -> %{canon} --mlir-print-op-generic     (nested!)
//
// They keep RUN lines short and, more importantly, let a whole suite change
// its pipeline in ONE place. The nested one only works because lit.cfg.py sets
// config.recursiveExpansionLimit; without it `%{canon}` inside the replacement
// stays literal and the RUN line fails with "command not found".
//
// RUN: %{canon} | FileCheck %s
// RUN: %{canon-generic} | FileCheck %s --check-prefix=GENERIC

// CHECK-LABEL: func.func @times_one
// CHECK-NOT: arith.muli
// GENERIC: "func.func"()
// GENERIC-NOT: "arith.muli"
func.func @times_one(%x: i32) -> i32 {
  %c1 = arith.constant 1 : i32
  %0 = arith.muli %x, %c1 : i32
  return %0 : i32
}
