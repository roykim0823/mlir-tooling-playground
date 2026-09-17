//===- 01_documented_dialect.td - Lesson 1: writing for the doc backends -*- tablegen -*-===//
//
// Every ODS record carries documentation fields that the C++ backends ignore
// and the DOC backends render as Markdown. This lesson fills all of them, so
// you can see which field ends up where:
//
//   mlir-tblgen --gen-dialect-doc -dialect=toy -I $MLIR/include 01_documented_dialect.td
//   mlir-tblgen --gen-op-doc                   -I $MLIR/include 01_documented_dialect.td
//   mlir-tblgen --gen-attrdef-doc              -I $MLIR/include 01_documented_dialect.td
//   mlir-tblgen --gen-typedef-doc              -I $MLIR/include 01_documented_dialect.td
//   mlir-tblgen --gen-enum-doc                 -I $MLIR/include 01_documented_dialect.td
//
//===----------------------------------------------------------------------------===//

include "mlir/IR/OpBase.td"
include "mlir/IR/AttrTypeBase.td"
include "mlir/IR/EnumAttr.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// The dialect's `summary` becomes the first paragraph under "# 'toy' Dialect";
// `description` follows it. Both are Markdown.
def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
  let summary = "A tiny f64 arithmetic dialect used throughout this repository.";
  let description = [{
    Toy has a handful of scalar `f64` operations, one custom type and one custom
    attribute. It exists to have something concrete to generate code, patterns,
    passes and — here — documentation for.

    Paragraphs, `code`, and lists all survive:

    * this list item is in the dialect description
    * so is this one
  }];
  let useDefaultTypePrinterParser = 1;
  let useDefaultAttributePrinterParser = 1;
}
class Toy_Op<string m, list<Trait> t = []> : Op<Toy_Dialect, m, t>;
class Toy_Attr<string n, list<Trait> t = []> : AttrDef<Toy_Dialect, n, t>;
class Toy_Type<string n, list<Trait> t = []> : TypeDef<Toy_Dialect, n, t>;

//===----------------------------------------------------------------------------===//
// Operations: summary -> italic one-liner; description -> body;
// assemblyFormat -> "Syntax:" block; operands/results/attributes -> tables
// whose "Description" column is the CONSTRAINT's summary (F64 -> "64-bit float").
//===----------------------------------------------------------------------------===//

def AddOp : Toy_Op<"add", [Pure]> {
  let summary = "f64 addition";
  let description = [{
    Adds two `f64` values. Example:

    ```mlir
    %sum = toy.add %a, %b
    ```

    Both operands are folded when they are `toy.constant`s (see `-toy-fold`).
  }];
  let arguments = (ins F64:$lhs, F64:$rhs);
  let results = (outs F64:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict";
}

// An op WITHOUT a description: the doc shows only the summary. Compare.
def PrintOp : Toy_Op<"print"> {
  let summary = "prints an f64 value";
  let arguments = (ins F64:$input);
  let assemblyFormat = "$input attr-dict";
}

//===----------------------------------------------------------------------------===//
// Enums: --gen-enum-doc lists the cases with their string values.
//===----------------------------------------------------------------------------===//

def Toy_RoundingMode : I32EnumAttr<"RoundingMode", "how a toy.round op rounds", [
  I32EnumAttrCase<"Nearest", 0, "nearest">,
  I32EnumAttrCase<"Floor",   1, "floor">,
  I32EnumAttrCase<"Ceil",    2, "ceil">,
]> {
  let cppNamespace = "::toy";
}

//===----------------------------------------------------------------------------===//
// Attributes & types: `AttrParameter`/`TypeParameter<"cpp type", "description">`
// fills the Parameters table's Description column. A bare "int64_t":$rows
// leaves it EMPTY — the most common gap in generated dialect docs.
//===----------------------------------------------------------------------------===//

def Toy_ShapeAttr : Toy_Attr<"Shape"> {
  let mnemonic = "shape";
  let summary = "a static 2-D shape";
  let description = [{ Rows and columns of a matrix, e.g. `#toy.shape<3 x 4>`. }];
  let parameters = (ins
    AttrParameter<"int64_t", "number of rows">:$rows,
    AttrParameter<"int64_t", "number of columns">:$cols
  );
  let assemblyFormat = "`<` $rows `x` $cols `>`";
}

def Toy_ArrayType : Toy_Type<"Array"> {
  let mnemonic = "array";
  let summary = "a fixed-size array type";
  let description = [{ `!toy.array<N x T>`: exactly `N` elements of type `T`. }];
  let parameters = (ins
    TypeParameter<"int64_t", "number of elements">:$size,
    TypeParameter<"::mlir::Type", "element type">:$elementType
  );
  let assemblyFormat = "`<` $size `x` $elementType `>`";
}
