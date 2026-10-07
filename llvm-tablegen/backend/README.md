# TableGen backends

A backend is whatever reads the records that the TableGen front end built
and produces output. LLVM's
[TableGen Overview](https://releases.llvm.org/20.1.0/docs/TableGen/index.html)
says you will most likely have to write one, and names two ways: extend
TableGen in C++, or write a script that reads the JSON that `--dump-json`
prints. The three directories take them in order of effort:

| Directory | What you do | Follows |
|---|---|---|
| [`stock/`](stock) | **use** the backends `llvm-tblgen` ships: the general ones, `--gen-searchable-tables`, a minimal target that the real `--gen-*` backends accept, LLVM's own `.td` files, and X86 | [BackEnds](https://releases.llvm.org/20.1.0/docs/TableGen/BackEnds.html) |
| [`json/`](json) | **write** a backend as a Python script over `--dump-json`, and compile C++ against its output | the overview's "script in any language" |
| [`writing/`](writing) | **write** backends in C++ against LLVM's TableGen library: the `RecordKeeper`/`Record`/`Init` model, errors, registration, debugging | [Backend Developer's Guide](https://releases.llvm.org/20.1.0/docs/TableGen/BackGuide.html) |

Each example is a lit test, like the rest of the track. `../check.sh` builds
the CMake projects here (`stock/` and `json/` have small C++ consumers;
`writing/` is all C++) and runs everything.

## Where this fits

- [`../language/`](../language) is the language these backends consume.
  Its capstone lessons 16 and 17 come back here: `json/` compiles them into
  C++, and `stock/03_mini_target.td` rewrites lesson 16 so that the real
  target backends accept it.
- [`../../mlir-tablegen/`](../../mlir-tablegen): `mlir-tblgen` is this same
  front end with MLIR's backends (`--gen-op-defs`, `--gen-rewriters`, …).
  `writing/` shows what one of those looks like inside.
