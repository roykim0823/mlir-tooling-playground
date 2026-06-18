// =============================================================================
// ODS Lesson 9 — Constraints and custom verification
//
//   Beyond fixed types you can constrain operands/results/attributes more
//   tightly, and ask ODS to emit a verifier hook for logic that can't be
//   expressed declaratively.
//
//     ConfinedAttr<Attr, [...]> - refine an attribute (e.g. non-negative int)
//     AllTypesMatch<[...]>     - cross-entity type equality
//     PredOpTrait / custom Pred - arbitrary predicate over the op
//     let hasVerifier = 1;     - emit `LogicalResult verify();` to hand-write
// =============================================================================

include "mlir/IR/OpBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
}

class Toy_Op<string mnemonic, list<Trait> traits = []>
    : Op<Toy_Dialect, mnemonic, traits>;

// A refined attribute constraint: the rank must be a non-negative I64.
def ReshapeOp : Toy_Op<"reshape", [
    AllTypesMatch<["input", "result"]>     // input and result share a type
]> {
  let summary = "reshape with a verified, non-negative rank attribute";
  let arguments = (ins
      AnyType:$input,
      ConfinedAttr<I64Attr, [IntNonNegative]>:$rank
  );
  let results = (outs AnyType:$result);
}

// `hasVerifier = 1` makes ODS declare `LogicalResult verify();` so you can add
// checks that declarative constraints can't express. You implement it in C++.
def RangeOp : Toy_Op<"range"> {
  let summary = "an integer range [lo, hi) verified in C++";
  let arguments = (ins I64:$lo, I64:$hi);
  let results = (outs AnyType:$result);
  let hasVerifier = 1;
}
