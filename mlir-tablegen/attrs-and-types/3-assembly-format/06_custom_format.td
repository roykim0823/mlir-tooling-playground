// =============================================================================
// Attrs & Types Lesson 6 — Hand-written parser/printer (hasCustomAssemblyFormat)
//
//   When the declarative format can't express the syntax you want, set
//   `hasCustomAssemblyFormat = 1` (and omit `assemblyFormat`). mlir-tblgen then
//   declares a parser/printer pair for you to implement in C++:
//
//     static Attribute parse(AsmParser &odsParser, Type odsType);
//     void print(AsmPrinter &odsPrinter) const;
//
//   (Types get the same with `Type`.) You write the bodies in your .cpp; here we
//   only generate the declarations.
// =============================================================================

include "mlir/IR/AttrTypeBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
  let useDefaultAttributePrinterParser = 1;
}

class Toy_Attr<string name, list<Trait> traits = []> : AttrDef<Toy_Dialect, name, traits>;

// A polynomial attribute whose textual form (e.g. "2x^2 + 3x + 1") is too
// irregular for assemblyFormat, so we take over parsing/printing in C++.
def Toy_PolynomialAttr : Toy_Attr<"Polynomial"> {
  let mnemonic = "poly";
  let summary = "a dense polynomial, printed as a human-readable expression";
  let parameters = (ins ArrayRefParameter<"int64_t">:$coefficients);
  let hasCustomAssemblyFormat = 1;
}
