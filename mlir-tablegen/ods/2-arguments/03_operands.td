// =============================================================================
// ODS Lesson 3 — Operands (the `ins` dag)
//
//   An op's inputs are declared in `arguments = (ins ...)`. Operands are SSA
//   values with a *type constraint*; each gets a `$name` so ODS can generate a
//   typed accessor (e.g. `op.getLhs()`).
//
//   Common type constraints: AnyType, AnyInteger, Index, F32, F64, I32, I64,
//   AnyFloat, AnyTensor, F64Tensor, ...
// =============================================================================

include "mlir/IR/OpBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
}

class Toy_Op<string mnemonic, list<Trait> traits = []>
    : Op<Toy_Dialect, mnemonic, traits>;

// Two F64 operands -> generated accessors getLhs() / getRhs().
def AddOp : Toy_Op<"add"> {
  let summary = "adds two f64 values";
  let arguments = (ins F64:$lhs, F64:$rhs);
  let results = (outs F64:$result);
}

// Operands can use looser constraints. AnyType matches any SSA value type.
def SelectOp : Toy_Op<"select"> {
  let summary = "selects between two values based on a predicate";
  let arguments = (ins I1:$cond, AnyType:$true_val, AnyType:$false_val);
  let results = (outs AnyType:$result);
}
