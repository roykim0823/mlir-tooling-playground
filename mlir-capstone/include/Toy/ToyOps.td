//===- ToyOps.td - The capstone Toy dialect -------------------*- tablegen -*-===//
//
// A complete, buildable out-of-tree dialect that ties together the ODS, DRR and
// interfaces lessons: it defines a dialect + five ops, a type and an attribute
// (ODS), one constant-folding rewrite (DRR), and implements the interfaces from
// ToyInterfaces.td. The CMake build runs these mlir-tblgen backends over it:
//
//   --gen-op-decls / --gen-op-defs           -> the C++ op classes
//   --gen-dialect-decls / --gen-dialect-defs -> the C++ ToyDialect class
//   --gen-typedef-* / --gen-attrdef-*        -> the type and attribute classes
//   --gen-rewriters                          -> the fold pattern
//
//===----------------------------------------------------------------------------===//

include "mlir/IR/OpBase.td"
include "mlir/IR/AttrTypeBase.td"
include "mlir/IR/PatternBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"
include "Toy/ToyInterfaces.td"   // BinaryArithOpInterface, ContainerTypeInterface

//===----------------------------------------------------------------------------===//
// Dialect + base classes (ODS — see ../../ods/ and ../../attrs-and-types/)
//===----------------------------------------------------------------------------===//

def Toy_Dialect : Dialect {
  let name = "toy";
  let summary = "The capstone Toy dialect.";
  // Rendered by --gen-dialect-doc under the dialect heading (see ../../../mlir-tablegen/docs/).
  let description = [{
    A tiny `f64` arithmetic dialect: constants, `add`/`mul`/`sub` (all
    implementing `BinaryArithOpInterface`), a side-effecting `print`, a
    fixed-size array type and a 2-D shape attribute. Its ops are folded by the
    `-toy-fold` pass.
  }];
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
// It implements ContainerTypeInterface (methods defined in ToyInterfaces.cpp).
def Toy_ArrayType : Toy_Type<"Array", [DeclareTypeInterfaceMethods<ContainerTypeInterface>]> {
  let mnemonic = "array";
  let summary = "a fixed-size array type";
  let description = [{ `!toy.array<N x T>`: exactly `N` elements of type `T`. }];
  // TypeParameter<type, description>: the description feeds --gen-dialect-doc's
  // Parameters table; a bare "int64_t":$size would leave that column empty.
  let parameters = (ins
    TypeParameter<"int64_t", "number of elements">:$size,
    TypeParameter<"::mlir::Type", "element type">:$elementType
  );
  let assemblyFormat = "`<` $size `x` $elementType `>`";
}

// #toy.shape<3 x 4> — a static 2-D shape attribute.
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

//===----------------------------------------------------------------------------===//
// Operations
//===----------------------------------------------------------------------------===//

def ConstantOp : Toy_Op<"constant", [Pure]> {
  let summary = "a constant f64 value";
  let description = [{
    Materializes an `f64` constant:

    ```mlir
    %c = toy.constant 1.0
    ```
  }];
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

// add / mul / sub implement BinaryArithOpInterface (ToyInterfaces.td). The
// trait DECLARES evaluate()/getSymbol() in each op class (+ isCommutative()
// where listed, to override its default); ToyInterfaces.cpp defines them.
def AddOp : Toy_Op<"add", [Pure, DeclareOpInterfaceMethods<BinaryArithOpInterface, ["isCommutative"]>]> {
  let summary = "f64 addition";
  let description = [{
    Adds two `f64` values. Folded by `-toy-fold` when both operands are
    `toy.constant`s (DRR pattern in this file).
  }];
  let arguments = (ins F64:$lhs, F64:$rhs);
  let results = (outs F64:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict";
}

def MulOp : Toy_Op<"mul", [Pure, DeclareOpInterfaceMethods<BinaryArithOpInterface, ["isCommutative"]>]> {
  let summary = "f64 multiplication";
  let arguments = (ins F64:$lhs, F64:$rhs);
  let results = (outs F64:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict";
}

// No DRR or PDLL pattern mentions toy.sub: it is folded ONLY by the C++
// pattern written against the interface (ToyPatterns.cpp). Uses the default
// isCommutative() -> false.
def SubOp : Toy_Op<"sub", [Pure, DeclareOpInterfaceMethods<BinaryArithOpInterface>]> {
  let summary = "f64 subtraction";
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
