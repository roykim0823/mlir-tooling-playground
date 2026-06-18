// =============================================================================
// ODS Lesson 6 — Results (the `outs` dag)
//
//   Results are declared in `results = (outs ...)`, mirroring operands. They
//   support the same type constraints and Variadic<T>. Multiple variadic
//   results need AttrSizedResultSegments (or SameVariadicResultSize).
// =============================================================================

include "mlir/IR/OpBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
}

class Toy_Op<string mnemonic, list<Trait> traits = []>
    : Op<Toy_Dialect, mnemonic, traits>;

// Two results -> getQuotient() / getRemainder().
def DivModOp : Toy_Op<"divmod"> {
  let summary = "integer division returning quotient and remainder";
  let arguments = (ins I64:$lhs, I64:$rhs);
  let results = (outs I64:$quotient, I64:$remainder);
}

// A variadic result group.
def UnpackOp : Toy_Op<"unpack"> {
  let summary = "unpacks an aggregate into a variadic number of values";
  let arguments = (ins AnyType:$input);
  let results = (outs Variadic<AnyType>:$results);
}
