// =============================================================================
// Attrs & Types Lesson 4 — Optional and default-valued parameters
//
//   OptionalParameter<"T">           - may be absent; stored as the given type
//                                      (often std::optional<...> / a null Attr).
//   DefaultValuedParameter<"T","v">  - absent in the assembly => the C++ default.
//
//   With the declarative assemblyFormat, optional/default parameters are elided
//   from the printed form when they hold the default/none.
// =============================================================================

include "mlir/IR/AttrTypeBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
  let useDefaultAttributePrinterParser = 1;
}

class Toy_Attr<string name, list<Trait> traits = []> : AttrDef<Toy_Dialect, name, traits>;

// #toy.tensor_spec<2 x 3>            (alignment defaulted, layout absent)
// #toy.tensor_spec<2 x 3, align = 8> (alignment given)
def Toy_TensorSpecAttr : Toy_Attr<"TensorSpec"> {
  let mnemonic = "tensor_spec";
  let parameters = (ins
      "int64_t":$rows,
      "int64_t":$cols,
      DefaultValuedParameter<"int64_t", "1">:$alignment,
      OptionalParameter<"::mlir::StringAttr">:$layout);
  // `struct` prints the trailing parameters as elidable `name = value` pairs.
  let assemblyFormat = "`<` $rows `x` $cols (`,` `align` `=` $alignment^)? (`,` `layout` `=` $layout^)? `>`";
}
