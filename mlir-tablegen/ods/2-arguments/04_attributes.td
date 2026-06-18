// =============================================================================
// ODS Lesson 4 — Attributes (compile-time constants in `ins`)
//
//   Attributes are *compile-time* values (not SSA operands) and also live in
//   the `arguments` dag, mixed freely with operands. ODS generates typed
//   accessors and folds them into the op's attribute dictionary.
//
//   Flavors:
//     PlainAttr                 - required
//     OptionalAttr<Attr>        - may be absent (accessor returns null/none)
//     DefaultValuedAttr<Attr,"v"> - absent => the given C++ default
// =============================================================================

include "mlir/IR/OpBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
}

class Toy_Op<string mnemonic, list<Trait> traits = []>
    : Op<Toy_Dialect, mnemonic, traits>;

// A required F64 attribute carrying the constant's value.
def ConstantOp : Toy_Op<"constant"> {
  let summary = "materializes a constant f64";
  let arguments = (ins F64Attr:$value);
  let results = (outs F64:$result);
}

// Operands and attributes mixed; optional + default-valued attributes.
def ConvOp : Toy_Op<"conv"> {
  let summary = "a convolution-ish op showcasing attribute flavors";
  let arguments = (ins
      AnyType:$input,
      I64Attr:$stride,                              // required
      DefaultValuedAttr<I64Attr, "1">:$dilation,    // default = 1
      OptionalAttr<StrAttr>:$name                   // may be omitted
  );
  let results = (outs AnyType:$result);
}
