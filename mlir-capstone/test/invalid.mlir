// Diagnostic tests: the ODS-generated verifiers and parsers reject bad IR with
// the expected message. -split-input-file runs each chunk (separated by a line
// of dashes) on its own, so one file can hold several independent errors.
//
// RUN: toy-opt %s -split-input-file -verify-diagnostics

// The F64 operand constraint from `let arguments = (ins F64:$lhs, F64:$rhs)`.
func.func @add_wrong_type(%a: i32, %b: i32) {
  // expected-error @+1 {{'toy.add' op operand #0 must be 64-bit float, but got 'i32'}}
  %0 = "toy.add"(%a, %b) : (i32, i32) -> f64
  return
}

// -----

// The F64Attr constraint on toy.constant's `value`.
func.func @constant_wrong_attr() {
  // expected-error @+1 {{'toy.constant' op attribute 'value' failed to satisfy constraint: 64-bit float attribute}}
  %0 = "toy.constant"() {value = 1 : i32} : () -> f64
  return
}

// -----

// The generated attribute parser (from `assemblyFormat`) wants two dimensions.
func.func @shape_attr_missing_dim() attributes {
  // expected-error @+1 {{expected 'x'}}
  toy.shape = #toy.shape<3>
} {
  return
}
