# lit & FileCheck — a step-by-step tutorial

A hands-on introduction to the two tools that drive almost every LLVM/MLIR
regression test: **`lit`** (the test *runner*) and **`FileCheck`** (the output
*pattern matcher*).

This tutorial is **self-contained**: it does not depend on any custom pass or
build system. Every runnable example uses the stock `mlir-opt` and a small
**standalone CMake project** in [`example/`](example/) that you can build and run
with a single command. The only prerequisite is a prebuilt LLVM/MLIR.

## The one-sentence mental model

> **`lit` finds test files and runs the shell commands written inside them;
> `FileCheck` reads `// CHECK:` patterns from a file and verifies they appear,
> in order, in some text you pipe to it.**

A typical MLIR test is just a `.mlir` file that contains both the command to run
*and* the expected output, as comments:

```mlir
// RUN: mlir-opt %s -cse | FileCheck %s

// CHECK-LABEL: func.func @simple_constant
func.func @simple_constant() -> (i32, i32) {
  // CHECK-NEXT: %[[RESULT:.*]] = arith.constant 1
  // CHECK-NEXT: return %[[RESULT]], %[[RESULT]]
  %0 = arith.constant 1 : i32
  %1 = arith.constant 1 : i32
  return %0, %1 : i32, i32
}
```

- `lit` sees the `// RUN:` line, substitutes `%s` with this file's path, and
  runs `mlir-opt -cse | FileCheck ...`.
- `FileCheck` re-reads this same file for `// CHECK:` lines and checks them
  against the piped-in transformed IR.
- Exit code 0 → `lit` reports **PASS**.

## Fastest way to see it work

```bash
cd example
./run.sh
```

That configures a standalone CMake project, builds a `check` target, and runs
three lit tests through FileCheck — printing `Passed: 3 (100.00%)`. See
[`example/README.md`](example/README.md) for the full walkthrough. Come back to
the chapters below to understand *why* each piece works.

### Run the chapter examples without typing

Every chapter's **Try it** commands are scripted under [`scripts/`](scripts/).
Each script echoes the command before running it, so the output reads like a
transcript:

```bash
scripts/try-01.sh        # just Chapter 1's commands
scripts/run-all.sh       # every chapter, in order
```

They auto-build the example and auto-detect the bundled LLVM (override with
`LLVM_BIN=/path/to/llvm-build/bin scripts/run-all.sh`). The mutating labs in
Chapter 6 back up and restore the files they touch, so the scripts are safe to
re-run.

## How to read this tutorial

Work through the chapters in order; each ends with a **Try it** you can run
against the `example/` project.

| # | Chapter | What you'll learn |
|---|---------|-------------------|
| 1 | [`01-lit-basics.md`](01-lit-basics.md) | What lit is, how to invoke it, how it discovers tests (`lit.cfg.py` + `lit.site.cfg.py.in`), RUN lines, substitutions, result codes |
| 2 | [`02-filecheck-basics.md`](02-filecheck-basics.md) | What FileCheck is, invocation, the plain `CHECK:` directive, whitespace rules |
| 3 | [`03-filecheck-directives.md`](03-filecheck-directives.md) | `CHECK-NEXT`, `-SAME`, `-NOT`, `-DAG`, `-COUNT-n`, `-LABEL`, `-EMPTY` |
| 4 | [`04-filecheck-variables.md`](04-filecheck-variables.md) | Regex `{{...}}`, string variables `[[VAR:...]]`, numeric variables `[[#...]]`, `@LINE` |
| 5 | [`05-mlir-testing.md`](05-mlir-testing.md) | MLIR conventions: SSA capture, diagnostic tests (`-verify-diagnostics`), runner/execution tests |
| 6 | [`06-hands-on.md`](06-hands-on.md) | Build, break, and extend the `example/` project end-to-end |

## Setup (do this once)

You need a prebuilt LLVM/MLIR that provides `mlir-opt`, `FileCheck`, and
`llvm-lit`. To run the standalone example, that's all — `example/run.sh` finds
the tools for you.

To run the **Try it** shell snippets in the chapters directly, also put the tool
directory on your `PATH`. From this tutorial directory:

```bash
# Adjust the path to wherever your LLVM build's bin/ is.
# (This repo ships one under externals/llvm-project/build.)
export PATH="$PWD/../../externals/llvm-project/build/bin:$PATH"

# sanity check — all three should resolve:
which mlir-opt FileCheck llvm-lit
```

## References (the primary sources this tutorial is built from)

- **lit** — <https://llvm.org/docs/CommandGuide/lit.html>
- **FileCheck** — <https://llvm.org/docs/CommandGuide/FileCheck.html>
- **LLVM Testing Guide** — <https://llvm.org/docs/TestingGuide.html>
- **MLIR Testing Guide** — <https://mlir.llvm.org/getting_started/TestingGuide/>
