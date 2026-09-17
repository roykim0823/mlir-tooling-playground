//===- 03_attr_type_interfaces.td - Lesson 3: AttrInterface & TypeInterface -*- tablegen -*-===//
//
// Same machinery, different entity. Attributes and types get `$_attr` /
// `$_type` instead of `$_op`, and their own backends:
//
//   mlir-tblgen --gen-type-interface-decls -I $MLIR/include 03_attr_type_interfaces.td
//   mlir-tblgen --gen-type-interface-defs  -I $MLIR/include 03_attr_type_interfaces.td
//   mlir-tblgen --gen-attr-interface-decls -I $MLIR/include 03_attr_type_interfaces.td
//   mlir-tblgen --gen-attr-interface-defs  -I $MLIR/include 03_attr_type_interfaces.td
//   mlir-tblgen --gen-typedef-decls        -I $MLIR/include 03_attr_type_interfaces.td  # the type's side
//   mlir-tblgen --gen-op-decls             -I $MLIR/include 03_attr_type_interfaces.td  # interface as constraint
//
//===----------------------------------------------------------------------------===//

include "mlir/IR/OpBase.td"
include "mlir/IR/AttrTypeBase.td"
include "mlir/IR/Interfaces.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
  let useDefaultTypePrinterParser = 1;
  let useDefaultAttributePrinterParser = 1;
}
class Toy_Op<string m, list<Trait> t = []> : Op<Toy_Dialect, m, t>;
class Toy_Type<string n, list<Trait> t = []> : TypeDef<Toy_Dialect, n, t>;
class Toy_Attr<string n, list<Trait> t = []> : AttrDef<Toy_Dialect, n, t>;

//===----------------------------------------------------------------------------===//
// A TypeInterface
//===----------------------------------------------------------------------------===//

// "Any type that is a fixed-size container of some element type."
def ContainerTypeInterface : TypeInterface<"ContainerTypeInterface"> {
  let description = [{ A type holding a known number of elements of one type. }];
  let cppNamespace = "::toy";
  let methods = [
    InterfaceMethod<"Number of elements.", "int64_t", "getNumElements", (ins)>,
    InterfaceMethod<"The element type.", "::mlir::Type", "getContainedType", (ins)>,
    // default impl using the other two, `$_type` is the concrete type
    InterfaceMethod<"Total bit width if the element type is an integer/float.",
                    "int64_t", "getTotalBitWidth", (ins), "", [{
      return $_type.getNumElements() * $_type.getContainedType().getIntOrFloatBitWidth();
    }]>,
  ];
}

// !toy.array<4 x f64> implements it. Method names are chosen NOT to clash
// with the parameter accessors ODS generates (getSize / getElementType).
def Toy_ArrayType : Toy_Type<"Array", [DeclareTypeInterfaceMethods<ContainerTypeInterface>]> {
  let mnemonic = "array";
  let parameters = (ins "int64_t":$size, "::mlir::Type":$elementType);
  let assemblyFormat = "`<` $size `x` $elementType `>`";
}
// C++ you write (type/attr interface methods are declared `const`, unlike ops):
//   int64_t     toy::ArrayType::getNumElements() const { return getSize(); }
//   mlir::Type  toy::ArrayType::getContainedType() const { return getElementType(); }

//===----------------------------------------------------------------------------===//
// An AttrInterface
//===----------------------------------------------------------------------------===//

def DescribableAttrInterface : AttrInterface<"DescribableAttrInterface"> {
  let description = [{ An attribute that can render a one-line description. }];
  let cppNamespace = "::toy";
  let methods = [
    InterfaceMethod<"Human-readable description.", "std::string", "describe", (ins)>,
  ];
}

// #toy.shape<3 x 4> implements it.
def Toy_ShapeAttr : Toy_Attr<"Shape", [DeclareAttrInterfaceMethods<DescribableAttrInterface>]> {
  let mnemonic = "shape";
  let parameters = (ins "int64_t":$rows, "int64_t":$cols);
  let assemblyFormat = "`<` $rows `x` $cols `>`";
}
// C++ you write:
//   std::string toy::ShapeAttr::describe() const { return "shape " + std::to_string(getRows()) + "x" + std::to_string(getCols()); }

//===----------------------------------------------------------------------------===//
// Interfaces double as ODS constraints
//===----------------------------------------------------------------------------===//

// A TypeInterface is also a `Type` constraint (isa<Interface>($_self)), and an
// AttrInterface an `Attr` constraint. So an op can accept "any type/attr that
// implements the interface", from any dialect:
def SizeOfOp : Toy_Op<"size_of"> {
  let arguments = (ins ContainerTypeInterface:$container,       // any implementer
                       DescribableAttrInterface:$note);
  let results = (outs I64:$size);
}
