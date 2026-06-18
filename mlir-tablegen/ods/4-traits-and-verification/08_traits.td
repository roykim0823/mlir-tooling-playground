// =============================================================================
// ODS Lesson 8 — Traits
//
//   Traits attach reusable semantics/verification to an op. They are the third
//   argument to `Op<...>` (forwarded through our Toy_Op base class). Some are
//   plain (defined in OpBase.td); others come from interface includes.
//
//   Common ones:
//     Pure                        - no side effects + speculatable (interfaces)
//     Commutative                 - operand order does not matter
//     SameOperandsAndResultType   - operands and result share one type
//     Terminator                  - ends a block
// =============================================================================

include "mlir/IR/OpBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"   // Pure
include "mlir/Interfaces/InferTypeOpInterface.td"   // SameOperandsAndResultType

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
}

class Toy_Op<string mnemonic, list<Trait> traits = []>
    : Op<Toy_Dialect, mnemonic, traits>;

// Pure + Commutative + same-type: a textbook arithmetic op. Because the result
// type is inferred from the operands, ODS generates an extra builder that does
// not require you to pass the result type.
def AddOp : Toy_Op<"add", [Pure, Commutative, SameOperandsAndResultType]> {
  let summary = "pure, commutative addition";
  let arguments = (ins F64:$lhs, F64:$rhs);
  let results = (outs F64:$result);
}

// Pure unary op.
def NegOp : Toy_Op<"neg", [Pure, SameOperandsAndResultType]> {
  let summary = "pure negation";
  let arguments = (ins F64:$operand);
  let results = (outs F64:$result);
}
