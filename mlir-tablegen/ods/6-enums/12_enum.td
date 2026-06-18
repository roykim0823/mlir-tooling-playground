// =============================================================================
// ODS Lesson 12 — Enums (EnumAttr)
//
//   ODS can generate a C++ enum + an attribute wrapping it. Define the cases
//   with I32EnumAttrCase, the enum with I32EnumAttr, then (optionally) wrap it
//   as a dialect attribute with EnumAttr so it carries a nice assembly form.
//   Emitted via `--gen-enum-decls` / `--gen-enum-defs`.
// =============================================================================

include "mlir/IR/OpBase.td"
include "mlir/IR/AttrTypeBase.td"
include "mlir/IR/EnumAttr.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
}

class Toy_Op<string mnemonic, list<Trait> traits = []>
    : Op<Toy_Dialect, mnemonic, traits>;

// The underlying enum: three int32 cases -> C++ `enum class Comparison`.
def CMP_EQ : I32EnumAttrCase<"eq", 0>;
def CMP_LT : I32EnumAttrCase<"lt", 1>;
def CMP_GT : I32EnumAttrCase<"gt", 2>;

def Comparison : I32EnumAttr<"Comparison", "comparison predicate",
                             [CMP_EQ, CMP_LT, CMP_GT]> {
  let cppNamespace = "::toy";
}

// Wrap the enum as a dialect attribute so it can be used in `arguments`.
def ComparisonAttr : EnumAttr<Toy_Dialect, Comparison, "comparison">;

def CmpOp : Toy_Op<"cmp"> {
  let summary = "compares two values using a predicate enum attribute";
  let arguments = (ins ComparisonAttr:$predicate, F64:$lhs, F64:$rhs);
  let results = (outs I1:$result);
}
