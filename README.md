# mlir-tooling-playground

Hands-on tutorials for the developer tooling around LLVM and MLIR: TableGen
and its backends, the two pattern languages, passes and interfaces, `lit` and
`FileCheck`, and the tools you meet once you have a dialect of your own
(`*-opt`, plugins, reducers, translators, language servers, CMake). Every
topic is taught from small artifacts you can run, with the expected output
next to the command, and everything meets in one buildable out-of-tree
dialect.

The official docs describe each of these pieces well in isolation. What they
rarely show is the pieces working together, end to end, on something small
enough to read in one sitting. That is the gap this repository fills.

**Who it is for:** anyone building an out-of-tree LLVM/MLIR project who wants
a worked reference rather than a specification. Familiarity with C++ and the
idea of a compiler IR is assumed; MLIR itself is not.

## The six tracks

Each track is a directory with a README that stands on its own, a runner that
replays every example in it, and a size of roughly a day's study. Read them in
this order; each says at the top what it assumes from the ones before.

| # | Track | What you learn | Runner |
|---|---|---|---|
| 1 | [`lit-and-filecheck/`](lit-and-filecheck) | how every LLVM/MLIR test works: `RUN:` lines, `CHECK:` directives, diagnostics tests, `split-file`, custom substitutions, the checks generator. 7 tutorials on a standalone lit project. | `scripts/try.sh` |
| 2 | [`llvm-tablegen/`](llvm-tablegen) | the TableGen language with `llvm-tblgen` (16 lessons), then writing a TableGen backend in C++ (6 lessons). | `language/gen-all.sh`, `backend/run-all.sh` |
| 3 | [`mlir-tablegen/`](mlir-tablegen) | MLIR's TableGen workflows: ODS for ops (12 lessons), attributes and types (10), pass declarations (3), your own interfaces (3), the documentation backends (1). | `gen-all.sh` |
| 4 | [`mlir-patterns/`](mlir-patterns) | rewriting IR declaratively: DRR in TableGen (5 lessons) and the same rewrites in PDLL (5 lessons), with a comparison of both against hand-written C++. | `gen-all.sh` |
| 5 | [`mlir-capstone/`](mlir-capstone) | everything above compiled into one out-of-tree dialect: a library, `toy-opt`, a plugin for the stock `mlir-opt`, `toy-reduce`, `toy-translate`, `toy-lsp-server`, generated docs, and a lit suite of 8 tests. | `cmake --build build --target check-toy` |
| 6 | [`mlir-tools/`](mlir-tools) | the tools around a dialect, stock and then your own: debugging flags, test-case reduction, translation, language servers, and the CMake that holds a project together (with a copyable skeleton). | one `try.sh` per topic |

Tracks 1 and 2 need only a prebuilt LLVM/MLIR. Track 5 needs the MLIR
development libraries and CMake. Track 6 refers back to the capstone for the
"your own dialect" half of each topic, so build track 5 before it; its
`debugging/` topic is the exception and can be read right after track 1.

## How the tracks fit together

**Testing first.** `lit` finds test files and runs the shell commands written
inside them; `FileCheck` checks a tool's output against `CHECK:` lines in the
same file. Every later track ends in a lit test, so this comes first.

**TableGen, LLVM side.** TableGen is the declarative language behind most
generated code in LLVM and MLIR: records in `.td` files, a backend that turns
them into C++. `llvm-tablegen/` teaches the language and then the other side,
writing a backend, which is how the MLIR generators are implemented.

**TableGen, MLIR side.** MLIR uses TableGen for its core, not its edges: every
dialect is defined this way. `mlir-tablegen/` covers defining ops, attributes
and types, declaring passes, defining interfaces, and generating docs, each as
a standalone `.td` file with the generated C++ explained.

**Rewriting.** `mlir-patterns/` teaches DRR and PDLL as twins, lesson for
lesson, so the two pattern languages can be read side by side.

**The capstone.** `mlir-capstone/` is the destination: a complete out-of-tree
dialect with ops, a type, an attribute, two interfaces, patterns in DRR, PDLL
and C++, a pass, and five tools built from MLIR's `*Main` libraries. Every
other track points at the place in it where its topic is put to work.

**The tools.** `mlir-tools/` covers what you reach for once the dialect
exists. Each topic shows the stock tool on stock IR, then the capstone's own
version of it, and ends in a lit test in the capstone.

## Prerequisites and conventions

- **LLVM/MLIR 20.** Everything was written and verified against Homebrew's
  `llvm@20` on macOS (`brew install llvm@20`); paths in the docs use
  `/opt/homebrew/opt/llvm@20`. Any LLVM 20 install with CMake files works;
  set `MLIR_DIR` or `LLVM_BIN` where a script asks for it.
- **A `lit` runner.** Installed LLVMs ship no `llvm-lit`; `pip install lit`
  provides one, and the CMake files find it on `PATH`.
- **Release builds.** Homebrew's LLVM has assertions off. Two features are
  compiled out and the docs say so where it matters: `-debug-only` and pass
  statistics.
- **Shell.** The command lines are plain POSIX shell and were run under both
  bash and zsh. Scripts are bash.
- **Generated output** (`generated/`, `build/`) is git-ignored; regenerate it
  with the track's runner.
- **Editor.** `.vscode/settings.json` wires the three MLIR language servers to
  this repo and the capstone build; see `mlir-tools/lsp/`.

## Repository map

```
lit-and-filecheck/      tutorial, example/ (standalone lit project), scripts/try.sh
llvm-tablegen/
  language/             16 lessons + solutions, gen-all.sh
  backend/              6 C++ backends, run-all.sh
mlir-tablegen/          gen-all.sh runs every lesson below
  ods/                  12 lessons        attrs-and-types/   10 lessons
  passes/                3 lessons        interfaces/         3 lessons
  docs/                  1 lesson
mlir-patterns/          gen-all.sh
  drr/                   5 lessons        pdll/               5 lessons
mlir-capstone/          the buildable dialect: include/ lib/ tools/ test/
mlir-tools/
  debugging/            examples/, try.sh
  reduce/               examples/, try.sh
  translate/            examples/, try.sh
  lsp/                  sessions/, make-session.py, summarize.py, try.sh
  cmake/                skeleton/ (copyable project), try.sh
.vscode/settings.json   language servers wired for this repo
```
