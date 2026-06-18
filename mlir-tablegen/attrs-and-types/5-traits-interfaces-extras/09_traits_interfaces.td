// =============================================================================
// Attrs & Types Lesson 9 — Traits and interfaces
//
//   Like ops, attributes and types can carry Traits (mixin methods/markers) and
//   Interfaces (a virtual API). They go in the trait list — the third argument
//   to AttrDef/TypeDef (forwarded through our Toy_Attr/Toy_Type base classes).
//
//     MemRefElementTypeInterface     - a marker interface: "usable as a memref
//                                       element type". Attaching it is enough.
//     DeclareTypeInterfaceMethods<I> - pull interface I's methods onto the type
//                                       and generate declarations to implement.
// =============================================================================

include "mlir/IR/AttrTypeBase.td"
include "mlir/IR/BuiltinTypeInterfaces.td"   // MemRefElementTypeInterface, etc.

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
  let useDefaultTypePrinterParser = 1;
}

class Toy_Type<string name, list<Trait> traits = []> : TypeDef<Toy_Dialect, name, traits>;

// Marker interface: declaring it lets !toy.scalar be used as a memref element
// type. No extra C++ needed for a pure marker interface.
def Toy_ScalarType : Toy_Type<"Scalar", [MemRefElementTypeInterface]> {
  let mnemonic = "scalar";
  let parameters = (ins "unsigned":$bitwidth);
  let assemblyFormat = "`<` $bitwidth `>`";
}
