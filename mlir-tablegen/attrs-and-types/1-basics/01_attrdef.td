// =============================================================================
// Attrs & Types Lesson 1 — Defining a custom attribute (AttrDef)
//
//   A dialect can define its own *attribute* kinds (compile-time values such as
//   #toy.shape<3 x 4>) by specializing the `AttrDef` class. mlir-tblgen emits
//   the C++ attribute class via --gen-attrdef-decls / --gen-attrdef-defs.
//
//   The pieces:
//     mnemonic        -> the keyword after the dialect prefix (#toy.<mnemonic>)
//     parameters      -> the stored fields (Lesson 2 goes deeper)
//     assemblyFormat  -> the textual syntax (Lesson 5 goes deeper)
//     cppClassName    -> override the default `<name>Attr` C++ class name
// =============================================================================

include "mlir/IR/AttrTypeBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
  // Needed so the dialect can parse/print its attributes by mnemonic.
  let useDefaultAttributePrinterParser = 1;
}

// Base class pinning attributes to the Toy dialect (mirrors the Toy_Op pattern).
class Toy_Attr<string name, list<Trait> traits = []>
    : AttrDef<Toy_Dialect, name, traits>;

// Generates `class ShapeAttr` in namespace ::toy. Printed as #toy.shape<3 x 4>.
def Toy_ShapeAttr : Toy_Attr<"Shape"> {
  let mnemonic = "shape";
  let summary = "a static 2-D shape";
  let description = [{
    The `#toy.shape` attribute stores a fixed number of rows and columns.
  }];
  let parameters = (ins "int64_t":$rows, "int64_t":$cols);
  let assemblyFormat = "`<` $rows `x` $cols `>`";
}
