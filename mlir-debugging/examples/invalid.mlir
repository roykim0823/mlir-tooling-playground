// Input for the diagnostics section: fails the verifier (operand types differ).
// The expected-error line makes it also usable with -verify-diagnostics.
func.func @bad(%a: i32, %b: i64) -> i32 {
  // expected-error @+1 {{'arith.addi' op requires the same type for all operands and results}}
  %0 = "arith.addi"(%a, %b) : (i32, i64) -> i32
  return %0 : i32
}
