// Several independent inputs in ONE test file, via LLVM's `split-file`.
//
// `split-file %s %t` cuts this file at every `//--- NAME` marker and writes
// each part to %t/NAME (%t becomes a directory). Everything above the first
// marker — these RUN lines — is discarded, so it is the natural place for them.
// Each part is then a complete, standalone .mlir file: it can carry its own
// CHECK lines and be given to any tool, unlike mlir-opt's `-split-input-file`,
// which only splits for diagnostics and only inside mlir-opt (see Tutorial 5).
//
// RUN: split-file %s %t
// RUN: mlir-opt %t/cse.mlir -cse | FileCheck %t/cse.mlir
// RUN: mlir-opt %t/canon.mlir -canonicalize | FileCheck %t/canon.mlir
// RUN: not mlir-opt %t/bad.mlir 2>&1 | FileCheck %t/bad.mlir

//--- cse.mlir
// CHECK-LABEL: func.func @dup
func.func @dup() -> (i32, i32) {
  // CHECK: %[[C:.*]] = arith.constant 7
  // CHECK-NEXT: return %[[C]], %[[C]]
  %0 = arith.constant 7 : i32
  %1 = arith.constant 7 : i32
  return %0, %1 : i32, i32
}

//--- canon.mlir
// CHECK-LABEL: func.func @times_one
func.func @times_one(%x: i32) -> i32 {
  // CHECK-NOT: arith.muli
  %c1 = arith.constant 1 : i32
  %0 = arith.muli %x, %c1 : i32
  return %0 : i32
}

//--- bad.mlir
// A part that must FAIL to parse: `not` inverts mlir-opt's exit code and
// FileCheck pins the message. This could not share a file with the two valid
// parts without split-file — one parse error would sink everything.
// CHECK: error: use of value '%b' expects different type than prior uses: 'i32' vs 'i64'
func.func @bad(%a: i32, %b: i64) -> i32 {
  %0 = arith.addi %a, %b : i32
  return %0 : i32
}
