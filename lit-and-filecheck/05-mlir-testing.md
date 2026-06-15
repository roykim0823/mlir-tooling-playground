# Chapter 5 — MLIR testing conventions

> Source: <https://mlir.llvm.org/getting_started/TestingGuide/> and
> <https://llvm.org/docs/TestingGuide.html>

lit + FileCheck are generic. This chapter covers how **MLIR** uses them, plus
two MLIR-specific test styles. The runnable examples are in the `example/`
project.

MLIR tests fall into four categories:

1. **Check tests** — transform IR with `mlir-opt`, FileCheck the result.
2. **Diagnostic tests** — assert the compiler emits a specific error/warning/remark.
3. **Integration / runner tests** — actually *execute* lowered code and check what it prints.
4. **C++ unit tests** — googletest in `unittests/` (not covered here).

## 5.1 Check tests — the standard form

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

The MLIR conventions to internalize (all from Chapters 3–4, applied):

- **`CHECK-LABEL: func.func @name`** at every function — isolates blocks and
  gives clean failure locations.
- **Capture SSA values** with `%[[NAME:.*]]` on definition, reuse with
  `%[[NAME]]` — never hardcode `%0`, `%1`. The compiler is free to renumber.
- **`CHECK-SAME:`** to spread a long signature across readable lines.
- Run a **minimal pipeline** (`-cse`, `-canonicalize`), not `-O3` — the test
  should isolate one transformation.
- Put `CHECK` lines **next to the code they describe** for readability (the
  matcher doesn't care where comments sit; humans do).

In a real out-of-tree project you'd swap `mlir-opt` for your own driver (say
`my-opt`) that registers your custom passes — the RUN/CHECK mechanics are
identical. See `example/README.md` → "Turning this into a real project".

## 5.2 Diagnostic tests — `-verify-diagnostics`

These check that *invalid* input produces the *right* error, instead of checking
transformed output. You pass `-verify-diagnostics` to `mlir-opt`, and annotate
the IR with `expected-*` directives. The run **passes** when the emitted
diagnostics exactly match the expectations. This is `example/test/invalid.mlir`:

```mlir
// RUN: mlir-opt %s -split-input-file -verify-diagnostics

func.func @bad_branch() {
  // expected-error @+1 {{reference to an undefined block}}
  cf.br ^missing
}

// -----

func.func @bad_return() -> i32 {
  %0 = arith.constant 1 : i64
  // expected-error @+1 {{doesn't match function result type ('i32')}}
  return %0 : i64
}
```

Key pieces:

| Construct | Meaning |
|-----------|---------|
| `-verify-diagnostics` | Turn on diagnostic verification mode |
| `expected-error {{msg}}` | Expect an error whose message **contains** `msg` (substring) on **this** line |
| `expected-warning {{...}}` | Same, for warnings |
| `expected-remark {{...}}` | Same, for remarks |
| `expected-error @+1 {{...}}` | The diagnostic is on the line **1 below** the comment |
| `expected-error @-2 {{...}}` | …**2 above** |
| `expected-error @above` / `@below` | Relative without a count |
| `-split-input-file` + the five-dash separator | Split the file into independent sub-tests, isolating failures |

The `{{...}}` here is FileCheck-style regex *inside the expected message*, and
matching is substring — you don't need the whole error text, just a stable
fragment.

> **Gotcha (learned while building this tutorial):** `-split-input-file` splits
> on **any** line matching the five-dash separator — including one buried inside
> a prose `//` comment. Keep that separator out of explanatory comments or you'll
> create a bogus extra sub-test. (This is why `invalid.mlir` spells out
> "five-dash separator" in words instead of showing it.)

### An alternative: capture stderr + FileCheck it

`-verify-diagnostics` is the standard, but you can also just run the tool,
redirect stderr to a temp file, and FileCheck *that*:

```mlir
// RUN: mlir-opt %s 2>%t; FileCheck %s < %t
// CHECK: reference to an undefined block
```

| | `-verify-diagnostics` | stderr-capture + FileCheck |
|---|---|---|
| Annotation | `expected-error {{...}}` next to the offending line | `// CHECK:` anywhere |
| Pinpoints the line | Yes (`@+1`, etc.) | No |
| Multiple errors / split-file | First-class | Manual |
| Setup | Needs the flag | Just shell redirection |

Prefer `-verify-diagnostics` for new MLIR tests; recognize the stderr-capture
form when you meet it.

## 5.3 Integration / runner tests — execute and check output

The strongest correctness signal: lower the IR all the way to something
executable, **run it**, and FileCheck the program's printed output. MLIR uses
`mlir-runner` to JIT-execute, or lowers to LLVM IR and uses `llc`/`clang`.

Typical shape:

```mlir
// RUN: mlir-opt %s --some-lowering-pipeline \
// RUN:   | mlir-runner -e main --entry-point-result=void \
// RUN:       --shared-libs=%mlir_runner_utils \
// RUN:   | FileCheck %s

func.func @main() {
  // ... compute something, print it ...
  // CHECK: 42
  return
}
```

Now `// CHECK: 42` is checking the **runtime stdout**, not IR. Real examples in
upstream MLIR live under `mlir/test/Integration/` and use multiple
`--check-prefix`es so several runs share one file. Integration tests are more
expensive (they build and execute), so they're reserved for cases where checking
IR alone wouldn't prove correctness — e.g. validating an entire lowering
pipeline end-to-end.

## 5.4 How the build wires it up

A CMake-based MLIR project exposes a `check` target that builds the tools then
runs lit. In the `example/` project that's:

```bash
cd example && ./run.sh                       # cmake configure + build + check
# under the hood: cmake --build build --target check  ->  llvm-lit build/test
```

Single file, no rebuild needed if only the `.mlir` changed:

```bash
llvm-lit -v example/build/test --filter='invalid\.mlir'
```

Both paths ultimately invoke `llvm-lit`, which reads each `.mlir`'s RUN lines and
shells out to `mlir-opt` / `mlir-runner` piped into `FileCheck` — exactly the
machinery from Chapters 1–4.

## Try it

> Shortcut: `scripts/try-05.sh` runs everything below automatically.

With the tools on your `PATH` (see [setup](README.md#setup-do-this-once)), from
`tutorials/lit-and-filecheck/`:

```bash
cd example && ./run.sh          # builds + runs all three categories at once

export PATH="$PWD/../../../externals/llvm-project/build/bin:$PATH"

# A check test:
llvm-lit -v build/test --filter='canonicalize\.mlir'

# A diagnostic test (note -verify-diagnostics in its RUN line):
grep -nE 'RUN:|expected-' test/invalid.mlir
llvm-lit -v build/test --filter='invalid\.mlir'
```

➡️ Next: [Chapter 6 — hands-on](06-hands-on.md)
