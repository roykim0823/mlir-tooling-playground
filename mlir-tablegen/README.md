# MLIR TableGen — ODS, DRR, Passes & Interfaces

MLIR drives four TableGen workflows through **`mlir-tblgen`**, and this
tutorial covers all of them, each in its own directory:

| Directory | What it does | `mlir-tblgen` backends |
|---|---|---|
| [`ods/`](ods) | **Operation Definition Specification** — *define* operations (+ enums) | `--gen-op-decls`/`-defs`, `--gen-dialect-*`, `--gen-enum-*` |
| [`attrs-and-types/`](attrs-and-types) | *define* custom **attributes & types** (`AttrDef`/`TypeDef`) | `--gen-attrdef-*`, `--gen-typedef-*` |
| [`drr/`](drr) | **Declarative Rewrite Rules** — *rewrite* IR with source→result patterns | `--gen-rewriters` |
| [`passes/`](passes) | **Passes** — *schedule* a transformation: argument, options, statistics, registration | `--gen-pass-decls`, `--gen-pass-doc` |
| [`interfaces/`](interfaces) | **Interfaces** — *define* a virtual API (`OpInterface`/`AttrInterface`/`TypeInterface`) that passes target instead of concrete ops | `--gen-{op,attr,type}-interface-{decls,defs,docs}` |
| [`docs/`](docs) | **Documentation** — render the `summary`/`description` fields of all of the above as Markdown reference pages | `--gen-dialect-doc`, `--gen-{op,attrdef,typedef,enum,pass}-doc` |

All six use the same TableGen language and the same tool. They differ in the
base classes you build on (`Op`/`Dialect`, `AttrDef`/`TypeDef`, `Pat`/`Pattern`,
`Pass`, `OpInterface`) and in the backend you invoke, and they stack: DRR
patterns match the ops ODS defined, a pass's `runOnOperation()` runs the DRR
patterns, and the doc backends render the same records once more as Markdown.

There is also a **buildable capstone** ([`capstone-toy/`](capstone-toy)) that
compiles ops, a custom type, a custom attribute, and a pass into a real dialect
library, exposes them through its own `toy-opt` tool *and* as a plugin for the
stock `mlir-opt`, and tests them with lit.
It also mixes in patterns written in **PDLL**, MLIR's non-TableGen pattern
language, which has its own track in [`../mlir-pdll/`](../mlir-pdll).

## Relationship to `llvm-tablegen/`

This is the MLIR sibling of the [`../llvm-tablegen/`](../llvm-tablegen) tutorials
(the [language](../llvm-tablegen/language) and [backend](../llvm-tablegen/backend)
halves). The mapping between the two worlds:

| Role | LLVM (`llvm-tblgen`) | MLIR (`mlir-tblgen`) |
|---|---|---|
| Declaratively **define** an entity | instruction / register / intrinsic descriptions | **ODS** — `Op`, `AttrDef`, `TypeDef` |
| Declaratively **rewrite** via DAG patterns | SelectionDAG ISel patterns (`--gen-dag-isel`) | **DRR** — `Pat`, `Pattern` (`--gen-rewriters`) |
| Declaratively describe a **pass** | *(none — LLVM passes are plain C++)* | **Passes** — `Pass`, `Option`, `Statistic` (`--gen-pass-decls`) |
| Declaratively define a **virtual API** | *(none)* | **Interfaces** — `OpInterface`, `InterfaceMethod` (`--gen-op-interface-*`) |

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
├── passes/                       # declaring passes (--gen-pass-decls)
│   ├── 1-basics/                 #   Pass<>, the generated base class, GEN_PASS_* guards
│   ├── 2-options-and-statistics/ #   Option, ListOption, Statistic, --gen-pass-doc
│   └── 3-anchors-and-dialects/   #   anchor ops, InterfacePass, dependentDialects, constructor
├── interfaces/                   # defining OpInterface / AttrInterface / TypeInterface
│   ├── 1-op-interface/           #   OpInterface, InterfaceMethod, DeclareOpInterfaceMethods, Concept/Model
│   ├── 2-defaults-and-verification/ # default vs shared bodies, static methods, extra*Declaration, verify
│   └── 3-attr-and-type-interfaces/  # TypeInterface/AttrInterface, interfaces as ODS constraints
├── docs/                         # the documentation backends
│   └── 1-documented-dialect/     #   summary/description everywhere, AttrParameter/TypeParameter descriptions, enums
├── capstone-toy/                 # a complete, BUILDABLE out-of-tree dialect
│   ├── include/Toy/ lib/         #   ODS + DRR + PDLL + pass + interfaces + glue, compiled into a library
│   ├── tools/                    #   a driver program and toy-opt (our mlir-opt)
│   ├── test/                     #   lit suite driving toy-opt
│   └── CMakeLists.txt            #   find_package(MLIR) + mlir_tablegen() + add_lit_testsuite()
├── gen-all.sh                    # run mlir-tblgen over every lesson
└── README.md                     # (this file)
```

Each lesson `.td` is self-contained — it defines a tiny `toy` dialect (or, for
`passes/`, a few `Pass` records) and runs standalone through `mlir-tblgen`. Start with **[`ods/`](ods/README.md)** (you
need ops before you can rewrite them), then **[`attrs-and-types/`](attrs-and-types/README.md)**,
**[`drr/`](drr/README.md)**, **[`passes/`](passes/README.md)** (you need a
rewrite before there is anything for a pass to run), and
**[`interfaces/`](interfaces/README.md)** (which makes those passes generic).
**[`docs/`](docs/README.md)** can be read at any point: it is about the
`summary`/`description` fields you have been writing all along.

> Editing `.td` files is much easier with `tblgen-lsp-server` running (hover
> on a record shows its summary, go-to-definition on a class). The
> [`../mlir-lsp/`](../mlir-lsp/README.md) track explains the
> `tablegen_compile_commands.yml` it needs, which the capstone's CMake build
> writes.

## Prerequisites

An LLVM/MLIR install with `mlir-tblgen` and the MLIR `.td` includes (e.g.
`brew install llvm@20`). The lessons were written against **LLVM/MLIR 20**.

```bash
mlir-tblgen --version
ls /opt/homebrew/opt/llvm@20/include/mlir/IR/OpBase.td   # the base ODS include
```

## Generating the C++

`./gen-all.sh` runs the right backend(s) for every lesson and writes the output
under `generated/`, mirroring the source tree. Each backend gets its own suffix:
`.op-decls.inc`/`.op-defs.inc` for ops, `.rewriters.inc` for DRR,
`.pass-decls.inc` (+ `.pass-doc.md`) for passes, `.op-interface-decls.inc` and
friends for interfaces, `.dialect-doc.md` and friends for docs, and matching
`attrdef-`/`typedef-`/`enum-`/`dialect-` variants for the rest:

```bash
./gen-all.sh
# ods/2-arguments/03_operands.td   --gen-op-decls->  generated/ods/2-arguments/03_operands.op-decls.inc
# drr/1-basics/01_basic_pattern.td --gen-rewriters-> generated/drr/1-basics/01_basic_pattern.rewriters.inc
# ...
```

Run a single file by hand:

```bash
MLIR=/opt/homebrew/opt/llvm@20
$MLIR/bin/mlir-tblgen --gen-op-defs   -I $MLIR/include ods/2-arguments/03_operands.td
$MLIR/bin/mlir-tblgen --gen-rewriters -I $MLIR/include drr/1-basics/01_basic_pattern.td
$MLIR/bin/mlir-tblgen --gen-pass-decls -name Toy -I $MLIR/include passes/1-basics/01_pass.td
```

> The `mlir-tblgen` path is set at the top of `gen-all.sh` (Homebrew `llvm@20`
> by default) — edit it if your install differs.

## Capstone: building a real dialect

The lessons above only *generate* C++. The **[`capstone-toy/`](capstone-toy/README.md)**
directory goes all the way: a complete, **buildable** out-of-tree dialect that
compiles the generated code into a dialect library, a driver program, and a
`toy-opt` tool, then tests the tool with a lit suite.

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
./build/toy-capstone                        # builds toy IR, prints it, folds add(const,const), prints again
./build/toy-opt test/fold.mlir -toy-fold    # the same fold as a pass, in our own mlir-opt
mlir-opt --load-dialect-plugin=build/ToyPlugin.dylib --load-pass-plugin=build/ToyPlugin.dylib \
         test/fold.mlir -pass-pipeline='builtin.module(toy-fold)'   # ...or in the STOCK mlir-opt
cmake --build build --target check-toy      # lit tests driving both
cmake --build build --target mlir-doc       # reference docs -> build/docs/Toy/*.md
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

(The CMake helpers themselves — `mlir_tablegen`, `add_mlir_dialect`,
`add_mlir_dialect_library` and the rest — are explained in the
[`../mlir-cmake/`](../mlir-cmake/README.md) chapter. The snippet is abridged — the real `CMakeLists.txt` runs **fourteen** backends,
adding the `typedef`/`attrdef` pairs for the custom type and attribute,
`-gen-pass-decls` for the pass and the four `-gen-*-interface-*` for the
interfaces, and builds `toy-opt` against `MLIROptLib`.) The
`-gen-*` flags are the same ones `gen-all.sh` runs ad hoc; `mlir_tablegen()`
just plugs them into the build graph and re-runs them when a `.td` changes. See
[`capstone-toy/README.md`](capstone-toy/README.md) for the full walkthrough.

## References

- ODS — <https://mlir.llvm.org/docs/DefiningDialects/Operations/>
- DRR — <https://mlir.llvm.org/docs/DeclarativeRewrites/>
- Passes — <https://mlir.llvm.org/docs/PassManagement/> (*Declarative Pass Specification*)
- Interfaces — <https://mlir.llvm.org/docs/Interfaces/>
- Defining a dialect — <https://mlir.llvm.org/docs/DefiningDialects/>
