# ODS — Operation Definition Specification

**ODS** is MLIR's TableGen-based way to *define operations* (and attributes,
types, and enums). You describe an op declaratively — its operands, results,
attributes, traits, assembly format — and `mlir-tblgen` emits the C++ op class:
accessors, builders, verifiers, and the parser/printer.

> This is the MLIR analog of LLVM's instruction descriptions, but far more
> pervasive: in MLIR *every* dialect (even the built-in ones) is defined this
> way. See [`../drr/`](../drr) for the rewrite-rule half of MLIR TableGen.

Every lesson is a self-contained `.td` file that defines a tiny `toy` dialect
and runs standalone through `mlir-tblgen`. The required base include is always
`mlir/IR/OpBase.td` (plus interface includes for some traits).

## Table of Contents

The lessons are grouped into subcategory directories. Lesson numbers run in
reading order across them.

**`1-dialect-and-ops/` — the dialect and a first op**
- 1 — [A Dialect and your first Operation](#lesson-1--a-dialect-and-your-first-operation)
- 2 — [Operation metadata: summary, description, mnemonic](#lesson-2--operation-metadata)

**`2-arguments/` — inputs: operands & attributes**
- 3 — [Operands (the `ins` dag)](#lesson-3--operands)
- 4 — [Attributes](#lesson-4--attributes)
- 5 — [Variadic and Optional operands](#lesson-5--variadic-and-optional-operands)

**`3-results-and-regions/` — outputs and nested IR**
- 6 — [Results (the `outs` dag)](#lesson-6--results)
- 7 — [Regions and Successors](#lesson-7--regions-and-successors)

**`4-traits-and-verification/` — semantics & checking**
- 8 — [Traits](#lesson-8--traits)
- 9 — [Constraints and custom verification](#lesson-9--constraints-and-custom-verification)

**`5-assembly-and-builders/` — syntax & construction**
- 10 — [Declarative assembly format](#lesson-10--declarative-assembly-format)
- 11 — [Custom builders](#lesson-11--custom-builders)

**`6-enums/` — dialect-defined enums**
- 12 — [Enums (EnumAttr)](#lesson-12--enums-enumattr)

> Defining custom **attributes** and **types** (`AttrDef`/`TypeDef`) has its own
> dedicated tutorial — see [`../attrs-and-types/`](../attrs-and-types).

---

## Lesson 1 — A Dialect and your first Operation

*Source: `1-dialect-and-ops/01_dialect.td`*

Everything starts with a `Dialect` (the C++ class + IR namespace your ops live
in) and a small base `Op` class so every op inherits the dialect and forwards
its traits.

```tablegen
def Toy_Dialect : Dialect { let name = "toy"; let cppNamespace = "::toy"; }
class Toy_Op<string mnemonic, list<Trait> traits = []>
    : Op<Toy_Dialect, mnemonic, traits>;

def NopOp : Toy_Op<"nop"> { let summary = "does nothing"; }
```

### What gets generated

`mlir-tblgen` is a *multi-backend* generator: the same `.td` feeds different
flags ("backends"), each emitting one slice of C++. Three matter here:

| Flag | Emits | From the file above |
|------|-------|---------------------|
| `--gen-dialect-decls` | the **dialect class** declaration | `class ToyDialect` |
| `--gen-dialect-defs` | the **dialect class** definition (ctor/dtor) | `ToyDialect::ToyDialect(…)` |
| `--gen-op-decls` | each op's **class declaration** (the header) | `class NopOp { … };` |
| `--gen-op-defs` | each op's **method definitions** (the impl) | `NopOp::build(…)`, `verifyInvariants()` |

The pattern is symmetric: both the dialect and each op split into a `-decls`
(header) backend and a `-defs` (impl) backend.

The split mirrors normal C++: *decls* go in a header you `#include` where the op
is *used*; *defs* go in exactly one `.cpp` so the bodies are compiled once. MLIR
gates both behind a `#define` macro (`GET_OP_CLASSES`) so a single `.inc` can be
pulled into several `#include` sites.

`gen-all.sh` emits all four at once, but you can run each backend explicitly.
From `ods/1-dialect-and-ops/`:

```bash
MLIR=/opt/homebrew/opt/llvm@20    # your LLVM/MLIR prefix
$MLIR/bin/mlir-tblgen --gen-dialect-decls -I $MLIR/include 01_dialect.td -o 01_dialect.dialect-decls.inc
$MLIR/bin/mlir-tblgen --gen-dialect-defs  -I $MLIR/include 01_dialect.td -o 01_dialect.dialect-defs.inc
$MLIR/bin/mlir-tblgen --gen-op-decls      -I $MLIR/include 01_dialect.td -o 01_dialect.op-decls.inc
$MLIR/bin/mlir-tblgen --gen-op-defs       -I $MLIR/include 01_dialect.td -o 01_dialect.op-defs.inc
```

Drop the `-o` to print to stdout instead. `gen-all.sh` runs exactly these (with
`-o` pointing under `generated/ods/1-dialect-and-ops/`, which is gitignored —
rerun any time).

**`--gen-dialect-decls` → the dialect class.** Registers the namespace; you
implement `initialize()` in C++ to register the ops/types:

```c++
namespace toy {
class ToyDialect : public ::mlir::Dialect {
  explicit ToyDialect(::mlir::MLIRContext *context);   // ctor MLIR calls on load
  void initialize();                                   // you write this: addOperations<…>()
  friend class ::mlir::MLIRContext;
public:
  ~ToyDialect() override;
  static constexpr ::llvm::StringLiteral getDialectNamespace() {
    return ::llvm::StringLiteral("toy");               // from `let name = "toy"`
  }
};
} // namespace toy
MLIR_DECLARE_EXPLICIT_TYPE_ID(::toy::ToyDialect)        // unique RTTI id for the dialect
```

**`--gen-dialect-defs` → the dialect's bodies** (the `.cpp` side). Pure
boilerplate: the constructor wires up the namespace + `TypeID` and calls the
`initialize()` you implement:

```c++
MLIR_DEFINE_EXPLICIT_TYPE_ID(::toy::ToyDialect)
namespace toy {
ToyDialect::ToyDialect(::mlir::MLIRContext *context)
    : ::mlir::Dialect(getDialectNamespace(), context, ::mlir::TypeID::get<ToyDialect>()) {
  initialize();                          // <- your hook: addOperations<NopOp, …>()
}
ToyDialect::~ToyDialect() = default;
} // namespace toy
```

**`--gen-op-decls` → the op's C++ class** (trimmed). Note the traits in the base
list — ODS derived them from the *empty* `arguments`/`results`:

```c++
namespace toy { class NopOp; }           // forward decl — always visible

#ifdef GET_OP_CLASSES                     // class body only when the consumer asks
namespace toy {
class NopOp : public ::mlir::Op<NopOp,
        ::mlir::OpTrait::ZeroRegions,     // <- no `regions` in the .td
        ::mlir::OpTrait::ZeroResults,     // <- no `results`
        ::mlir::OpTrait::ZeroSuccessors,  // <- no `successors`
        ::mlir::OpTrait::ZeroOperands,    // <- no `arguments`
        ::mlir::OpTrait::OpInvariants> {  //    structural checks
public:
  using Op::Op;                                         // inherit the constructors
  static constexpr ::llvm::StringLiteral getOperationName() {
    return ::llvm::StringLiteral("toy.nop");            // dialect prefix + mnemonic
  }
  static void build(::mlir::OpBuilder &, ::mlir::OperationState &);          // builder
  static void build(::mlir::OpBuilder &, ::mlir::OperationState &, ::mlir::TypeRange);
  ::llvm::LogicalResult verifyInvariants();             // called after build/parse
};
} // namespace toy
MLIR_DECLARE_EXPLICIT_TYPE_ID(::toy::NopOp)
#endif // GET_OP_CLASSES
```

> ODS also emits a `NopOpAdaptor` — a lightweight view over an op's
> operands/attributes, used by builders and folders before a full `Operation*`
> exists. Ignore it until a later lesson gives the op operands to view.

**`--gen-op-defs` → the out-of-line bodies** of those methods. With no operands,
results, or attributes there's almost nothing to do:

```c++
#ifdef GET_OP_CLASSES
// default builder: nothing to add to the op state
void NopOp::build(::mlir::OpBuilder &odsBuilder, ::mlir::OperationState &odsState) {
}
// result-typed builder: asserts zero results, then records them
void NopOp::build(::mlir::OpBuilder &b, ::mlir::OperationState &odsState, ::mlir::TypeRange resultTypes) {
  assert(resultTypes.size() == 0u && "mismatched number of results");
  odsState.addTypes(resultTypes);
}
// invariant check the framework runs automatically — trivially succeeds here
::llvm::LogicalResult NopOp::verifyInvariantsImpl() { return ::mlir::success(); }
::llvm::LogicalResult NopOp::verifyInvariants() { return verifyInvariantsImpl(); }
MLIR_DEFINE_EXPLICIT_TYPE_ID(::toy::NopOp)
#endif // GET_OP_CLASSES
```

Every later lesson makes these bodies grow: operands add `getLhs()` accessors,
attributes add segment math, `hasVerifier = 1` adds a call into your hand-written
`verify()`. Diffing the generated `.inc` before and after a `.td` change is the
fastest way to see what a given ODS feature actually buys you.

## Lesson 2 — Operation metadata

*Source: `1-dialect-and-ops/02_op_metadata.td`*

Every op carries documentation. `summary` is a one-liner; `description` is a
long-form `[{ ... }]` Markdown block consumed by `--gen-op-doc`. The mnemonic
passed to the base class becomes the IR name after the dialect prefix
(`"print"` → `toy.print`, C++ class `PrintOp`).

```tablegen
def PrintOp : Toy_Op<"print"> {
  let summary = "prints its operand";
  let description = [{ The `toy.print` operation ... }];
}
```

**What gets generated.** Three files — the same two op backends as Lesson 1, plus
the doc:

- `02_op_metadata.op-decls.inc` / `.op-defs.inc` — the `PrintOp` class, identical
  in shape to Lesson 1's `NopOp`. `summary`/`description` are pure metadata, so
  they don't change the C++ at all.
- `02_op_metadata.op-doc.md` — the new one: `--gen-op-doc` turns
  `summary`/`description` into Markdown for the dialect's rendered docs.

```bash
$MLIR/bin/mlir-tblgen --gen-op-decls -I $MLIR/include 02_op_metadata.td -o 02_op_metadata.op-decls.inc
$MLIR/bin/mlir-tblgen --gen-op-defs  -I $MLIR/include 02_op_metadata.td -o 02_op_metadata.op-defs.inc
$MLIR/bin/mlir-tblgen --gen-op-doc   -I $MLIR/include 02_op_metadata.td -o 02_op_metadata.op-doc.md
```

The doc output:

```markdown
### `toy.print` (::toy::PrintOp)
_Prints its (eventual) operand to stdout_          <!-- from `summary` -->

The `toy.print` operation is a placeholder ...     <!-- `description`, emitted verbatim -->
```

---

## Lesson 3 — Operands

*Source: `2-arguments/03_operands.td`*

An op's SSA inputs are declared in `arguments = (ins ...)`. Each operand has a
*type constraint* and a `$name`, which becomes a typed accessor (`op.getLhs()`).
Constraints range from concrete (`F64`, `I1`) to broad (`AnyType`).

```tablegen
def AddOp : Toy_Op<"add"> {
  let arguments = (ins F64:$lhs, F64:$rhs);
  let results = (outs F64:$result);
}
```

**What gets generated** (`--gen-op-decls` / `--gen-op-defs`, same command shape
as [Lesson 1](#lesson-1--a-dialect-and-your-first-operation) with `03_operands.td`).
The empty op of Lesson 1 now carries its operand count in the trait list and a
typed accessor per `$name`:

```c++
class AddOp : public ::mlir::Op<AddOp,
        ::mlir::OpTrait::OneResult,
        ::mlir::OpTrait::OneTypedResult<::mlir::FloatType>::Impl,  // result is F64
        ::mlir::OpTrait::NOperands<2>::Impl,                       // <- two operands now
        ::mlir::OpTrait::OpInvariants> {
  // one accessor per named operand; F64:$lhs ->
  ::mlir::TypedValue<::mlir::FloatType> getLhs() {                 // typed (FloatType), not raw Value
    return ::llvm::cast<::mlir::TypedValue<::mlir::FloatType>>(*getODSOperands(0).begin());
  }
  ::mlir::TypedValue<::mlir::FloatType> getRhs();                  // ... getODSOperands(1)
  ::mlir::OpOperand &getLhsMutable();                             // mutable handle, for rewrites
  ::mlir::TypedValue<::mlir::FloatType> getResult();              // F64:$result accessor

  // a builder that takes the operands by value (Lesson 1's op had none):
  static void build(::mlir::OpBuilder &, ::mlir::OperationState &,
                    ::mlir::Type result, ::mlir::Value lhs, ::mlir::Value rhs);
};
```

The accessor's *return type* follows the constraint: `F64` → `TypedValue<FloatType>`,
whereas a broad `AnyType` operand (see `SelectOp` in the same file) yields
`TypedValue<Type>`. The `op-defs` side gains a `verify(Location)` that checks each
operand's runtime type against its constraint.

## Lesson 4 — Attributes

*Source: `2-arguments/04_attributes.td`*

Attributes are *compile-time* values; they live in the same `arguments` dag,
mixed with operands. Flavors: a plain attribute (required),
`OptionalAttr<Attr>`, and `DefaultValuedAttr<Attr, "v">`.

```tablegen
let arguments = (ins
    AnyType:$input,
    I64Attr:$stride,                            // required
    DefaultValuedAttr<I64Attr, "1">:$dilation,  // default = 1
    OptionalAttr<StrAttr>:$name);               // may be omitted
```

**What gets generated** (`--gen-op-decls`, `04_attributes.td`). Each attribute
becomes a typed accessor whose shape follows its flavor. For `ConvOp`:

```c++
::mlir::IntegerAttr getStrideAttr();              // required I64Attr -> the raw attribute
uint64_t            getStride();                  // ...plus an unwrapped convenience getter
::mlir::IntegerAttr getDilationAttr();            // DefaultValuedAttr -> yields 1 when absent
::std::optional<::llvm::StringRef> getName();     // OptionalAttr -> empty optional when omitted
```

Attributes are kept in a generated `Properties` struct (MLIR's inherent-attribute
storage), and the `op-defs` side verifies the required ones are present and
correctly typed.

## Lesson 5 — Variadic and Optional operands

*Source: `2-arguments/05_variadic.td`*

`Variadic<T>` matches zero-or-more operands; `Optional<T>` zero-or-one. With
more than one variadic/optional group, MLIR needs help telling them apart at
runtime — add `AttrSizedOperandSegments` (or the `SameVariadicOperandSize`
trait).

```tablegen
def SumOp    : Toy_Op<"sum"> { let arguments = (ins Variadic<F64>:$inputs); ... }
def ConcatOp : Toy_Op<"concat", [AttrSizedOperandSegments]> {
  let arguments = (ins Variadic<AnyType>:$lhs, Variadic<AnyType>:$rhs); ... }
```

**What gets generated** (`--gen-op-decls`, `05_variadic.td`). A `Variadic<T>`
operand yields a *range* accessor rather than a single value:

```c++
::mlir::Operation::operand_range getInputs();    // SumOp: zero-or-more F64 operands
::mlir::MutableOperandRange       getInputsMutable();
```

With two variadic groups, `AttrSizedOperandSegments` adds a hidden
`operandSegmentSizes` property recording where one group ends and the next
begins; each group's accessor then slices the operands by those sizes:

```c++
// ConcatOp, [AttrSizedOperandSegments]:
using operandSegmentSizesTy = std::array<int32_t, 2>;   // {#lhs, #rhs}
::mlir::Operation::operand_range getLhs();              // first segment
::mlir::Operation::operand_range getRhs();              // second segment
```

---

## Lesson 6 — Results

*Source: `3-results-and-regions/06_results.td`*

Results are declared in `results = (outs ...)`, mirroring operands — same type
constraints and `Variadic<T>`. Multiple results yield named accessors
(`getQuotient()` / `getRemainder()`); multiple *variadic* results need
`AttrSizedResultSegments`.

```tablegen
def DivModOp : Toy_Op<"divmod"> {
  let arguments = (ins I64:$lhs, I64:$rhs);
  let results = (outs I64:$quotient, I64:$remainder);
}
```

**What gets generated** (`--gen-op-decls`, `06_results.td`). Multiple results
become one named accessor each, mirroring operands:

```c++
::mlir::TypedValue<::mlir::IntegerType> getQuotient();   // outs I64:$quotient -> result 0
::mlir::TypedValue<::mlir::IntegerType> getRemainder();  // result 1
```

A `Variadic` result (see `UnpackOp` in the same file) instead yields a
`result_range getResults()`.

## Lesson 7 — Regions and Successors

*Source: `3-results-and-regions/07_regions_successors.td`*

Regions hold nested blocks (loop/if/func bodies), declared in
`regions = (region ...)` with `AnyRegion` or `SizedRegion<N>`. Successors are
control-flow target blocks for terminator ops, declared in
`successors = (successor ...)`.

```tablegen
def WhileOp : Toy_Op<"while"> {
  let arguments = (ins I1:$cond);
  let regions = (region SizedRegion<1>:$body);
}
def CondBranchOp : Toy_Op<"cond_br", [Terminator]> {
  let successors = (successor AnySuccessor:$trueDest, AnySuccessor:$falseDest);
}
```

**What gets generated** (`--gen-op-decls`, `07_regions_successors.td`). A region
becomes a `Region &` accessor; a successor becomes a `Block *` accessor:

```c++
// WhileOp — region SizedRegion<1>:$body:
::mlir::Region &getBody();
// CondBranchOp — successor …:$trueDest, $falseDest:
::mlir::Block *getTrueDest();    // -> (*this)->getSuccessor(0)
::mlir::Block *getFalseDest();   // -> getSuccessor(1)
// and a builder that takes the successor blocks:
static void build(::mlir::OpBuilder &, ::mlir::OperationState &,
                  ::mlir::Value cond, ::mlir::Block *trueDest, ::mlir::Block *falseDest);
```

---

## Lesson 8 — Traits

*Source: `4-traits-and-verification/08_traits.td`*

Traits attach reusable semantics/verification, passed as the op's trait list.
Some are plain (`Commutative`, `Terminator`, in `OpBase.td`); others need
interface includes — `Pure` (`SideEffectInterfaces.td`),
`SameOperandsAndResultType` (`InferTypeOpInterface.td`). Type-inferring traits
make ODS emit a builder that doesn't require the result type.

```tablegen
include "mlir/Interfaces/SideEffectInterfaces.td"
include "mlir/Interfaces/InferTypeOpInterface.td"

def AddOp : Toy_Op<"add", [Pure, Commutative, SameOperandsAndResultType]> { ... }
```

**What gets generated** (`--gen-op-decls`, `08_traits.td`). Traits append to the
op's base-class list, and some pull in interface methods. `AddOp`'s class now reads:

```c++
class AddOp : public ::mlir::Op<AddOp, /* …structural traits… */,
        ::mlir::OpTrait::IsCommutative,                 // Commutative
        ::mlir::ConditionallySpeculatable::Trait,       // }
        ::mlir::MemoryEffectOpInterface::Trait,         // } from Pure
        ::mlir::OpTrait::SameOperandsAndResultType,
        ::mlir::InferTypeOpInterface::Trait> {          // <- enables type inference
  // because the result type is inferable, ODS adds:
  static ::llvm::LogicalResult inferReturnTypes(/* … */,
      ::llvm::SmallVectorImpl<::mlir::Type> &inferredReturnTypes);
};
```

That `inferReturnTypes` is what lets builders and the parser construct the op
without you spelling out the result type.

## Lesson 9 — Constraints and custom verification

*Source: `4-traits-and-verification/09_constraints.td`*

Tighten declarative checks with `ConfinedAttr<Attr, [...]>` (e.g.
`IntNonNegative`) and cross-entity traits like `AllTypesMatch<[...]>`. For logic
that can't be expressed declaratively, set `hasVerifier = 1`; ODS then declares
`LogicalResult verify();` for you to implement in C++.

```tablegen
def ReshapeOp : Toy_Op<"reshape", [AllTypesMatch<["input", "result"]>]> {
  let arguments = (ins AnyType:$input, ConfinedAttr<I64Attr, [IntNonNegative]>:$rank);
  let results = (outs AnyType:$result);
}
def RangeOp : Toy_Op<"range"> { ...; let hasVerifier = 1; }
```

**What gets generated** (`--gen-op-decls`, `09_constraints.td`). `hasVerifier = 1`
makes ODS *declare* a hook you implement, next to the auto-generated structural
checks:

```c++
// RangeOp:
::llvm::LogicalResult verifyInvariants();   // auto: operand/result/attr types
::llvm::LogicalResult verify();             // <- YOU write this (because hasVerifier = 1)
```

Declarative constraints need no hook: `ConfinedAttr<I64Attr, [IntNonNegative]>`
and `AllTypesMatch<["input","result"]>` are folded straight into the generated
`verifyInvariants()` body in `op-defs`.

---

## Lesson 10 — Declarative assembly format

*Source: `5-assembly-and-builders/10_assembly_format.td`*

`assemblyFormat` describes the op's textual syntax, so you skip a hand-written
parser/printer. It interleaves backtick literals, `$operand`/`$attr`
references, `type(...)` directives, and `attr-dict`.

```tablegen
def AddOp : Toy_Op<"add"> {
  let arguments = (ins F64:$lhs, F64:$rhs);
  let results = (outs F64:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
}
// prints:  %r = toy.add %a, %b : f64
```

**What gets generated** (`--gen-op-decls` / `--gen-op-defs`,
`10_assembly_format.td`). Instead of leaving the parser/printer to you, ODS emits
both from the format string:

```c++
static ::mlir::ParseResult parse(::mlir::OpAsmParser &parser, ::mlir::OperationState &result);
void                       print(::mlir::OpAsmPrinter &p);
```

The `op-defs` bodies implement exactly the format string you wrote — read them to
see how each directive (`$lhs`, the `,` literal, `attr-dict`, `type(...)`) becomes
a parse/print call.

## Lesson 11 — Custom builders

*Source: `5-assembly-and-builders/11_builders.td`*

ODS auto-generates `build()` methods; add convenience overloads with
`OpBuilder<(ins ...), [{ C++ body }]>`. Inside the body, `$_builder` and
`$_state` are the current builder and op state. `skipDefaultBuilders = 1`
suppresses the auto-generated ones.

```tablegen
let builders = [
  OpBuilder<(ins "double":$value), [{
    build($_builder, $_state, $_builder.getF64Type(),
          $_builder.getF64FloatAttr(value));
  }]>
];
```

**What gets generated** (`--gen-op-decls`, `11_builders.td`). Your `OpBuilder`
becomes an extra `build()` overload alongside the auto-generated ones:

```c++
// ConstantOp — from OpBuilder<(ins "double":$value), …>:
static void build(::mlir::OpBuilder &, ::mlir::OperationState &, double value);
// plus the default overloads ODS always emits:
static void build(::mlir::OpBuilder &, ::mlir::OperationState &, ::mlir::Type result, /* … */);
```

The C++ you wrote in the `[{ … }]` block lands in the matching `op-defs`
definition. `skipDefaultBuilders = 1` would drop the auto-generated overloads,
leaving only yours.

---

## Lesson 12 — Enums (EnumAttr)

*Source: `6-enums/12_enum.td`*

> Custom **attributes** and **types** moved to their own tutorial:
> [`../attrs-and-types/`](../attrs-and-types/README.md). This lesson keeps just
> the enum, which ops use directly in their `arguments`.

Define cases with `I32EnumAttrCase`, the enum with `I32EnumAttr`, then wrap it
as a dialect attribute with `EnumAttr` so ops can use it in `arguments`. Needs
`mlir/IR/EnumAttr.td`.

```tablegen
def Comparison : I32EnumAttr<"Comparison", "comparison predicate",
    [I32EnumAttrCase<"eq", 0>, I32EnumAttrCase<"lt", 1>, I32EnumAttrCase<"gt", 2>]> {
  let cppNamespace = "::toy";
}
def ComparisonAttr : EnumAttr<Toy_Dialect, Comparison, "comparison">;
```

**What gets generated** (`--gen-enum-decls` / `--gen-enum-defs`, `12_enum.td`).
A plain C++ enum plus string/symbol conversion helpers:

```c++
enum class Comparison : uint32_t { eq = 0, lt = 1, gt = 2 };          // the cases
::llvm::StringRef           stringifyComparison(Comparison);          // enum -> "eq"/"lt"/"gt"
::std::optional<Comparison> symbolizeComparison(::llvm::StringRef);   // string -> enum
::std::optional<Comparison> symbolizeComparison(uint32_t);           // int -> enum
```

`EnumAttr<Toy_Dialect, Comparison, "comparison">` then wraps the enum as a dialect
attribute (its own `--gen-attrdef-*` output), so `CmpOp` can take
`ComparisonAttr:$predicate` in its `arguments`.

---

## Generating the C++

From the `mlir-tablegen/` root, `./gen-all.sh` runs the matching backend for
every lesson and writes the result under `generated/`. To run one by hand:

```bash
MLIR=/opt/homebrew/opt/llvm@20
$MLIR/bin/mlir-tblgen --gen-op-defs -I $MLIR/include \
  ods/2-arguments/03_operands.td
```

Consuming the output for real means `#include`-ing it into a dialect library and
compiling against `libMLIR` (you need a registered dialect + `MLIRContext`),
which is heavier than a standalone demo — see the top-level
[README](../README.md#building-a-real-dialect-the-mlir_tablegen-cmake-flow) for
the standard `mlir_tablegen()` CMake flow.
