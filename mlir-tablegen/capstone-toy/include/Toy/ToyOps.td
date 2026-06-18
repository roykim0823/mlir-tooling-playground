//===- ToyOps.td - The capstone Toy dialect -------------------*- tablegen -*-===//
//
// A complete, buildable out-of-tree dialect that ties together the ODS and DRR
// lessons: it defines a dialect + four ops (ODS) and one constant-folding
// rewrite (DRR) in a single source of truth. The CMake build runs five
// mlir-tblgen backends over this file:
//
//   --gen-op-decls / --gen-op-defs           -> the C++ op classes
//   --gen-dialect-decls / --gen-dialect-defs -> the C++ ToyDialect class
//   --gen-rewriters                          -> the fold pattern
//
//===----------------------------------------------------------------------------===//

include "mlir/IR/OpBase.td"
include "mlir/IR/AttrTypeBase.td"
include "mlir/IR/PatternBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

//===----------------------------------------------------------------------------===//
// Dialect + base classes (ODS — see ../../ods/ and ../../attrs-and-types/)
//===----------------------------------------------------------------------------===//

def Toy_Dialect : Dialect {
  let name = "toy";
  let summary = "The capstone Toy dialect.";
  let cppNamespace = "::toy";
  // Required to parse/print the dialect's own attributes and types by mnemonic.
  let useDefaultAttributePrinterParser = 1;
  let useDefaultTypePrinterParser = 1;
}

class Toy_Op<string mnemonic, list<Trait> traits = []>
    : Op<Toy_Dialect, mnemonic, traits>;
class Toy_Attr<string name, list<Trait> traits = []>
    : AttrDef<Toy_Dialect, name, traits>;
class Toy_Type<string name, list<Trait> traits = []>
    : TypeDef<Toy_Dialect, name, traits>;

//===----------------------------------------------------------------------------===//
// A custom type and attribute (see ../../attrs-and-types/)
//===----------------------------------------------------------------------------===//

// !toy.array<3 x f64> — a fixed-size array with an element type parameter.
def Toy_ArrayType : Toy_Type<"Array"> {
  let mnemonic = "array";
  let summary = "a fixed-size array type";
  let parameters = (ins "int64_t":$size, "::mlir::Type":$elementType);
  let assemblyFormat = "`<` $size `x` $elementType `>`";
}

// #toy.shape<3 x 4> — a static 2-D shape attribute.
def Toy_ShapeAttr : Toy_Attr<"Shape"> {
  let mnemonic = "shape";
  let summary = "a static 2-D shape";
  let parameters = (ins "int64_t":$rows, "int64_t":$cols);
  let assemblyFormat = "`<` $rows `x` $cols `>`";
}

//===----------------------------------------------------------------------------===//
// Operations
//===----------------------------------------------------------------------------===//

def ConstantOp : Toy_Op<"constant", [Pure]> {
  let summary = "a constant f64 value";
  let arguments = (ins F64Attr:$value);
  let results = (outs F64:$result);
  let assemblyFormat = "$value attr-dict";

  // Convenience builder: ConstantOp from a raw double.
  let builders = [
    OpBuilder<(ins "double":$value), [{
      build($_builder, $_state, $_builder.getF64Type(),
            $_builder.getF64FloatAttr(value));
    }]>
  ];
}

def AddOp : Toy_Op<"add", [Pure]> {
  let summary = "f64 addition";
  let arguments = (ins F64:$lhs, F64:$rhs);
  let results = (outs F64:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict";
}

def MulOp : Toy_Op<"mul", [Pure]> {
  let summary = "f64 multiplication";
  let arguments = (ins F64:$lhs, F64:$rhs);
  let results = (outs F64:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict";
}

def PrintOp : Toy_Op<"print"> {
  let summary = "prints an f64 value (has a side effect, so it is never folded away)";
  let arguments = (ins F64:$input);
  let assemblyFormat = "$input attr-dict";
}

//===----------------------------------------------------------------------------===//
// Rewrite patterns (DRR — see ../../drr/)
//===----------------------------------------------------------------------------===//

// Constant-fold add(constant a, constant b) -> constant (a + b). The arithmetic
// happens in C++ via the NativeCodeCall helper `foldAddF64` (see ToyPatterns.cpp).
def FoldAddF64 : NativeCodeCall<"foldAddF64($_builder, $0, $1)">;

def : Pat<(AddOp (ConstantOp $a), (ConstantOp $b)),
          (ConstantOp (FoldAddF64 $a, $b))>;
