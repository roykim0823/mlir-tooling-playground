# The tools around a dialect

Defining and building a dialect is half the work. This track is the other
half: the tools you reach for once the dialect exists, each shown on the stock
`mlir-opt` first and then on the capstone's own version of it.

| Directory | Topic | Stock tool | Capstone tool |
|---|---|---|---|
| [`debugging/`](debugging) | seeing what a pass pipeline does: IR dumps, printing modes, reproducers, timing, diagnostics; what needs an assertions build | `mlir-opt` flags, `llvm-tblgen` record dumps | `toy-opt` (same flags) |
| [`reduce/`](reduce) | shrinking a failing input to the smallest one that still shows the symptom | `mlir-reduce`, `llvm-reduce` | `toy-reduce` |
| [`translate/`](translate) | getting IR in and out of non-MLIR formats | `mlir-translate` | `toy-translate` |
| [`lsp/`](lsp) | editor support: diagnostics, hover, go-to-definition for `.mlir`, `.td`, `.pdll` | `mlir-lsp-server`, `tblgen-lsp-server`, `mlir-pdll-lsp-server` | `toy-lsp-server` |
| [`cmake/`](cmake) | the build system all of it rests on: the `add_mlir_*` helpers, a copyable skeleton project, the upstream template | | |

Read them in that order, or pick what you need; they do not depend on each
other. Every one has a `try.sh` that replays its README, and the four
tool tracks skip their capstone sections with a hint until
[`../mlir-capstone/`](../mlir-capstone/README.md) is built. `debugging/` needs
nothing but a stock `mlir-opt` and can be read right after the lit track.

A theme runs through the four tool tracks: MLIR ships each tool as a library
with a `main()` you can write yourself (`MlirOptMain`, `MlirReduceMain`,
`mlirTranslateMain`, `MlirLspServerMain`). Registering your dialect with one of
them is a dozen lines, and the capstone does it four times. The plugin route,
loading your dialect into the *stock* tool instead, is covered in the
capstone's README; in LLVM 20 only `mlir-opt` supports it.
