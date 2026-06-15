# Chapter 2 — FileCheck basics

> Source: <https://llvm.org/docs/CommandGuide/FileCheck.html>

## 2.1 What is FileCheck?

> "FileCheck reads two files (one from standard input, and one specified on the
> command line) and uses one to verify the other."

- The **check file** (named on the command line) contains the expected
  patterns, written as `CHECK:` directives.
- The **input** (from stdin, or `--input-file`) is the text to verify — usually
  the output of a compiler tool.

FileCheck exits **0** if every directive matches in order, non-zero otherwise,
printing a diagnostic that shows *which* directive failed and *where*.

### Why not just `grep` or `diff`?

- `diff` is too strict: it breaks on any whitespace change, renamed SSA values
  (`%0` vs `%c1_i32`), or reordered-but-equivalent output.
- `grep` is too weak: it can't express "this line, then the *next* line", "these
  in any order", "this must *not* appear here", or "capture this value and
  reuse it later".

FileCheck sits in the sweet spot: ordered, regex-capable, whitespace-tolerant,
with variables.

## 2.2 Invocation

```
FileCheck match-file [options] < input
```

In an MLIR RUN line, `match-file` is almost always `%s` (the test file itself),
because the same file holds both the IR and the `CHECK:` lines:

```mlir
// RUN: mlir-opt %s -cse | FileCheck %s
```

Standalone, for experimenting (using the example project's `cse.mlir`):

```bash
mlir-opt example/test/cse.mlir -cse | FileCheck example/test/cse.mlir
# no output + exit 0 == success
```

Key options (more in later chapters):

| Option | Meaning |
|--------|---------|
| `--check-prefix PREFIX` | Use `PREFIX:` instead of `CHECK:` |
| `--check-prefixes A,B` | Multiple prefixes from one file (test several configs) |
| `--input-file FILE` | Read input from a file instead of stdin |
| `--match-full-lines` | A match must span the whole line, not a substring |
| `--strict-whitespace` | Don't canonicalize whitespace (see 2.4) |
| `--implicit-check-not PAT` | Add an implicit `CHECK-NOT: PAT` between every directive |
| `-DVAR=VALUE` | Predefine a pattern variable from the command line |
| `--dump-input=fail` | On failure, print the annotated input (excellent for debugging) |
| `--comment-prefixes` | Prefixes that *disable* a line (default `COM:`, `RUN:`) |

## 2.3 The `CHECK:` directive

The workhorse. `CHECK: <pattern>` succeeds if `<pattern>` appears **somewhere on
some line at or after** the current match position.

```mlir
// CHECK: arith.constant
```

Crucially, `CHECK:` directives are **ordered but not adjacent**. Given:

```
// CHECK: alpha
// CHECK: gamma
```

the input must contain `alpha`, and then `gamma` on the same or a *later* line.
Anything (including a `beta` line) is allowed in between. To forbid gaps, use
`CHECK-NEXT` (Chapter 3).

A directive's pattern is **substring** by default — `CHECK: constant` matches a
line containing `arith.constant 1 : i32`. Use `--match-full-lines` if you need
exact whole-line matches.

## 2.4 Whitespace handling

By default FileCheck **canonicalizes horizontal whitespace**: any run of spaces
or tabs in the pattern matches any run of spaces/tabs in the input. This is what
lets you indent `CHECK:` lines for readability without breaking matches.

Two knobs change this:

- `--strict-whitespace` — whitespace must match exactly (useful when testing a
  pretty-printer's exact formatting).
- `CHECK-EMPTY:` — the only way to assert a truly blank line (see Chapter 3),
  because a normal `CHECK:` with an empty pattern would match anything.

## 2.5 Comments inside check files

To write a comment that FileCheck ignores, use the comment prefix `COM:`:

```mlir
// COM: the next check verifies CSE collapsed the duplicate constant
// CHECK: arith.constant
```

Also, by default `RUN:` is treated as a comment prefix too — so FileCheck won't
try to interpret your RUN lines as checks.

## 2.6 Multiple prefixes — testing several configurations

You can drive several pipelines from one file by giving each its own prefix.
This is exactly what `example/test/ctlz`-style tests in upstream MLIR do; the
shape is:

```mlir
// RUN: mlir-opt %s -pass-a | FileCheck %s --check-prefix=A
// RUN: mlir-opt %s -pass-b | FileCheck %s --check-prefix=B

// A: result_from_a
// B: result_from_b
// CHECK: common_to_both   ; (CHECK is always active unless you override prefixes)
```

`--check-prefixes=CHECK,A` activates both at once.

## Try it

> Shortcut: `scripts/try-02.sh` runs everything below automatically.

With the tools on your `PATH` (see [setup](README.md#setup-do-this-once)), from
`tutorials/lit-and-filecheck/`:

```bash
# See the raw transformed IR first (what FileCheck will receive):
mlir-opt example/test/cse.mlir -cse

# Now verify it. Silence + exit 0 == pass:
mlir-opt example/test/cse.mlir -cse | FileCheck example/test/cse.mlir
echo "exit code: $?"

# Make it FAIL on purpose to see the diagnostic:
mlir-opt example/test/cse.mlir -cse | FileCheck <(echo "// CHECK: arith.muli")
```

The last command demands a `muli` that CSE never produces — read the error:
FileCheck names the directive, the expected string, and shows the input it
scanned.

➡️ Next: [Chapter 3 — FileCheck directives](03-filecheck-directives.md)
