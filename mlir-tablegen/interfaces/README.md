# Interfaces — defining your own `OpInterface` / `AttrInterface` / `TypeInterface`

An **interface** is a virtual API that ops (or attributes, or types) from *any*
dialect can implement. A pass or pattern written against the interface works
for every implementer without naming one — this is how `-canonicalize`,
`-cse`, the inliner and bufferization work on dialects they have never heard
of. [ODS Lesson 8](../ods/README.md#lesson-8--traits) and
[Attrs & Types Lesson 9](../attrs-and-types/README.md#lesson-9--traits-and-interfaces)
showed how to *use* MLIR's built-in interfaces; this track shows how to
**define** one and what TableGen generates for it.

> Required include: `mlir/IR/Interfaces.td`. The C++ half (implementing the
> declared methods, a pattern generic over the interface, a pass that counts
> implementers) is in the [`../../mlir-capstone/`](../../mlir-capstone/README.md) build.

Four backends, one input file each way:

| Backend | Output | You include it from |
|---|---|---|
| `--gen-op-interface-decls` / `-defs` | the interface class, its `Concept`/`Model`/`Trait`, method dispatch | a header / a `.cpp` |
| `--gen-type-interface-decls` / `-defs` | same, for `TypeInterface` | |
| `--gen-attr-interface-decls` / `-defs` | same, for `AttrInterface` | |
| `--gen-op-interface-docs` (also `type`/`attr`) | Markdown reference | docs |

```bash
MLIR=/opt/homebrew/opt/llvm@20
$MLIR/bin/mlir-tblgen --gen-op-interface-decls -I $MLIR/include 1-op-interface/01_op_interface.td
$MLIR/bin/mlir-tblgen --gen-op-decls           -I $MLIR/include 1-op-interface/01_op_interface.td  # the ops' side
../gen-all.sh     # every backend for every lesson -> ../generated/interfaces/
```

## Table of Contents

- 1 — [Defining an OpInterface](#lesson-1--defining-an-opinterface) · `1-op-interface/`
- 2 — [Default, shared and static methods; verification](#lesson-2--default-shared-and-static-methods-verification) · `2-defaults-and-verification/`
- 3 — [AttrInterface and TypeInterface; interfaces as constraints](#lesson-3--attrinterface-and-typeinterface-interfaces-as-constraints) · `3-attr-and-type-interfaces/`
- [From `.td` to a generic pass](#from-td-to-a-generic-pass) · capstone
- [External models: interfaces for ops you don't own](#external-models-interfaces-for-ops-you-dont-own)

The record shape, from `Interfaces.td`:

```tablegen
def MyInterface : OpInterface<"MyInterface"> {   // or AttrInterface / TypeInterface
  let cppNamespace = "::toy";
  let methods = [
    //              description   return type  name     (ins args)     shared body  default body
    InterfaceMethod<"...",        "double",    "eval",  (ins "double":$x), [{ ... }], [{ ... }]>,
    StaticInterfaceMethod<...>,
  ];
  let extraClassDeclaration = [{ ... }];        // only in the interface class
  let extraSharedClassDeclaration = [{ ... }];  // in the interface class AND each implementer
  let verify = [{ ... }];                       // OpInterface only
}
```

---

## Lesson 1 — Defining an OpInterface

*Source: `1-op-interface/01_op_interface.td`*

```tablegen
include "mlir/IR/Interfaces.td"

def BinaryArithOpInterface : OpInterface<"BinaryArithOpInterface"> {
  let description = [{ A binary f64 arithmetic op that can be evaluated on constant operands. }];
  let cppNamespace = "::toy";
  let methods = [
    InterfaceMethod<"Evaluate the op on two constant operands.",
                    "double", "evaluate", (ins "double":$lhs, "double":$rhs)>,
    InterfaceMethod<"The operator symbol, for diagnostics.",
                    "::llvm::StringRef", "getSymbol", (ins)>,
  ];
}

def AddOp : Toy_Op<"add", [Pure, DeclareOpInterfaceMethods<BinaryArithOpInterface>]> { ... }
def MulOp : Toy_Op<"mul", [Pure, DeclareOpInterfaceMethods<BinaryArithOpInterface>]> { ... }
def NegOp : Toy_Op<"neg", [Pure]> { ... }   // does not implement it
```

`--gen-op-interface-decls` emits a concept/model pair, the usual C++ way to
get a virtual interface without a common base class. Read it once; afterwards
you only ever touch the `.td`:

```cpp
namespace toy {
namespace detail {
struct BinaryArithOpInterfaceInterfaceTraits {
  struct Concept {                                       // a vtable, by hand
    double (*evaluate)(const Concept *impl, ::mlir::Operation *, double, double);
    ::llvm::StringRef (*getSymbol)(const Concept *impl, ::mlir::Operation *);
  };
  template<typename ConcreteOp>
  class Model : public Concept {                         // fills the vtable for ONE op class
    static inline double evaluate(const Concept *, ::mlir::Operation *op, double lhs, double rhs) {
      return (llvm::cast<ConcreteOp>(op)).evaluate(lhs, rhs);   // -> AddOp::evaluate
    }
    ...
  };
  template<typename ConcreteOp> class FallbackModel;     // for external models (see below)
  template<typename ConcreteModel, typename ConcreteOp> class ExternalModel;
};
} // namespace detail

class BinaryArithOpInterface                             // the handle you use in passes
    : public ::mlir::OpInterface<BinaryArithOpInterface, detail::BinaryArithOpInterfaceInterfaceTraits> {
public:
  template <typename ConcreteOp> struct Trait : public detail::BinaryArithOpInterfaceTrait<ConcreteOp> {};
  double evaluate(double lhs, double rhs);
  ::llvm::StringRef getSymbol();
};
} // namespace toy
```

`--gen-op-interface-defs` is the dispatch through the vtable:

```cpp
double toy::BinaryArithOpInterface::evaluate(double lhs, double rhs) {
  return getImpl()->evaluate(getImpl(), getOperation(), lhs, rhs);
}
```

And on the **op's side** (`--gen-op-decls`), `DeclareOpInterfaceMethods` did two
things: added `::toy::BinaryArithOpInterface::Trait` to the op's trait list,
and *declared* the methods inside the op class for you to define:

```cpp
class AddOp : public ::mlir::Op<AddOp, ..., ::toy::BinaryArithOpInterface::Trait> {
  ...
  double evaluate(double lhs, double rhs);   // you define this
  ::llvm::StringRef getSymbol();             // and this
};
```

Your C++, and a consumer that never mentions `AddOp`:

```cpp
double toy::AddOp::evaluate(double l, double r) { return l + r; }
llvm::StringRef toy::AddOp::getSymbol() { return "+"; }

if (auto arith = llvm::dyn_cast<toy::BinaryArithOpInterface>(op))   // false for NegOp
  llvm::outs() << arith.getSymbol() << " -> " << arith.evaluate(2.0, 3.0);
```

> `[BinaryArithOpInterface]` (bare, without `DeclareOpInterfaceMethods`) only
> attaches the trait; use it when every method has a default (Lesson 2) or the
> op already provides the methods via `extraClassDeclaration`.

## Lesson 2 — Default, shared and static methods; verification

*Source: `2-defaults-and-verification/02_defaults.td`*

`InterfaceMethod` has two optional trailing code arguments that change who
provides the body:

| Arguments | Who implements | Overridable? | Use for |
|---|---|---|---|
| neither | every op, in C++ | — | the real per-op logic (`evaluate`) |
| 6th: `defaultImplementation` | interface, unless the op overrides | yes: list the name in `DeclareOpInterfaceMethods<I, ["name"]>` | sensible defaults (`isCommutative` → `false`) |
| 5th: `methodBody` | interface, once, for all ops | **no** | helpers on the generic `Operation` API (`$_op->getOperand(0)`) |

```tablegen
let methods = [
  InterfaceMethod<"Evaluate on two doubles.", "double", "evaluate", (ins "double":$lhs, "double":$rhs)>,
  InterfaceMethod<"Whether lhs and rhs may be swapped.", "bool", "isCommutative", (ins),
                  /*methodBody=*/"", /*defaultImplementation=*/[{ return false; }]>,
  InterfaceMethod<"The left operand.", "::mlir::Value", "getLhsValue", (ins), [{
    return $_op->getOperand(0);
  }]>,
  StaticInterfaceMethod<"Number of operands every implementer has.", "unsigned", "getArity", (ins), [{ return 2; }]>,
];
```

`$_op` is the concrete op instance (`llvm::cast<ConcreteOp>(op)` in the
`Model`). The effect on the generated op classes:

```cpp
// AddOp : DeclareOpInterfaceMethods<BinaryArithOpInterface, ["isCommutative"]>
  double evaluate(double lhs, double rhs);
  bool isCommutative();                 // declared because it was listed -> you define it
// SubOp : DeclareOpInterfaceMethods<BinaryArithOpInterface>
  double evaluate(double lhs, double rhs);   // isCommutative() comes from the Trait: `return false;`
```

Two places to add code without a method record:

```tablegen
// pasted into the interface class AND every implementer's Trait; `$_op` works
let extraSharedClassDeclaration = [{
  ::mlir::FloatAttr evaluateAttr(::mlir::FloatAttr lhs, ::mlir::FloatAttr rhs) {
    double r = $_op.evaluate(lhs.getValueAsDouble(), rhs.getValueAsDouble());
    return ::mlir::FloatAttr::get(lhs.getType(), r);
  }
}];
// pasted only into the interface class
let extraClassDeclaration = [{
  static constexpr ::llvm::StringLiteral getInterfaceDocName() { return "binary-arith"; }
}];
```

**Verification.** `let verify` runs as part of every implementing op's
verifier, exactly like a trait verifier (it becomes `Trait::verifyTrait`):

```tablegen
let verify = [{
  if ($_op->getNumOperands() != 2)
    return $_op->emitOpError("BinaryArithOpInterface requires exactly two operands");
  return ::mlir::success();
}];
```

```cpp
// generated, in detail::BinaryArithOpInterfaceTrait<ConcreteOp>
static ::llvm::LogicalResult verifyTrait(::mlir::Operation *op) {
  if (op->getNumOperands() != 2)
    return op->emitOpError("BinaryArithOpInterface requires exactly two operands");
  return ::mlir::success();
}
```

Set `verifyWithRegions = 1` if the check needs the ops inside the op's regions
to be verified first. `--gen-op-interface-docs` renders the record as
Markdown, marking each method "must be implemented by the user" or not.

## Lesson 3 — AttrInterface and TypeInterface; interfaces as constraints

*Source: `3-attr-and-type-interfaces/03_attr_type_interfaces.td`*

Same machinery, different entity. The placeholder is `$_type` / `$_attr`, the
attach class is `DeclareTypeInterfaceMethods` / `DeclareAttrInterfaceMethods`,
and the generated methods are `const` (a `Type`/`Attribute` is a value handle):

```tablegen
def ContainerTypeInterface : TypeInterface<"ContainerTypeInterface"> {
  let cppNamespace = "::toy";
  let methods = [
    InterfaceMethod<"Number of elements.", "int64_t", "getNumElements", (ins)>,
    InterfaceMethod<"The element type.", "::mlir::Type", "getContainedType", (ins)>,
    InterfaceMethod<"Total bit width if the element type is an integer/float.",
                    "int64_t", "getTotalBitWidth", (ins), "", [{
      return $_type.getNumElements() * $_type.getContainedType().getIntOrFloatBitWidth();
    }]>,
  ];
}

def Toy_ArrayType : Toy_Type<"Array", [DeclareTypeInterfaceMethods<ContainerTypeInterface>]> {
  let parameters = (ins "int64_t":$size, "::mlir::Type":$elementType);
  ...
}

def DescribableAttrInterface : AttrInterface<"DescribableAttrInterface"> {
  let cppNamespace = "::toy";
  let methods = [InterfaceMethod<"Human-readable description.", "std::string", "describe", (ins)>];
}
def Toy_ShapeAttr : Toy_Attr<"Shape", [DeclareAttrInterfaceMethods<DescribableAttrInterface>]> { ... }
```

```cpp
// generated (--gen-typedef-decls)
class ArrayType : public ::mlir::Type::TypeBase<ArrayType, ::mlir::Type, detail::ArrayTypeStorage,
                                                ::toy::ContainerTypeInterface::Trait> {
  int64_t getNumElements() const;
  ::mlir::Type getContainedType() const;
// you write
int64_t    toy::ArrayType::getNumElements() const { return getSize(); }
mlir::Type toy::ArrayType::getContainedType() const { return getElementType(); }
```

> Pick method names that do not collide with the parameter accessors ODS
> already generates (`getSize()`, `getElementType()`), or the class gets two
> declarations of the same signature.

**Interfaces are also constraints.** `TypeInterface` derives from `Type` and
`AttrInterface` from `Attr`, with the predicate `isa<Interface>($_self)`. So an
op can accept "anything implementing the interface", across dialects:

```tablegen
def SizeOfOp : Toy_Op<"size_of"> {
  let arguments = (ins ContainerTypeInterface:$container, DescribableAttrInterface:$note);
  let results = (outs I64:$size);
}
```

```cpp
// generated verifier (--gen-op-defs)
if (!((::llvm::isa<::toy::ContainerTypeInterface>(type))))
  return op->emitOpError(...) << " must be ContainerTypeInterface instance, but got " << type;
```

## From `.td` to a generic pass

The [capstone](../../mlir-capstone/README.md) defines `BinaryArithOpInterface` and
`ContainerTypeInterface` in `ToyInterfaces.td` and uses them three ways:

1. **`toy.add` / `toy.mul` / `toy.sub` implement the op interface**
   (`ToyOps.td`); `ToyInterfaces.cpp` defines `evaluate()` / `getSymbol()` and
   overrides `isCommutative()` for add and mul only.
2. **One C++ pattern folds all of them.** `FoldBinaryArithConstants` in
   `ToyPatterns.cpp` is an `OpInterfaceRewritePattern<BinaryArithOpInterface>`:
   it reads both operands through the shared `getLhsValue()` / `getRhsValue()`
   and calls `evaluate()`. `toy.sub` has no DRR or PDLL pattern and is folded
   only this way — adding a fourth arithmetic op needs no new pattern.
3. **The pass counts through the interface** (`ToyPasses.cpp`):
   `module.walk([&](toy::BinaryArithOpInterface) { ++n; })`.

The CMake side is four more `mlir_tablegen()` lines on a separate
`LLVM_TARGET_DEFINITIONS`, and one include-order rule: the interface header
must come *before* the generated op/type classes that name its `Trait`.

## External models: interfaces for ops you don't own

The generated `ExternalModel` / `FallbackModel` classes (visible in the Lesson 1
output) exist so an interface can be attached to an op, type or attribute
**defined elsewhere** — e.g. making `arith.addf` implement
`BinaryArithOpInterface` without touching the arith dialect:

```cpp
struct AddFArithModel
    : public toy::BinaryArithOpInterface::ExternalModel<AddFArithModel, arith::AddFOp> {
  double evaluate(Operation *op, double l, double r) const { return l + r; }   // note: Operation* first
  llvm::StringRef getSymbol(Operation *op) const { return "+"; }
};
// at dialect-registration time:
registry.addExtension(+[](MLIRContext *ctx, arith::ArithDialect *) {
  arith::AddFOp::attachInterface<AddFArithModel>(*ctx);
});
```

Nothing changes in the `.td`; the interface simply gains an implementer at
runtime. This is how upstream attaches bufferization or tiling interfaces to
dialects that do not know about them.

## References

- Interfaces — <https://mlir.llvm.org/docs/Interfaces/> (sections *Attribute/Operation/Type Interfaces* and *External Models*)
- `Interfaces.td` — `mlir/IR/Interfaces.td` in your MLIR include directory
- Upstream examples — `mlir/include/mlir/Interfaces/*.td` (e.g. `SideEffectInterfaces.td`, `InferTypeOpInterface.td`)
