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

**Generates:** `mlir-tblgen --gen-dialect-decls` → `class ToyDialect`;
`--gen-op-decls` / `--gen-op-defs` → `class NopOp`.

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

**Generates:** op docs via `--gen-op-doc`; the op class as before.

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

**Generates:** `getLhs()` / `getRhs()` accessors and operand verification.

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

**Generates:** typed attribute accessors folded into the op's attribute dict.

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

**Generates:** range accessors; an `operandSegmentSizes` attribute for the
segmented case.

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

**Generates:** `--gen-enum-decls` / `--gen-enum-defs` → `enum class Comparison`.

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
