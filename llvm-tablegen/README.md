# LLVM TableGen

LLVM's **TableGen** has two sides, and this directory covers both — one per
subfolder:

| Directory | What it teaches |
|---|---|
| [`language/`](language) | The TableGen **language** and how to *use* `llvm-tblgen`: records, classes, template args, `let`, bang operators, `multiclass`, DAGs, … and turning records into C++. |
| [`backend/`](backend) | Writing your own TableGen **backend** in C++: the `RecordKeeper`/`Record`/`Init` data model, finding records, emitting output, error reporting, `--gen-*` registration, and driving a real stock backend (`--gen-searchable-tables`) end to end. |

Read [`language/`](language/README.md) first (you need to understand `.td`
files and what a backend consumes), then [`backend/`](backend/README.md) to see
how the code-generation side is written.

> The split mirrors a real distinction: most LLVM developers *use* TableGen
> (write `.td`, run the built-in `--gen-*` backends), while a smaller number
> *extend* it by writing new backends. `language/` is the former; `backend/` the
> latter.

## Relationship to the rest of the repo

- [`../mlir-tablegen/`](../mlir-tablegen) — MLIR's `mlir-tblgen` is the same tool
  with a different set of backends (ODS, DRR, attributes/types). Its lessons are
  the MLIR analog of what `language/` teaches here; `backend/` shows what writing
  one of those `--gen-*` backends looks like underneath.

## Prerequisites

An LLVM install with `llvm-tblgen` and (for `backend/`) the development
libraries/headers — e.g. `brew install llvm@20`. Each subfolder's README has its
own build/run instructions.
