// =============================================================================
// Attrs & Types Lesson 7 — Builders
//
//   ODS auto-generates `get(ctx, params...)` (and `getChecked`). Add convenience
//   builders with `AttrBuilder` / `TypeBuilder`:
//
//     AttrBuilder<(ins "T":$x), [{ C++ returning the attribute }]>
//     TypeBuilderWithInferredContext<...>  - context taken from a param
//
//   `let skipDefaultBuilders = 1;` suppresses the auto-generated `get`s if you
//   want full control. Inside the body, `$_ctxt`/`$_get` are available.
// =============================================================================

include "mlir/IR/AttrTypeBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
  let useDefaultAttributePrinterParser = 1;
  let useDefaultTypePrinterParser = 1;
}

class Toy_Attr<string name, list<Trait> traits = []> : AttrDef<Toy_Dialect, name, traits>;
class Toy_Type<string name, list<Trait> traits = []> : TypeDef<Toy_Dialect, name, traits>;

def Toy_VersionAttr : Toy_Attr<"Version"> {
  let mnemonic = "version";
  let parameters = (ins "int64_t":$major, "int64_t":$minor);
  // Note: `.` is not a legal assemblyFormat literal, so we separate with `:`.
  let assemblyFormat = "`<` $major `:` $minor `>`";

  let builders = [
    // Build a "major.0" version from just the major number.
    AttrBuilder<(ins "int64_t":$major), [{
      return $_get($_ctxt, major, /*minor=*/0);
    }]>
  ];
}

def Toy_BoxType : Toy_Type<"Box"> {
  let mnemonic = "box";
  let parameters = (ins "::mlir::Type":$element);
  let assemblyFormat = "`<` $element `>`";

  let builders = [
    // The context can be inferred from the element type, so the caller need not
    // pass an MLIRContext explicitly.
    TypeBuilderWithInferredContext<(ins "::mlir::Type":$element), [{
      return $_get(element.getContext(), element);
    }]>
  ];
}
