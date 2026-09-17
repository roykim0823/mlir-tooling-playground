# mlir-tooling-playground

Hands-on tutorials for the LLVM/MLIR developer toolchain, learned by example:
the **`lit`** + **`FileCheck`** testing stack, **LLVM TableGen** (the language
and `llvm-tblgen` backends), and **MLIR TableGen** (ODS — Operation Definition
Specification — and DRR — Declarative Rewrite Rules — driven by `mlir-tblgen`).

## Purpose

LLVM and MLIR are built on a layer of *developer tooling* that the official docs
describe well in isolation but rarely show working end-to-end. The goal of this
repo is to close that gap: each topic is taught through small, **runnable**
artifacts — a test you run with `lit`, a `.td` file you actually feed to
`llvm-tblgen`/`mlir-tblgen`, a backend you compile — with the expected output
shown right next to it.

## What's covered

### lit & FileCheck — how LLVM/MLIR tools are tested

Almost every regression test in LLVM and MLIR is a single source file that
carries *both* the command to run and the expected output, written as comments.
Two tools make that work, and [`lit-and-filecheck/`](lit-and-filecheck) covers
both:

- **`lit`** (the LLVM Integrated Tester) is the test *runner*. It discovers test
  files under a directory, reads the `// RUN:` lines embedded in each one,
  substitutes placeholders such as `%s` (the test file's path), executes the
  resulting shell pipeline, and reports PASS/FAIL. It knows nothing about
  compilers or IR; it only runs commands and checks exit codes. The tutorial
  covers `lit.cfg.py` / `lit.site.cfg.py` configuration, suite discovery,
  substitutions, `REQUIRES` / `XFAIL`, and reading lit's output when a test
  fails.
- **`FileCheck`** is the output *pattern matcher* that those `RUN` lines pipe
  into. It re-reads the test file for `// CHECK:` lines and verifies they appear,
  in order, in the text on stdin. The tutorial works through the directive
  family (`CHECK-NEXT`, `CHECK-SAME`, `CHECK-LABEL`, `CHECK-NOT`, `CHECK-DAG`,
  `CHECK-EMPTY`, `CHECK-COUNT`), regex patterns `{{...}}`, and pattern variables
  `[[NAME:...]]` / `[[NAME]]` for capturing SSA names that differ from run to
  run, plus check prefixes for sharing one file across several pipelines.
- **MLIR testing conventions** — how a real `.mlir` test drives `mlir-opt` with
  a single pass (`-cse`, `-canonicalize`, …) so failures have exactly one cause,
  how to structure `CHECK-LABEL` per function, and how to write a new test from
  scratch.

Everything runs against a small standalone CMake project in
[`example/`](lit-and-filecheck/example) using stock `mlir-opt` and `FileCheck`,
so the only prerequisite is a prebuilt LLVM/MLIR. A one-command runner
(`scripts/try.sh`) lets you execute any tutorial step directly.

### TableGen — LLVM's declarative description language

**TableGen** is the language behind most of LLVM's and MLIR's generated code.
You write *records* in `.td` files and a *backend* turns them into C++. The
language is shared, but LLVM and MLIR use it for very different jobs and ship
different tools, so the two get separate tracks.

**LLVM TableGen** ([`llvm-tablegen/`](llvm-tablegen)) — the tool is
`llvm-tblgen`. In LLVM proper, TableGen is used for *target codegen*: instruction,
register, scheduling, and intrinsic descriptions, and SelectionDAG
instruction-selection patterns. Core IR is hand-written C++. This track teaches
the language and the tool itself, independent of any target:

- **The language** (`language/`) — records, classes, template arguments, `let`,
  bang operators, `multiclass`, DAGs, and running the stock `--gen-*` backends
  of `llvm-tblgen`. This is the foundation the MLIR track builds on.
- **Backends** (`backend/`) — what happens on the other side of `--gen-*`:
  walking the `RecordKeeper` / `Record` / `Init` data model in C++, emitting
  code, reporting errors, and registering a new backend. This is how the ODS and
  DRR generators below are implemented under the hood.

**MLIR TableGen** ([`mlir-tablegen/`](mlir-tablegen)) — the tool is
`mlir-tblgen`, the same TableGen frontend with an MLIR-specific set of backends.
Where LLVM uses TableGen at the edges, MLIR uses it at the core: *every* dialect,
including the built-in ones, is defined declaratively. Two workflows dominate:

- **ODS — Operation Definition Specification** (`ods/`) — MLIR's way to
  *define* operations. You describe an op declaratively (its operands, results,
  attributes, regions, traits, verifier, assembly format, builders, enums) and
  `mlir-tblgen --gen-op-decls/-defs` emits the C++ op class: accessors,
  builders, verifier, parser and printer. ODS is the MLIR analog of LLVM's
  instruction descriptions.
- **Attributes & types** (`attrs-and-types/`) — the ODS counterpart for a
  dialect's own compile-time values (`#toy.shape<3 x 4>`) and types
  (`!toy.int<32>`): `AttrDef` / `TypeDef`, parameters, assembly format,
  builders, verification, and traits/interfaces, generated via
  `--gen-attrdef-*` / `--gen-typedef-*`.
- **DRR — Declarative Rewrite Rules** (`drr/`) — MLIR's way to *rewrite* IR.
  You write a source pattern (the IR to match) and a result pattern (the IR to
  build) as TableGen DAGs, and `mlir-tblgen --gen-rewriters` turns each into a
  C++ `RewritePattern`. DRR builds directly on ODS: the DAG operators in a
  pattern *are* the ops you defined. Covers constraints, `NativeCodeCall`
  escapes to C++, multi-result and auxiliary ops, and rewrite directives. DRR is
  the MLIR analog of LLVM's SelectionDAG ISel patterns.
- **Capstone: an out-of-tree Toy dialect** (`capstone-toy/`) — ties ODS,
  attributes/types, and DRR together into a single `.td` that nine `mlir-tblgen`
  backends turn into a real dialect library, compiled and linked against
  `libMLIR` with CMake, plus a driver that builds IR, applies the rewrite, and
  prints the result.

### Suggested order

The `lit` / `FileCheck` track is self-contained and is the quickest way to see
the toolchain in action, so it comes first. The TableGen tracks form a
progression: start by *using* TableGen (writing `.td`, running stock
`llvm-tblgen` backends), then learn to *extend* it (writing your own backend in
C++), then move to MLIR's ODS and DRR workflows, and finally tie it together in
a **buildable** out-of-tree dialect.

**Who it's for:** anyone building an out-of-tree LLVM/MLIR project (a new
dialect, a custom backend, a pass) who wants a worked reference rather than a
spec. Most lessons only need an LLVM/MLIR install (`brew install llvm@20`); the
capstone additionally links against `libMLIR`.

## Contents

- [`lit-and-filecheck/`](lit-and-filecheck) — testing LLVM/MLIR tools with `lit` and `FileCheck`: a 6-chapter tutorial, a runnable `example/` lit test suite, and a one-command `scripts/try.sh` runner.
- [`llvm-tablegen/`](llvm-tablegen) — LLVM's `llvm-tblgen`, in two parts:
  - [`language/`](llvm-tablegen/language) — the TableGen language, from first records to generating C++ from `.td` files. 16 lessons, worked solutions in `solution/01`–`15`.
  - [`backend/`](llvm-tablegen/backend) — writing your own TableGen backend in C++ (RecordKeeper, the `Init` hierarchy, emitting + errors, `--gen-*` registration) plus driving a real `--gen-searchable-tables` backend. 6 lessons (`1-entry-point/` → `6-searchable-tables/`), each a self-contained C++ backend.
- [`mlir-tablegen/`](mlir-tablegen) — MLIR's `mlir-tblgen` workflows:
  - [`ods/`](mlir-tablegen/ods) — **ODS**: defining operations (operands, results, traits, assembly format, builders, enums). 12 lessons in 6 groups (`1-dialect-and-ops/` → `6-enums/`).
  - [`attrs-and-types/`](mlir-tablegen/attrs-and-types) — defining custom attributes & types (`AttrDef` / `TypeDef`). 10 lessons in 5 groups.
  - [`drr/`](mlir-tablegen/drr) — **DRR**: declarative rewrite rules (source→result patterns, `NativeCodeCall`, directives). 5 lessons (`1-basics/` → `5-directives/`).
  - [`capstone-toy/`](mlir-tablegen/capstone-toy) — a complete, buildable out-of-tree Toy dialect linking everything above against `libMLIR` through nine `mlir-tblgen` backends.
