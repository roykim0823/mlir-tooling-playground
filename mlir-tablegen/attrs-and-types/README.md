# Attributes & Types — defining custom `AttrDef` / `TypeDef`

A dialect doesn't just define operations — it can define its own **attributes**
(compile-time values like `#toy.shape<3 x 4>`) and **types** (`!toy.int<32>`).
This tutorial covers MLIR's ODS support for them: `AttrDef` / `TypeDef`,
parameters, parsing/printing, builders, verification, and traits/interfaces.
`mlir-tblgen` emits the C++ classes via `--gen-attrdef-*` / `--gen-typedef-*`.

> This is a sibling of the [`../ods/`](../ods) (Operations) tutorial — the MLIR
> docs put [Attributes and Types](https://mlir.llvm.org/docs/DefiningDialects/AttributesAndTypes/)
> on its own page next to [Operations](https://mlir.llvm.org/docs/DefiningDialects/Operations/).
> Attributes and types are **uniqued, immutable** values owned by the
> `MLIRContext`; `parameters` are their identity (the storage key).

Required base include: `mlir/IR/AttrTypeBase.td`. Each lesson is a self-contained
`.td` that runs standalone through `mlir-tblgen`.

## Table of Contents

**`1-basics/` — your first attribute and type**
- 1 — [Defining a custom attribute (AttrDef)](#lesson-1--defining-a-custom-attribute-attrdef)
- 2 — [Defining a custom type (TypeDef)](#lesson-2--defining-a-custom-type-typedef)

**`2-parameters/` — what an attr/type stores**
- 3 — [Parameters](#lesson-3--parameters)
- 4 — [Optional and default-valued parameters](#lesson-4--optional-and-default-valued-parameters)

**`3-assembly-format/` — textual syntax**
- 5 — [Declarative assemblyFormat & directives](#lesson-5--declarative-assemblyformat--directives)
- 6 — [Hand-written parser/printer](#lesson-6--hand-written-parserprinter)

**`4-builders-and-verification/` — construction & checking**
- 7 — [Builders](#lesson-7--builders)
- 8 — [Verification (genVerifyDecl)](#lesson-8--verification-genverifydecl)

**`5-traits-interfaces-extras/` — semantics & escape hatches**
- 9 — [Traits and interfaces](#lesson-9--traits-and-interfaces)
- 10 — [Extra declarations & a note on storage](#lesson-10--extra-declarations--a-note-on-storage)

---

## Lesson 1 — Defining a custom attribute (AttrDef)

*Source: `1-basics/01_attrdef.td`*

Specialize `AttrDef`. The `mnemonic` is the keyword after the dialect prefix
(`#toy.shape`), `parameters` are the stored fields, `assemblyFormat` the textual
syntax. The C++ class defaults to `<name>Attr` (`ShapeAttr`).

```tablegen
def Toy_ShapeAttr : AttrDef<Toy_Dialect, "Shape"> {
  let mnemonic = "shape";
  let parameters = (ins "int64_t":$rows, "int64_t":$cols);
  let assemblyFormat = "`<` $rows `x` $cols `>`";   // #toy.shape<3 x 4>
}
```

The dialect needs `let useDefaultAttributePrinterParser = 1;` so it can dispatch
on the mnemonic. **Generates:** `--gen-attrdef-decls` / `--gen-attrdef-defs`.

## Lesson 2 — Defining a custom type (TypeDef)

*Source: `1-basics/02_typedef.td`*

Structurally identical, with `TypeDef`. The default C++ name is `<name>Type`;
`cppClassName` overrides it (handy to avoid clashes like `IntType`).

```tablegen
def Toy_IntType : TypeDef<Toy_Dialect, "Int"> {
  let mnemonic = "int";
  let cppClassName = "ToyIntType";
  let parameters = (ins "unsigned":$width);
  let assemblyFormat = "`<` $width `>`";            // !toy.int<32>
}
```

**Generates:** `--gen-typedef-decls` / `--gen-typedef-defs`.

---

## Lesson 3 — Parameters

*Source: `2-parameters/03_parameters.td`*

Each parameter is a raw C++ type (`"int64_t"`, `"::mlir::Type"`) or a
*specialized parameter class* that teaches ODS how to allocate/parse/print it:

- `ArrayRefParameter<"T">` — a variable-length `ArrayRef<T>` (copied into the context),
- `StringRefParameter<>` — a `StringRef`,
- `APFloatParameter<>` — an `APFloat`.

A `"::mlir::Type"` parameter lets a type nest other types.

```tablegen
def Toy_StructType : TypeDef<Toy_Dialect, "Struct"> {
  let mnemonic = "struct";
  let parameters = (ins StringRefParameter<"the struct's name">:$name,
                        ArrayRefParameter<"::mlir::Type">:$elementTypes);
  let assemblyFormat = "`<` $name `,` $elementTypes `>`";  // !toy.struct<"point", i32, f64>
}
```

## Lesson 4 — Optional and default-valued parameters

*Source: `2-parameters/04_optional_default.td`*

`OptionalParameter<"T">` may be absent; `DefaultValuedParameter<"T","v">` falls
back to a C++ default. With an optional group `(...$p^)?` in the format, they're
elided from the printed form when defaulted/none.

```tablegen
let parameters = (ins "int64_t":$rows, "int64_t":$cols,
    DefaultValuedParameter<"int64_t", "1">:$alignment,
    OptionalParameter<"::mlir::StringAttr">:$layout);
let assemblyFormat =
    "`<` $rows `x` $cols (`,` `align` `=` $alignment^)? (`,` `layout` `=` $layout^)? `>`";
```

---

## Lesson 5 — Declarative assemblyFormat & directives

*Source: `3-assembly-format/05_assembly_format.td`*

Beyond literals and `$param` references, the format offers directives:

- `params` — every parameter in order,
- `struct(params)` — order-independent `key = value` pairs,
- `qualified($p)` — print a nested attr/type with its full `#dialect.`/`!dialect.` prefix,
- `custom<Foo>(...)` — delegate one slice to a C++ `parseFoo`/`printFoo` pair.

```tablegen
def Toy_ConfigAttr : AttrDef<Toy_Dialect, "Config"> {
  let mnemonic = "config";
  let parameters = (ins "int64_t":$width, "int64_t":$isSigned);
  let assemblyFormat = "`<` struct(params) `>`";   // #toy.config<width = 8, signed = 1>
}
```

> Note: `.` is **not** a legal `assemblyFormat` literal (only letters and
> ``_:,=<>()[]{}?+*``); use another separator like `:`.

## Lesson 6 — Hand-written parser/printer

*Source: `3-assembly-format/06_custom_format.td`*

When the declarative format can't express the syntax, set
`hasCustomAssemblyFormat = 1` (and omit `assemblyFormat`). mlir-tblgen then
declares a `parse`/`print` pair you implement in C++:

```tablegen
def Toy_PolynomialAttr : AttrDef<Toy_Dialect, "Polynomial"> {
  let mnemonic = "poly";
  let parameters = (ins ArrayRefParameter<"int64_t">:$coefficients);
  let hasCustomAssemblyFormat = 1;   // -> static Attribute parse(...); void print(...) const;
}
```

---

## Lesson 7 — Builders

*Source: `4-builders-and-verification/07_builders.td`*

ODS auto-generates `get(ctx, params...)` / `getChecked`. Add convenience
overloads with `AttrBuilder` / `TypeBuilder`;
`TypeBuilderWithInferredContext` lets the context come from a parameter so the
caller needn't pass an `MLIRContext`. `skipDefaultBuilders = 1` suppresses the
generated ones.

```tablegen
let builders = [
  AttrBuilder<(ins "int64_t":$major), [{ return $_get($_ctxt, major, /*minor=*/0); }]>
];
```

## Lesson 8 — Verification (genVerifyDecl)

*Source: `4-builders-and-verification/08_verification.td`*

`genVerifyDecl = 1` generates a verifier you implement in C++; `getChecked`
calls it before construction:

```tablegen
def Toy_FixedType : TypeDef<Toy_Dialect, "Fixed"> {
  let parameters = (ins "unsigned":$totalBits, "unsigned":$fractionalBits);
  let genVerifyDecl = 1;
  // -> static LogicalResult verify(function_ref<InFlightDiagnostic()> emitError,
  //                                unsigned totalBits, unsigned fractionalBits);
}
```

---

## Lesson 9 — Traits and interfaces

*Source: `5-traits-interfaces-extras/09_traits_interfaces.td`*

Attributes/types can carry traits and interfaces in their trait list (the third
`AttrDef`/`TypeDef` argument). A marker interface like
`MemRefElementTypeInterface` just needs attaching; `DeclareTypeInterfaceMethods<I>`
pulls in interface `I`'s methods for you to implement.

```tablegen
def Toy_ScalarType : TypeDef<Toy_Dialect, "Scalar", [MemRefElementTypeInterface]> {
  let mnemonic = "scalar";
  let parameters = (ins "unsigned":$bitwidth);
}
```

## Lesson 10 — Extra declarations & a note on storage

*Source: `5-traits-interfaces-extras/10_extra_and_storage.td`*

`extraClassDeclaration` injects arbitrary C++ (derived accessors/helpers) into
the generated class:

```tablegen
let extraClassDeclaration = [{
  int64_t getNumElements() const { return getRows() * getCols(); }
  bool isSquare() const { return getRows() == getCols(); }
}];
```

**Storage (advanced):** ODS generates the uniqued storage class for you. Set
`genStorageClass = 0` to hand-write it (`KeyTy`, `construct()`, `==`, `hashKey`);
mutable attrs/types keep an immutable key but expose a post-construction
`mutate(...)`. Both are out of scope here.

---

## Generating the C++ — and a buildable example

From the `mlir-tablegen/` root, `./gen-all.sh` runs the matching backend(s) for
every lesson into `generated/`. By hand:

```bash
MLIR=/opt/homebrew/opt/llvm@20
$MLIR/bin/mlir-tblgen --gen-typedef-defs -I $MLIR/include attrs-and-types/1-basics/02_typedef.td
```

For attributes/types **compiled and registered** into a working dialect (with a
parse/print round-trip), see the capstone:
[`../capstone-toy/`](../capstone-toy/README.md), which defines a real `!toy.array`
type and `#toy.poly` attribute alongside its ops.
