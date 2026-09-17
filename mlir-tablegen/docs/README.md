# Documentation backends — `--gen-dialect-doc` and friends

The same `.td` files that generate a dialect's C++ also generate its
**reference documentation**. Every ODS record has `summary` and `description`
fields that the C++ backends ignore; the *doc* backends render them, together
with the structure they can derive (operands, results, attributes, syntax,
traits, parameters, options), as Markdown. The pages under
<https://mlir.llvm.org/docs/Dialects/> and <https://mlir.llvm.org/docs/Passes/>
are produced exactly this way.

> Required includes: whatever the definitions need (`OpBase.td`,
> `AttrTypeBase.td`, `EnumAttr.td`, `PassBase.td`, `Interfaces.td`). The
> [capstone](../../mlir-capstone/README.md) wires the backends into CMake so
> `cmake --build build --target mlir-doc` writes `build/docs/Toy/*.md`.

| Backend | Input records | Output |
|---|---|---|
| `--gen-dialect-doc -dialect=NAME` | one dialect's ops, attributes, types, enums | one page per dialect (the usual choice) |
| `--gen-op-doc` / `--gen-attrdef-doc` / `--gen-typedef-doc` / `--gen-enum-doc` | just that kind | fragments, for assembling pages by hand |
| `--gen-pass-doc` | `Pass` records | the pass reference (`-toy-fold`, options, statistics) |
| `--gen-op-interface-docs` / `--gen-attr-interface-docs` / `--gen-type-interface-docs` | interfaces | method reference, marking what implementers must define |

Common options: `--op-include-regex` / `--op-exclude-regex` select ops by
name for the dialect/op pages; `--strip-prefix=::toy::` shortens the C++ class
names shown in headings (`(::toy::AddOp)` → `(AddOp)`);
`-allow-hugo-specific-features` is for the website build (it changes nothing
for a dialect like this one).

```bash
MLIR=/opt/homebrew/opt/llvm@20
$MLIR/bin/mlir-tblgen --gen-dialect-doc -dialect=toy -I $MLIR/include 1-documented-dialect/01_documented_dialect.td
../gen-all.sh     # every doc backend for the lesson -> ../generated/docs/
```

## Lesson 1 — Writing for the doc backends

*Source: `1-documented-dialect/01_documented_dialect.td`*

The lesson fills every documentation field so you can see where each lands.
The mapping:

| In the `.td` | In the Markdown |
|---|---|
| `Dialect.summary`, `Dialect.description` | the paragraphs under `# 'toy' Dialect`, before `[TOC]` |
| `Op.summary` | the italic one-liner under `### toy.add (::toy::AddOp)` |
| `Op.description` | the body — Markdown, so code blocks and lists work |
| `assemblyFormat` | the `Syntax:` block, verbatim |
| operands / results / attributes | tables; the **Description column is the constraint's summary** (`F64` → "64-bit float", `F64Attr` → "64-bit float attribute") |
| traits & interfaces | the `Traits:` / `Interfaces:` / `Effects:` lines (derived; `Pure` expands to what it really is) |
| `AttrDef`/`TypeDef` `summary`, `description`, `assemblyFormat` | the attribute/type sections, with a rendered `Syntax:` such as `!toy.array<int64_t, ::mlir::Type>` |
| `AttrParameter<"T", "desc">` / `TypeParameter<"T", "desc">` | the **Description** column of the Parameters table |
| `I32EnumAttr` cases | a Symbol / Value / String table (`--gen-enum-doc`) |

```tablegen
def Toy_Dialect : Dialect {
  let name = "toy";
  let summary = "A tiny f64 arithmetic dialect used throughout this repository.";
  let description = [{
    Toy has a handful of scalar `f64` operations, ...
    * this list item is in the dialect description
  }];
}

def AddOp : Toy_Op<"add", [Pure]> {
  let summary = "f64 addition";
  let description = [{
    Adds two `f64` values. Example:

    ```mlir
    %sum = toy.add %a, %b
    ```
  }];
  ...
}

def Toy_ShapeAttr : Toy_Attr<"Shape"> {
  let parameters = (ins
    AttrParameter<"int64_t", "number of rows">:$rows,      // <- documented
    AttrParameter<"int64_t", "number of columns">:$cols
  );
}
```

`--gen-dialect-doc -dialect=toy` produces (abridged):

```markdown
# 'toy' Dialect

A tiny f64 arithmetic dialect used throughout this repository.

Toy has a handful of scalar `f64` operations, one custom type and one custom
attribute. ...

[TOC]

## Operations

### `toy.add` (::toy::AddOp)

_F64 addition_

Adds two `f64` values. Example:

```mlir
%sum = toy.add %a, %b
```

Syntax:

```
operation ::= `toy.add` $lhs `,` $rhs attr-dict
```

Traits: `AlwaysSpeculatableImplTrait`

Interfaces: `ConditionallySpeculatable`, `NoMemoryEffect (MemoryEffectOpInterface)`

#### Operands:

| Operand | Description |
| :-----: | ----------- |
| `lhs` | 64-bit float
| `rhs` | 64-bit float

...

## Attributes

### ShapeAttr

a static 2-D shape

Rows and columns of a matrix, e.g. `#toy.shape<3 x 4>`.

Syntax:

```
#toy.shape<
  int64_t,   # rows
  int64_t   # cols
>
```

#### Parameters:

| Parameter | C++ type | Description |
| :-------: | :-------: | ----------- |
| rows | `int64_t` | number of rows |
| cols | `int64_t` | number of columns |
```

The output shows three things about how these pages come out:

1. **`toy.print` has no `description`** — its section is the summary and the
   operand table, nothing else. Whether a page reads as a reference or as a
   stub is decided by the `description` fields, so write them in the `.td`.
2. **Parameter descriptions are opt-in.** `(ins "int64_t":$rows)` is what most
   tutorials show; it leaves the Description column empty. Use
   `AttrParameter<"int64_t", "...">:$rows` (or `TypeParameter`) — same C++,
   documented parameter.
3. **The tables are derived, not written.** `Pure` becomes
   `AlwaysSpeculatableImplTrait` + `ConditionallySpeculatable` +
   `NoMemoryEffect`; `F64` becomes "64-bit float". You document intent; the
   backend documents structure.

The fragment backends give the same sections without the page frame:

```bash
$MLIR/bin/mlir-tblgen --gen-op-doc      -I $MLIR/include 1-documented-dialect/01_documented_dialect.td   # ### toy.add ... only
$MLIR/bin/mlir-tblgen --gen-enum-doc    -I $MLIR/include 1-documented-dialect/01_documented_dialect.td
```
```markdown
### RoundingMode

how a toy.round op rounds

#### Cases:

| Symbol | Value | String |
| :----: | :---: | ------ |
| Nearest | `0` | nearest |
| Floor | `1` | floor |
| Ceil | `2` | ceil |
```

## Passes and interfaces

The [passes](../passes/README.md#lesson-2--options-and-statistics) and
[interfaces](../interfaces/README.md) tracks already showed `--gen-pass-doc`
and `--gen-op-interface-docs`; the capstone generates both for real:

```markdown
### `-toy-fold`

_Constant-fold BinaryArithOpInterface ops (add/mul/sub) using the DRR, PDLL and C++ patterns_

Applies the DRR `Pat` rewrites declared in ToyOps.td, ...

#### Options
```
-max-iterations : Maximum number of greedy rewrite iterations (...)
-report         : Emit a remark on the module with the number of folded ops
```
```

## Generating with CMake: `add_mlir_doc`

MLIR's helper takes the `.td` (without extension), an output name, a
subdirectory, and the backend flags. The capstone's `CMakeLists.txt`:

```cmake
set(MLIR_BINARY_DIR ${CMAKE_BINARY_DIR})          # see below
if(NOT TARGET mlir-doc)
  add_custom_target(mlir-doc)
endif()
add_mlir_doc(include/Toy/ToyOps        ToyDialect        Toy/ -gen-dialect-doc -dialect=toy)
add_mlir_doc(include/Toy/ToyPasses     ToyPasses         Toy/ -gen-pass-doc)
add_mlir_doc(include/Toy/ToyInterfaces ToyOpInterfaces   Toy/ -gen-op-interface-docs)
add_mlir_doc(include/Toy/ToyInterfaces ToyTypeInterfaces Toy/ -gen-type-interface-docs)
```

```bash
cd ../../mlir-capstone
cmake --build build --target mlir-doc
find build/docs -type f
# build/docs/Toy/ToyDialect.md
# build/docs/Toy/ToyOpInterfaces.md
# build/docs/Toy/ToyPasses.md
# build/docs/Toy/ToyTypeInterfaces.md
```

Each call runs `mlir-tblgen` into `<build>/<output>.md`, then copies the
file to `${MLIR_BINARY_DIR}/docs/<subdir><output>.md` and adds a
`<output>DocGen` target to `mlir-doc`. Out of tree, two things go wrong:

- **`MLIR_BINARY_DIR` is not set** by an installed `MLIRConfig.cmake` (it is an
  in-tree variable), so without the `set(...)` the copy goes to `/docs/...` at
  the filesystem root. Point it at your build directory.
- **`mlir-doc` must exist** before the first `add_mlir_doc`. The installed
  `MLIRConfig.cmake` already creates it during `find_package(MLIR)`, so a plain
  `add_custom_target(mlir-doc)` fails with *another target with the same name
  already exists*; the `if(NOT TARGET ...)` guard works whether or not your
  MLIR version does this.

The docs are **not** built by default — `mlir-doc` is a separate target, so
`cmake --build build` stays fast and the docs are regenerated on demand (or by
CI, which is where diffing them against the committed copy catches an op whose
description nobody updated).

## References

- Defining dialects: documentation fields — <https://mlir.llvm.org/docs/DefiningDialects/Operations/#operation-documentation>
- The generated pages upstream — <https://mlir.llvm.org/docs/Dialects/> (e.g. `arith`), <https://mlir.llvm.org/docs/Passes/>
- `add_mlir_doc` — `AddMLIR.cmake` in your MLIR install (`lib/cmake/mlir/`)
