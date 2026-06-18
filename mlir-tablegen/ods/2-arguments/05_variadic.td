// =============================================================================
// ODS Lesson 5 — Variadic and Optional operands
//
//   Variadic<T>  - zero-or-more operands of type T (accessor returns a range).
//   Optional<T>  - zero-or-one operand.
//
//   An op with more than one variadic/optional operand must tell MLIR how to
//   tell them apart at runtime, via AttrSizedOperandSegments (an extra
//   `operandSegmentSizes` attribute) or the SameVariadicOperandSize trait.
// =============================================================================

include "mlir/IR/OpBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
}

class Toy_Op<string mnemonic, list<Trait> traits = []>
    : Op<Toy_Dialect, mnemonic, traits>;

// A single variadic operand: `toy.sum`(v0, v1, ...).
def SumOp : Toy_Op<"sum"> {
  let summary = "sums a variadic list of f64 values";
  let arguments = (ins Variadic<F64>:$inputs);
  let results = (outs F64:$result);
}

// One required operand plus an optional bias.
def AffineApplyOp : Toy_Op<"affine_apply"> {
  let summary = "x with an optional bias added";
  let arguments = (ins F64:$x, Optional<F64>:$bias);
  let results = (outs F64:$result);
}

// Two variadic operand groups need AttrSizedOperandSegments to disambiguate.
def ConcatOp : Toy_Op<"concat", [AttrSizedOperandSegments]> {
  let summary = "concatenates two variadic groups of values";
  let arguments = (ins Variadic<AnyType>:$lhs, Variadic<AnyType>:$rhs);
  let results = (outs AnyType:$result);
}
