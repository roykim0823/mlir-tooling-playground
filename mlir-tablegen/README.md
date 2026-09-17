# MLIR TableGen — ODS, DRR, Passes & Interfaces

MLIR drives four TableGen workflows through **`mlir-tblgen`**, and this
tutorial covers all of them, each in its own directory:

| Directory | What it does | `mlir-tblgen` backends |
|---|---|---|
| [`ods/`](ods) | **Operation Definition Specification** — *define* operations (+ enums) | `--gen-op-decls`/`-defs`, `--gen-dialect-*`, `--gen-enum-*` |
| [`attrs-and-types/`](attrs-and-types) | *define* custom **attributes & types** (`AttrDef`/`TypeDef`) | `--gen-attrdef-*`, `--gen-typedef-*` |
| [`passes/`](passes) | **Passes** — *schedule* a transformation: argument, options, statistics, registration | `--gen-pass-decls`, `--gen-pass-doc` |
| [`interfaces/`](interfaces) | **Interfaces** — *define* a virtual API (`OpInterface`/`AttrInterface`/`TypeInterface`) that passes target instead of concrete ops | `--gen-{op,attr,type}-interface-{decls,defs,docs}` |
| [`docs/`](docs) | **Documentation** — render the `summary`/`description` fields of all of the above as Markdown reference pages | `--gen-dialect-doc`, `--gen-{op,attrdef,typedef,enum,pass}-doc` |

All five use the same TableGen language and the same tool. They differ in the
base classes you build on (`Op`/`Dialect`, `AttrDef`/`TypeDef`, `Pass`,
`OpInterface`) and in the backend you invoke. The remaining TableGen workflow,
**DRR** rewrite patterns (`--gen-rewriters`), lives in
[`../mlir-patterns/drr/`](../mlir-patterns/drr) next to its PDLL twin, because
the two are best read side by side; its patterns match the ops ODS defined
here, and a pass's `runOnOperation()` is what runs them.

Everything generated here is compiled into a real dialect in
[`../mlir-capstone/`](../mlir-capstone), which has its own track.

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
├── gen-all.sh                    # run mlir-tblgen over every lesson
└── README.md                     # (this file)
```

Each lesson `.td` is self-contained: it defines a tiny `toy` dialect (or, for
`passes/`, a few `Pass` records) and runs standalone through `mlir-tblgen`.
Start with **[`ods/`](ods/README.md)**, then
**[`attrs-and-types/`](attrs-and-types/README.md)**. Rewriting the ops you
defined is the next track, [`../mlir-patterns/`](../mlir-patterns/README.md);
come back for **[`passes/`](passes/README.md)** (a pass is what runs those
rewrites), **[`interfaces/`](interfaces/README.md)** (which makes passes
generic), and **[`docs/`](docs/README.md)** (which can be read at any point).

> Editing `.td` files is much easier with `tblgen-lsp-server` running (hover
> on a record shows its summary, go-to-definition on a class). The
> [`../mlir-tools/lsp/`](../mlir-tools/lsp/README.md) track explains the
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
`.op-decls.inc`/`.op-defs.inc` for ops,
`.pass-decls.inc` (+ `.pass-doc.md`) for passes, `.op-interface-decls.inc` and
friends for interfaces, `.dialect-doc.md` and friends for docs, and matching
`attrdef-`/`typedef-`/`enum-`/`dialect-` variants for the rest:

```bash
./gen-all.sh
# ods/2-arguments/03_operands.td   --gen-op-decls->  generated/ods/2-arguments/03_operands.op-decls.inc
# ...
```

Run a single file by hand:

```bash
MLIR=/opt/homebrew/opt/llvm@20
$MLIR/bin/mlir-tblgen --gen-op-defs   -I $MLIR/include ods/2-arguments/03_operands.td
$MLIR/bin/mlir-tblgen --gen-pass-decls -name Toy -I $MLIR/include passes/1-basics/01_pass.td
```

> The `mlir-tblgen` path is set at the top of `gen-all.sh` (Homebrew `llvm@20`
> by default) — edit it if your install differs.

## Where the generated code goes

The lessons here only *generate* C++. [`../mlir-capstone/`](../mlir-capstone/README.md)
compiles the output of every backend above (plus DRR and PDLL patterns) into a
dialect library with its own `toy-opt`, and
[`../mlir-tools/cmake/`](../mlir-tools/cmake/README.md) explains the
`mlir_tablegen()` / `add_mlir_dialect()` CMake helpers that plug these same
`-gen-*` flags into a build.

## References

- ODS — <https://mlir.llvm.org/docs/DefiningDialects/Operations/>
- DRR — <https://mlir.llvm.org/docs/DeclarativeRewrites/>
- Passes — <https://mlir.llvm.org/docs/PassManagement/> (*Declarative Pass Specification*)
- Interfaces — <https://mlir.llvm.org/docs/Interfaces/>
- Defining a dialect — <https://mlir.llvm.org/docs/DefiningDialects/>
