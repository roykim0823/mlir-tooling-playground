// =============================================================================
// Attrs & Types Lesson 10 — Extra declarations & a note on storage
//
//   `extraClassDeclaration` injects arbitrary C++ into the generated class —
//   handy for derived accessors/helpers built on top of the parameters. There
//   is also `extraClassDefinition` for out-of-line bodies.
//
//   Storage (advanced): by default ODS generates the uniqued storage class. Set
//   `let genStorageClass = 0;` to hand-write it (defining KeyTy, construct(),
//   hashKey, ==). Mutable attrs/types keep an immutable key but allow a
//   post-construction `mutate(...)`. Both are beyond this lesson; we just show
//   the common `extraClassDeclaration` here.
// =============================================================================

include "mlir/IR/AttrTypeBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
  let useDefaultTypePrinterParser = 1;
}

class Toy_Type<string name, list<Trait> traits = []> : TypeDef<Toy_Dialect, name, traits>;

// A 2-D shape type with derived helpers added via extraClassDeclaration.
def Toy_GridType : Toy_Type<"Grid"> {
  let mnemonic = "grid";
  let parameters = (ins "int64_t":$rows, "int64_t":$cols);
  let assemblyFormat = "`<` $rows `x` $cols `>`";

  let extraClassDeclaration = [{
    // Total number of cells — a convenience built on the stored parameters.
    int64_t getNumElements() const { return getRows() * getCols(); }
    bool isSquare() const { return getRows() == getCols(); }
  }];
}
