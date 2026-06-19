# mlir-tooling-playground

Hands-on tutorials for the LLVM/MLIR developer toolchain — TableGen, lit, FileCheck, and the rest of the out-of-tree scaffolding, learned by example.

## Purpose

LLVM and MLIR are built on a layer of *developer tooling* that the official docs
describe well in isolation but rarely show working end-to-end. The goal of this
repo is to close that gap: each topic is taught through small, **runnable**
artifacts — a `.td` file you actually feed to `llvm-tblgen`/`mlir-tblgen`, a
backend you compile, a test you run with `lit` — with the expected output shown
right next to it.

It's organized as a progression. You start by *using* TableGen (writing `.td`,
running stock `--gen-*` backends), then learn to *extend* it (writing your own
backend in C++), then move to MLIR's two big TableGen workflows (defining ops /
attrs / types with ODS, rewriting IR with DRR), and finally tie it together in a
**buildable** out-of-tree dialect. A separate track covers testing those tools
with `lit` and `FileCheck`.

**Who it's for:** anyone building an out-of-tree LLVM/MLIR project (a new
dialect, a custom backend, a pass) who wants a worked reference rather than a
spec. Most lessons only need an LLVM/MLIR install (`brew install llvm@20`); the
capstone additionally links against `libMLIR`.

## Contents

- [`llvm-tablegen/`](llvm-tablegen) — LLVM's `llvm-tblgen`, in two parts:
  - [`language/`](llvm-tablegen/language) — the TableGen language, from first records to generating C++ from `.td` files.
  - [`backend/`](llvm-tablegen/backend) — writing your own TableGen backend in C++ (RecordKeeper, the `Init` hierarchy, emitting + errors, `--gen-*` registration) plus driving a real `--gen-searchable-tables` backend.
- [`mlir-tablegen/`](mlir-tablegen) — MLIR's `mlir-tblgen` workflows:
  - [`ods/`](mlir-tablegen/ods) — **ODS**: defining operations (operands, results, traits, assembly format, builders, enums).
  - [`attrs-and-types/`](mlir-tablegen/attrs-and-types) — defining custom attributes & types (`AttrDef` / `TypeDef`).
  - [`drr/`](mlir-tablegen/drr) — **DRR**: declarative rewrite rules (source→result patterns, `NativeCodeCall`, directives).
  - [`capstone-toy/`](mlir-tablegen/capstone-toy) — a complete, buildable out-of-tree Toy dialect linking everything above against `libMLIR`.
- [`lit-and-filecheck/`](lit-and-filecheck) — testing LLVM/MLIR tools with `lit` and `FileCheck`, plus a runnable example test suite.

## Progress so far

- ✅ **`llvm-tablegen/language/`** — 16 lessons across `1-basics/` → `4-codegen/`.
- ✅ **`llvm-tablegen/backend/`** — 5 lessons, each a self-contained C++ backend (`1-entry-point/` → `5-registration/`).
- ✅ **`mlir-tablegen/ods/`** — operation definition, 6 lesson groups (`1-dialect-and-ops/` → `6-enums/`).
- ✅ **`mlir-tablegen/attrs-and-types/`** — custom attrs & types, 10 lessons across 5 groups.
- ✅ **`mlir-tablegen/drr/`** — declarative rewrite rules, 5 lessons (`1-basics/` → `5-directives/`).
- ✅ **`mlir-tablegen/capstone-toy/`** — buildable Toy dialect wiring ODS + DRR through nine `mlir-tblgen` backends.
- ✅ **`lit-and-filecheck/`** — 6 lessons plus a runnable `example/` lit test suite and `scripts/` runners.
