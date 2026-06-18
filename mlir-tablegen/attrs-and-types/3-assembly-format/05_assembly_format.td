// =============================================================================
// Attrs & Types Lesson 5 — Declarative assemblyFormat & directives
//
//   `assemblyFormat` describes parsing/printing declaratively (no hand-written
//   C++). Beyond literals and $param references it offers directives:
//
//     params         - all parameters, comma-separated
//     struct($a,$b)  - `name = value` pairs, order-independent on parse
//     qualified($p)  - print a nested attr/type with its full `#dialect.` form
//     custom<Foo>(..)- delegate one slice to a C++ parse/printFoo pair
//     `<` `>`        - literal keywords/punctuation (in backticks)
// =============================================================================

include "mlir/IR/AttrTypeBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
  let useDefaultAttributePrinterParser = 1;
}

class Toy_Attr<string name, list<Trait> traits = []> : AttrDef<Toy_Dialect, name, traits>;

// `params`: simplest possible — print every parameter in order.
// #toy.point<1, 2>
def Toy_PointAttr : Toy_Attr<"Point"> {
  let mnemonic = "point";
  let parameters = (ins "int64_t":$x, "int64_t":$y);
  let assemblyFormat = "`<` params `>`";
}

// `struct`: print parameters as order-independent `key = value` pairs.
// #toy.config<width = 8, signed = 1>
def Toy_ConfigAttr : Toy_Attr<"Config"> {
  let mnemonic = "config";
  let parameters = (ins "int64_t":$width, "int64_t":$isSigned);
  let assemblyFormat = "`<` struct(params) `>`";
}

// `qualified`: force the nested attribute to print with its `#toy.` prefix.
// #toy.boxed<#toy.point<1, 2>>
def Toy_BoxedAttr : Toy_Attr<"Boxed"> {
  let mnemonic = "boxed";
  let parameters = (ins "::toy::PointAttr":$inner);
  let assemblyFormat = "`<` qualified($inner) `>`";
}
