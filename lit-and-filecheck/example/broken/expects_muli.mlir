// An intentionally FAILING test, used by Tutorial 2 in ../../README.md.
// It lives in broken/ (NOT test/) so lit never discovers it — the real suite
// stays green. Run it by hand to read FileCheck's diagnostic:
//
//   mlir-opt broken/expects_muli.mlir -cse | FileCheck broken/expects_muli.mlir --dump-input=fail
//
// The CHECK demands an op that CSE never produces, so FileCheck fails: it names
// the directive, the string it wanted (arith.muli), and shows the scanned input.

// CHECK: arith.muli
func.func @simple_constant() -> (i32, i32) {
  %0 = arith.constant 1 : i32
  %1 = arith.constant 1 : i32
  return %0, %1 : i32, i32
}
