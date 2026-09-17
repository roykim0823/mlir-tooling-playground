// toy-reduce (tools/toy-reduce.cpp): mlir-reduce for the Toy dialect. The
// interestingness script is Inputs/interesting.sh — "the output of -toy-fold
// still contains a toy.sub". Everything not needed to keep that true goes:
// the unrelated function and the dead toy.mul.
//
// RUN: toy-reduce %s -reduction-tree='traversal-mode=0 test=%S/Inputs/interesting.sh' -o %t 2>/dev/null
// RUN: FileCheck %s < %t

// CHECK-NOT: func.func @unrelated
func.func @unrelated() -> f64 {
  %0 = toy.constant 1.0
  %1 = toy.constant 2.0
  %2 = toy.add %0, %1
  return %2 : f64
}

// CHECK-LABEL: func.func @suspect
func.func @suspect(%x: f64) -> f64 {
  // CHECK-NOT: toy.mul %{{.*}}, %{{.*}} : f64{{$}}
  %c3 = toy.constant 3.0
  %c1 = toy.constant 1.0
  %dead = toy.mul %x, %c3
  // CHECK: toy.sub
  %0 = toy.mul %x, %c1
  %1 = toy.sub %0, %c3
  %2 = toy.add %1, %x
  return %2 : f64
}
