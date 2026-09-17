# mlir-tooling-playground

Hands-on tutorials for the developer tooling around LLVM and MLIR: TableGen
and its backends, the pattern languages, passes and interfaces, `lit` and
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

## Start here

Read the tracks in this order. Each one stands on the previous ones and says
so at the top; each has a one-command runner (`try.sh` or `gen-all.sh`) that
replays every example in its README.

| Step | Track | You learn | Needs |
|---|---|---|---|
| 1 | [`lit-and-filecheck/`](lit-and-filecheck) | how every LLVM/MLIR test works: `RUN:` lines, `CHECK:` directives, diagnostics tests, `split-file`, custom substitutions | stock `mlir-opt` |
| 2 | [`llvm-tablegen/language/`](llvm-tablegen/language) | the TableGen language: records, classes, `let`, bang operators, `multiclass`, DAGs | `llvm-tblgen` |
| 3 | [`llvm-tablegen/backend/`](llvm-tablegen/backend) | writing a TableGen backend in C++: `RecordKeeper`, `Init`, emitting, `--gen-*` registration | LLVM dev libraries |
| 4 | [`mlir-tablegen/ods/`](mlir-tablegen/ods), [`attrs-and-types/`](mlir-tablegen/attrs-and-types) | defining ops, attributes and types with ODS | `mlir-tblgen` |
| 5 | [`mlir-tablegen/drr/`](mlir-tablegen/drr), then [`mlir-pdll/`](mlir-pdll) | rewriting IR: TableGen DRR, then the same rewrites in PDLL, and when to use which | `mlir-tblgen`, `mlir-pdll` |
| 6 | [`mlir-tablegen/passes/`](mlir-tablegen/passes), [`interfaces/`](mlir-tablegen/interfaces), [`docs/`](mlir-tablegen/docs) | declaring passes, defining your own interfaces, generating reference docs | `mlir-tblgen` |
| 7 | [`mlir-tablegen/capstone-toy/`](mlir-tablegen/capstone-toy) | all of the above compiled into one dialect library with `toy-opt`, a plugin for stock `mlir-opt`, and a lit suite | `libMLIR`, CMake |
| 8 | [`mlir-debugging/`](mlir-debugging) | the flags that show what a pass pipeline is doing, and what needs an assertions build | stock `mlir-opt` |
| 9 | [`mlir-reduce/`](mlir-reduce) | shrinking a failing input with `mlir-reduce` and `llvm-reduce` | stock tools, capstone for `toy-reduce` |
| 10 | [`mlir-translate/`](mlir-translate) | importing and exporting non-MLIR formats; `toy-translate` | stock tool, capstone |
| 11 | [`mlir-lsp/`](mlir-lsp) | the three language servers, driven by hand and wired into an editor; `toy-lsp-server` | stock servers, capstone |
| 12 | [`mlir-cmake/`](mlir-cmake) | what the CMake helpers expand to; a copyable skeleton project; the upstream template | CMake |

Steps 1 and 8 need nothing but a prebuilt LLVM/MLIR and can be read on their
own. Steps 9 to 12 refer back to the capstone for the "your own dialect"
half of each topic, so build it (step 7) before them.

## The tracks in one paragraph each

**Testing.** `lit` finds test files and runs the shell commands written inside
them; `FileCheck` checks a tool's output against `CHECK:` lines in the same
file. The [`lit-and-filecheck/`](lit-and-filecheck) tutorial builds up every
directive on a standalone CMake project that tests stock `mlir-opt`, then adds
diagnostics tests, multi-input files, custom substitutions and the checks
generator. The capstone reuses the exact wiring for its own tools.

**TableGen, LLVM side.** TableGen is the declarative language behind most
generated code in LLVM and MLIR: records in `.td` files, a backend that turns
them into C++. [`llvm-tablegen/`](llvm-tablegen) teaches the language with
`llvm-tblgen` and then the other side, writing a backend, which is how the
MLIR generators below are implemented.

**TableGen, MLIR side.** MLIR uses TableGen for its core, not its edges:
every dialect is defined this way. [`mlir-tablegen/`](mlir-tablegen) covers
ODS for ops, attributes and types; DRR for rewrite patterns; pass
declarations; interfaces; and the documentation backends. Each lesson is a
standalone `.td` file you feed to `mlir-tblgen`, with the generated C++
explained.

**Patterns beyond TableGen.** [`mlir-pdll/`](mlir-pdll) is PDLL, MLIR's own
pattern language, taught as a twin of the DRR lessons so the two can be read
side by side. It compiles to PDL, a dialect of IR that describes patterns.

**The capstone.** [`mlir-tablegen/capstone-toy/`](mlir-tablegen/capstone-toy)
is a complete out-of-tree dialect: ops, a type, an attribute, two interfaces,
patterns in DRR, PDLL and C++, a pass, and five tools built from MLIR's
`*Main` libraries (`toy-opt`, `toy-reduce`, `toy-translate`,
`toy-lsp-server`, a driver). A plugin loads the same dialect and pass into the
stock `mlir-opt`. Its lit suite drives all of them.

**Tooling around a dialect.** Four short tracks cover what you reach for once
the dialect exists: [`mlir-debugging/`](mlir-debugging) for looking inside a
run, [`mlir-reduce/`](mlir-reduce) for shrinking a failing input,
[`mlir-translate/`](mlir-translate) for getting IR in and out of other
formats, and [`mlir-lsp/`](mlir-lsp) for editor support. Each shows the stock
tool first and then the capstone's own version of it.

**Build system.** [`mlir-cmake/`](mlir-cmake) explains the CMake helpers all
of this rests on, from their source, and ships a minimal project in the
upstream layout that you can copy.

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
  with the track's `gen-all.sh` or the capstone's CMake build.

## Repository map

```
lit-and-filecheck/      tutorial, example/ (standalone lit project), scripts/try.sh
llvm-tablegen/
  language/             16 lessons + solutions, gen-all.sh
  backend/              6 C++ backends, run-all.sh
mlir-tablegen/          gen-all.sh runs every lesson below
  ods/                  12 lessons        attrs-and-types/   10 lessons
  drr/                   5 lessons        passes/             3 lessons
  interfaces/            3 lessons        docs/               1 lesson
  capstone-toy/         the buildable dialect: include/ lib/ tools/ test/
mlir-pdll/              5 lessons mirroring drr/, gen-all.sh
mlir-debugging/         examples/, try.sh
mlir-reduce/            examples/, try.sh
mlir-translate/         examples/, try.sh
mlir-lsp/               sessions/, make-session.py, summarize.py, try.sh
mlir-cmake/             skeleton/ (copyable project), try.sh
.vscode/settings.json   language servers wired for this repo
```
