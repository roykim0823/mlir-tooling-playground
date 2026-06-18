# MLIR TableGen — ODS & DRR

MLIR drives two big TableGen workflows through **`mlir-tblgen`**, and this
tutorial covers both, each in its own directory:

| Directory | What it does | `mlir-tblgen` backends |
|---|---|---|
| [`ods/`](ods) | **Operation Definition Specification** — *define* operations (+ enums) | `--gen-op-decls`/`-defs`, `--gen-dialect-*`, `--gen-enum-*` |
| [`attrs-and-types/`](attrs-and-types) | *define* custom **attributes & types** (`AttrDef`/`TypeDef`) | `--gen-attrdef-*`, `--gen-typedef-*` |
| [`drr/`](drr) | **Declarative Rewrite Rules** — *rewrite* IR with source→result patterns | `--gen-rewriters` |

All three are the *same* TableGen language and tool — they differ only in the
base classes they build on (`Op`/`Dialect`, `AttrDef`/`TypeDef`, `Pat`/`Pattern`)
and the backend you invoke. **DRR builds on ODS**: a rewrite pattern's DAG
operators are the ops you defined with ODS.

There is also a **buildable capstone** ([`capstone-toy/`](capstone-toy)) that
compiles ops, a custom type, and a custom attribute into a real dialect library.

## Relationship to `llvm-tablegen/`

This is the MLIR sibling of the [`../llvm-tablegen/`](../llvm-tablegen) tutorials
(the [language](../llvm-tablegen/language) and [backend](../llvm-tablegen/backend)
halves). The mapping between the two worlds:

| Role | LLVM (`llvm-tblgen`) | MLIR (`mlir-tblgen`) |
|---|---|---|
| Declaratively **define** an entity | instruction / register / intrinsic descriptions | **ODS** — `Op`, `AttrDef`, `TypeDef` |
| Declaratively **rewrite** via DAG patterns | SelectionDAG ISel patterns (`--gen-dag-isel`) | **DRR** — `Pat`, `Pattern` (`--gen-rewriters`) |

The big difference in scope: LLVM uses TableGen only for *target codegen* (core
IR is hand-written C++), whereas in MLIR **every** dialect — even built-in ones
— is defined via ODS.

## Directory layout

```
mlir-tablegen/
├── ods/                          # Operation Definition Specification
│   ├── 1-dialect-and-ops/        #   dialect + first op, metadata
│   ├── 2-arguments/              #   operands, attributes, variadic/optional
│   ├── 3-results-and-regions/    #   results, regions, successors
│   ├── 4-traits-and-verification/#   traits, constraints, custom verifier
│   ├── 5-assembly-and-builders/  #   assemblyFormat, custom builders
│   └── 6-enums/                  #   EnumAttr
├── attrs-and-types/              # custom attributes & types (AttrDef/TypeDef)
│   ├── 1-basics/                 #   AttrDef & TypeDef basics
│   ├── 2-parameters/             #   parameters, optional/default-valued
│   ├── 3-assembly-format/        #   assemblyFormat directives, custom format
│   ├── 4-builders-and-verification/ # custom builders, genVerifyDecl
│   └── 5-traits-interfaces-extras/  # traits/interfaces, extraClassDeclaration
├── drr/                          # Declarative Rewrite Rules
│   ├── 1-basics/                 #   Pat, source/result patterns
│   ├── 2-constraints/            #   constraints & custom predicates
│   ├── 3-native-code/            #   NativeCodeCall
│   ├── 4-multi-result-and-aux/   #   multi-result, auxiliary, supplemental
│   └── 5-directives/             #   replaceWithValue, returnType, either, ...
├── capstone-toy/                 # a complete, BUILDABLE out-of-tree dialect
│   ├── include/Toy/ lib/ tools/  #   ODS + DRR + glue, compiled into a driver
│   └── CMakeLists.txt            #   find_package(MLIR) + mlir_tablegen()
├── gen-all.sh                    # run mlir-tblgen over every lesson
└── README.md                     # (this file)
```

Each lesson `.td` is self-contained — it defines a tiny `toy` dialect and runs
standalone through `mlir-tblgen`. Start with **[`ods/`](ods/README.md)** (you
need ops before you can rewrite them), then **[`attrs-and-types/`](attrs-and-types/README.md)**
and **[`drr/`](drr/README.md)**.

## Prerequisites

An LLVM/MLIR install with `mlir-tblgen` and the MLIR `.td` includes (e.g.
`brew install llvm@20`). The lessons were written against **LLVM/MLIR 20**.

```bash
mlir-tblgen --version
ls /opt/homebrew/opt/llvm@20/include/mlir/IR/OpBase.td   # the base ODS include
```

## Generating the C++

`./gen-all.sh` runs the right backend for every lesson and writes the output
under `generated/`, mirroring the source tree (ODS files emit `.decls.inc` +
`.defs.inc`; DRR files emit `.rewriters.inc`):

```bash
./gen-all.sh
# ods/2-arguments/03_operands.td  --gen-op-decls->  generated/ods/2-arguments/03_operands.decls.inc
# drr/1-basics/01_basic_pattern.td --gen-rewriters-> generated/drr/1-basics/01_basic_pattern.rewriters.inc
# ...
```

Run a single file by hand:

```bash
MLIR=/opt/homebrew/opt/llvm@20
$MLIR/bin/mlir-tblgen --gen-op-defs   -I $MLIR/include ods/2-arguments/03_operands.td
$MLIR/bin/mlir-tblgen --gen-rewriters -I $MLIR/include drr/1-basics/01_basic_pattern.td
```

> The `mlir-tblgen` path is set at the top of `gen-all.sh` (Homebrew `llvm@20`
> by default) — edit it if your install differs.

## Capstone: building a real dialect — [`capstone-toy/`](capstone-toy)

The lessons above only *generate* C++. The **[`capstone-toy/`](capstone-toy/README.md)**
directory goes all the way: a complete, **buildable** out-of-tree dialect that
compiles the generated code into a dialect library and a driver program.

Unlike the `llvm-tablegen` searchable-table demo (which links only
`libLLVMSupport`), MLIR-generated C++ is compiled **into a dialect library**
against `libMLIR`: it needs a registered dialect, an `MLIRContext`, and
hand-written `.cpp` glue (the dialect `initialize()` that registers ops, any
`NativeCodeCall` helpers). The capstone wires generation into CMake with MLIR's
own `mlir_tablegen()` macro rather than a shell script:

```bash
cd capstone-toy
cmake -S . -B build -DMLIR_DIR=/opt/homebrew/opt/llvm@20/lib/cmake/mlir
cmake --build build
./build/toy-capstone        # builds toy IR, prints it, folds add(const,const), prints again
```

```cmake
set(LLVM_TARGET_DEFINITIONS include/Toy/ToyOps.td)
mlir_tablegen(include/Toy/ToyOps.h.inc       -gen-op-decls)
mlir_tablegen(include/Toy/ToyOps.cpp.inc     -gen-op-defs)
mlir_tablegen(include/Toy/ToyDialect.h.inc   -gen-dialect-decls -dialect=toy)
mlir_tablegen(include/Toy/ToyDialect.cpp.inc -gen-dialect-defs  -dialect=toy)
mlir_tablegen(include/Toy/ToyPatterns.inc    -gen-rewriters)
add_public_tablegen_target(ToyIncGen)                 # the generation step

add_mlir_dialect_library(MLIRToy lib/ToyDialect.cpp lib/ToyPatterns.cpp
                         DEPENDS ToyIncGen LINK_LIBS PUBLIC MLIRIR MLIRSupport)
```

The `-gen-*` flags are exactly the ones `gen-all.sh` runs here; `mlir_tablegen()`
just plugs them into the build graph and re-runs them when a `.td` changes. See
[`capstone-toy/README.md`](capstone-toy/README.md) for the full walkthrough.

## References

- ODS — <https://mlir.llvm.org/docs/DefiningDialects/Operations/>
- DRR — <https://mlir.llvm.org/docs/DeclarativeRewrites/>
- Defining a dialect — <https://mlir.llvm.org/docs/DefiningDialects/>
