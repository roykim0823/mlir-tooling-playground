// =============================================================================
// Attrs & Types Lesson 8 — Verification (genVerifyDecl)
//
//   Set `genVerifyDecl = 1` to have ODS generate a verifier hook that runs when
//   the attribute/type is constructed (via the `getChecked` path):
//
//     static LogicalResult verify(
//         function_ref<InFlightDiagnostic()> emitError, <params...>);
//
//   You implement it in C++ to reject invalid parameter combinations. The
//   generated `get` stays unchecked; `getChecked` calls `verify` first.
// =============================================================================

include "mlir/IR/AttrTypeBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
  let useDefaultTypePrinterParser = 1;
}

class Toy_Type<string name, list<Trait> traits = []> : TypeDef<Toy_Dialect, name, traits>;

// A fixed-point type whose fractional bits must not exceed the total width —
// a constraint that can't be expressed declaratively, so we verify in C++.
def Toy_FixedType : Toy_Type<"Fixed"> {
  let mnemonic = "fixed";
  let summary = "a fixed-point number type";
  let parameters = (ins "unsigned":$totalBits, "unsigned":$fractionalBits);
  let assemblyFormat = "`<` $totalBits `,` $fractionalBits `>`";
  let genVerifyDecl = 1;
}
