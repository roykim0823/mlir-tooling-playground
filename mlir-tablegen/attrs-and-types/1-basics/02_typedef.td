// =============================================================================
// Attrs & Types Lesson 2 — Defining a custom type (TypeDef)
//
//   Types are structurally identical to attributes: specialize `TypeDef`
//   instead of `AttrDef`. Emitted via --gen-typedef-decls / --gen-typedef-defs.
//   `cppClassName` overrides the default `<name>Type` C++ name.
// =============================================================================

include "mlir/IR/AttrTypeBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
  let useDefaultTypePrinterParser = 1;
}

class Toy_Type<string name, list<Trait> traits = []>
    : TypeDef<Toy_Dialect, name, traits>;

// !toy.int<32> — a sized integer type. C++ class IntegerType... would clash, so
// override the generated class name with cppClassName.
def Toy_IntType : Toy_Type<"Int"> {
  let mnemonic = "int";
  let summary = "a sized integer type";
  let cppClassName = "ToyIntType";
  let parameters = (ins "unsigned":$width);
  let assemblyFormat = "`<` $width `>`";
}
