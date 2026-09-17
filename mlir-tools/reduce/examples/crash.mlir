// Input for the mlir-reduce sections. The story: "-canonicalize miscompiles
// something involving arith.divui, and this is the module where we noticed".
// We want the SMALLEST module that still shows the symptom, which the tester
// (interesting.sh) defines as "after -canonicalize, an arith.divui remains".
//
// Two whole functions and two dead ops are irrelevant to that; the reducer
// should remove exactly those.
func.func @unrelated_a(%x: i32) -> i32 {
  %c1 = arith.constant 1 : i32
  %0 = arith.addi %x, %c1 : i32
  %1 = arith.muli %0, %c1 : i32
  return %1 : i32
}
func.func @suspect(%a: i32, %b: i32, %c: i32) -> i32 {
  %c2 = arith.constant 2 : i32
  %c0 = arith.constant 0 : i32
  %dead1 = arith.muli %a, %c2 : i32          // unused
  %dead2 = arith.xori %dead1, %b : i32       // unused
  %0 = arith.addi %a, %b : i32
  %1 = arith.subi %0, %c : i32
  %2 = arith.divui %1, %c2 : i32             // the op the symptom depends on
  %3 = arith.addi %2, %c0 : i32              // x + 0: canonicalize folds it away
  return %3 : i32
}
func.func @unrelated_b(%x: f32) -> f32 {
  %0 = arith.mulf %x, %x : f32
  %1 = arith.addf %0, %x : f32
  return %1 : f32
}
