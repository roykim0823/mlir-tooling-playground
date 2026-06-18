// =============================================================================
// Attrs & Types Lesson 3 — Parameters
//
//   `parameters` is a list of stored fields. Each can be a raw C++ type
//   ("int64_t", "::mlir::Type") or a specialized parameter class that teaches
//   ODS how to allocate/parse/print it:
//
//     ArrayRefParameter<"T">    - a variable-length ::llvm::ArrayRef<T>
//     StringRefParameter<>      - a ::llvm::StringRef (copied into the context)
//     APFloatParameter<>        - a ::llvm::APFloat
//
//   A parameter whose C++ type is `::mlir::Type` lets a type nest other types.
// =============================================================================

include "mlir/IR/AttrTypeBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
  let useDefaultTypePrinterParser = 1;
  let useDefaultAttributePrinterParser = 1;
}

class Toy_Type<string name, list<Trait> traits = []> : TypeDef<Toy_Dialect, name, traits>;
class Toy_Attr<string name, list<Trait> traits = []> : AttrDef<Toy_Dialect, name, traits>;

// A struct-like type: an ordered list of element types + a name.
// !toy.struct<"point", i32, f64>
def Toy_StructType : Toy_Type<"Struct"> {
  let mnemonic = "struct";
  let parameters = (ins
      StringRefParameter<"the struct's name">:$name,
      ArrayRefParameter<"::mlir::Type">:$elementTypes);
  let assemblyFormat = "`<` $name `,` $elementTypes `>`";
}

// An attribute storing an arbitrary-precision float plus a unit.
// #toy.measure<3.14 : "meters">
def Toy_MeasureAttr : Toy_Attr<"Measure"> {
  let mnemonic = "measure";
  let parameters = (ins APFloatParameter<"">:$value,
                        StringRefParameter<"the unit">:$unit);
  let assemblyFormat = "`<` $value `:` $unit `>`";
}
