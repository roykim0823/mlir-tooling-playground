// =============================================================================
// ODS Lesson 10 — Declarative assembly format
//
//   `assemblyFormat` describes how the op parses/prints in textual IR, so you
//   don't hand-write a parser/printer. It interleaves literals (in backticks),
//   operand/attribute references ($name), and type directives.
//
//   Building blocks: `literal`, $operand, $attr, type($x), functional-type(...),
//   attr-dict, operands, optional groups `(... )?`.
// =============================================================================

include "mlir/IR/OpBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
}

class Toy_Op<string mnemonic, list<Trait> traits = []>
    : Op<Toy_Dialect, mnemonic, traits>;

// Prints as:  %r = toy.add %a, %b : f64
def AddOp : Toy_Op<"add"> {
  let summary = "add with a custom textual form";
  let arguments = (ins F64:$lhs, F64:$rhs);
  let results = (outs F64:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
}

// Prints as:  %r = toy.cast %in : i32 to i64
def CastOp : Toy_Op<"cast"> {
  let summary = "cast with input/output types in the format";
  let arguments = (ins AnyType:$input);
  let results = (outs AnyType:$output);
  let assemblyFormat = "$input attr-dict `:` type($input) `to` type($output)";
}
