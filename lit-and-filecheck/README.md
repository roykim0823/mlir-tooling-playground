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

Every chapter's **Try it** commands are scripted in [`scripts/try.sh`](scripts/try.sh),
which echoes each command before running it, so the output reads like a
transcript:

```bash
scripts/try.sh           # every chapter, in order
scripts/try.sh 3         # just Chapter 3's commands (1–6)
```

It auto-builds the example and auto-detects the bundled LLVM (override with
`LLVM_BIN=/path/to/llvm-build/bin scripts/try.sh`). The mutating labs in
Chapter 6 back up and restore the files they touch, so it is safe to re-run.

## How to read this tutorial

Work through the chapters below in order; each ends with a **Try it** you can run
against the `example/` project.

| # | Chapter | What you'll learn |
|---|---------|-------------------|
| 1 | [lit basics](#chapter-1--lit-basics) | What lit is, how to invoke it, how it discovers tests (`lit.cfg.py` + `lit.site.cfg.py.in`), RUN lines, substitutions, result codes |
| 2 | [FileCheck basics](#chapter-2--filecheck-basics) | What FileCheck is, invocation, the plain `CHECK:` directive, whitespace rules |
| 3 | [FileCheck directives](#chapter-3--filecheck-directives) | `CHECK-NEXT`, `-SAME`, `-NOT`, `-DAG`, `-COUNT-n`, `-LABEL`, `-EMPTY` |
| 4 | [patterns and variables](#chapter-4--patterns-and-variables) | Regex `{{...}}`, string variables `[[VAR:...]]`, numeric variables `[[#...]]`, `@LINE` |
| 5 | [MLIR testing conventions](#chapter-5--mlir-testing-conventions) | MLIR conventions: SSA capture, diagnostic tests (`-verify-diagnostics`), runner/execution tests |
| 6 | [hands-on](#chapter-6--hands-on) | Build, break, and extend the `example/` project end-to-end |

## Setup (do this once)

You need a prebuilt LLVM/MLIR that provides `mlir-opt`, `FileCheck`, and a lit
runner. To run the standalone example, that's all — `example/run.sh` finds the
tools for you (and bootstraps `lit` if needed; see below).

**About the lit runner.** A *from-source* LLVM build ships `llvm-lit`. An
*installed* LLVM — Homebrew's `llvm@20` included — does **not**. The `lit`
PyPI/Homebrew package is the same tool under a different name and works
identically; both `example/run.sh` and `scripts/try.sh` fall back to it
automatically, so a missing `llvm-lit` is not a problem. On Homebrew:

```bash
brew install lit          # provides `lit`; equivalent to `llvm-lit`
```

To run the **Try it** shell snippets in the chapters by hand, put the tool
directory on your `PATH`. From this tutorial directory:

```bash
# From-source build: point at its bin/ (ships llvm-lit).
export PATH="$PWD/../../externals/llvm-project/build/bin:$PATH"
# Homebrew instead: export PATH="$(brew --prefix llvm@20)/bin:$PATH"

# sanity check — mlir-opt and FileCheck must resolve. A lit runner is either
# llvm-lit (from-source) or lit (installed); at least one should resolve.
which mlir-opt FileCheck
which llvm-lit || which lit
```

### macOS / Homebrew: "llvm-lit not found"

If you installed LLVM with Homebrew (`brew install llvm@20`), the sanity check
shows `mlir-opt` and `FileCheck` resolving but `llvm-lit` missing:

```text
$ which mlir-opt FileCheck llvm-lit
/opt/homebrew/opt/llvm@20/bin/mlir-opt
/opt/homebrew/opt/llvm@20/bin/FileCheck
llvm-lit not found
```

This is expected and **not** an error. Homebrew's LLVM ships lit's engine but
not the `llvm-lit` wrapper name (that name is only generated by a from-source
LLVM build). The `example/run.sh` and `scripts/try.sh` helpers already handle
this — they fall back to `lit` on your `PATH`, or bootstrap it into a private
`example/.lit-venv/` on first run — so you can ignore the missing `llvm-lit` and
just run them.

If you want to run the chapters' literal `llvm-lit …` commands by hand, install
`lit` and expose it under the `llvm-lit` name:

```bash
brew install lit
ln -sf "$(brew --prefix lit)/bin/lit" /opt/homebrew/bin/llvm-lit

# now resolves in any new terminal:
which llvm-lit            # /opt/homebrew/bin/llvm-lit
```

The symlink points at Homebrew's stable `opt/` path, so it survives
`brew upgrade lit`. (If you later install the full `brew install llvm`, it ships
its own `llvm-lit`; remove this symlink first to avoid a link conflict.)


---

## Chapter 1 — lit basics

> Source: <https://llvm.org/docs/CommandGuide/lit.html> and
> <https://llvm.org/docs/TestingGuide.html>

### 1.1 What is lit?

`lit` (the **L**LVM **I**ntegrated **T**ester) is a *portable test runner*. Its
job is narrow and well-defined:

1. **Discover** test files under a directory.
2. **Read** the `RUN:` lines inside each file.
3. **Execute** those lines as shell commands (with substitutions applied).
4. **Report** a result per file: PASS / FAIL / etc.

`lit` does **not** know anything about compilers, IR, or what "correct" output
is. It just runs commands and checks their exit codes. The actual *verification*
of output is delegated to another tool — usually `FileCheck` (Chapter 2).

### 1.2 Invoking lit

```
llvm-lit [options] [tests...]
```

`tests` can be individual files or directories to search. `lit` exits non-zero
if any test fails.

The options you will actually use day-to-day:

| Option | Meaning |
|--------|---------|
| `-v`, `--verbose` | Show the failing command and its output for **failed** tests |
| `-a`, `--show-all` | Like `-v`, but for **all** tests (great for debugging a passing-but-confusing test) |
| `-q`, `--quiet` | Only show failures |
| `-s`, `--succinct` | Less output + a progress bar |
| `--filter REGEXP` | Run only tests whose **name** matches the regex |
| `-j N`, `--workers N` | Run N tests in parallel (default: auto) |
| `--time-tests` | Report wall-clock time per test |
| `--show-suites` / `--show-tests` | List discovered suites / tests and exit |
| `--debug` | Debug lit's own *configuration* discovery |
| `--order {smart,random,lexical}` | Execution order (`smart` = previously-failed first) |

You can also set `LIT_OPTS` in the environment to inject options when lit is
invoked indirectly (e.g. by a CMake `check` target):

```bash
LIT_OPTS="--filter=cse -a" cmake --build build --target check
```

### 1.3 How lit discovers tests

When you point lit at a directory, it looks for two kinds of Python config
files — and this is the standard LLVM/MLIR convention:

- **`lit.cfg.py`** — the *main* config, checked into source. Describes the test
  format and which file extensions are tests. Hand-written. (You'll edit this.)
- **`lit.site.cfg.py`** — the *generated* config, written by the build system
  (CMake) into the **build** directory from a template named
  **`lit.site.cfg.py.in`**. It bakes in absolute paths (where the tools were
  built) and then `load_config(...)`s the main `lit.cfg.py`.

This split is why you run lit against the **build** directory even though the
`.mlir` files live in source — the generated site config points the "test source
root" back at the real test directory. In the `example/` project the chain is:

```
example/build/test/lit.site.cfg.py   (generated: absolute paths)
        └── load_config ──►  example/test/lit.cfg.py   (the real config)
```

CMake produces the site config with one call (see `example/CMakeLists.txt`):

```cmake
configure_lit_site_cfg(
  ${CMAKE_CURRENT_SOURCE_DIR}/test/lit.site.cfg.py.in   # template (source)
  ${CMAKE_CURRENT_BINARY_DIR}/test/lit.site.cfg.py      # generated (build)
  MAIN_CONFIG ${CMAKE_CURRENT_SOURCE_DIR}/test/lit.cfg.py)
```

#### The `config` object

Both config files run as Python with a pre-defined `config` object. Key
attributes (you'll see these in `example/test/lit.cfg.py`):

| Attribute | Purpose |
|-----------|---------|
| `config.name` | Suite name shown in reports (`"LIT_FILECHECK_EXAMPLE"`) |
| `config.test_format` | How to run tests — `ShTest()` = "RUN lines are shell commands" |
| `config.suffixes` | Which extensions are tests (`[".mlir"]`) |
| `config.test_source_root` | Where the test files live |
| `config.test_exec_root` | Where tests execute (build dir) |
| `config.substitutions` | Text substitutions (FileCheck, %s, %t, tool names…) |
| `config.environment` | Env vars for the test process (e.g. `PATH` so `mlir-opt` resolves) |
| `config.excludes` | Directories/files to skip |
| `config.available_features` | Feature names usable in `REQUIRES`/`UNSUPPORTED`/`XFAIL` |

### 1.4 The RUN line

Inside a test file, any line containing `RUN:` (after a comment marker) is a
command for lit to execute. The comment marker is whatever the file's language
uses — `//` for MLIR/C++, `;` for LLVM IR, `#` for assembly.

```mlir
// RUN: mlir-opt %s -cse | FileCheck %s
```

Rules:

- Multiple `RUN:` lines run **in sequence**; if any command returns non-zero,
  the test FAILs.
- They support **pipes and redirection** (`|`, `>`, `<`).
- A command can be split across lines with a trailing `\`.
- Keep them simple — the LLVM guide explicitly recommends minimal RUN lines and
  using FileCheck (not `grep`) for verification.

The two common forms are equivalent:

```mlir
// pipe form (most common):
// RUN: mlir-opt %s -cse | FileCheck %s

// temp-file form (when you need the output twice, or to inspect it):
// RUN: mlir-opt %s -cse > %t
// RUN: FileCheck %s < %t
```

### 1.5 Substitutions

Before running a RUN line, lit replaces magic tokens. The essential ones:

| Token | Expands to |
|-------|------------|
| `%s` | the **source** path of the test file being run |
| `%S` | the **directory** containing the test file |
| `%t` | a temp file path **unique to this test** (safe scratch space) |
| `%T` | a temp **directory** unique to this test |
| `%p` | same as `%S` (deprecated alias) |
| `%%` | a literal `%` |

Tool names like `mlir-opt` and `FileCheck` are *also* registered as
substitutions (via `add_tool_substitutions` in `lit.cfg.py`) so the test uses
the freshly-built binary rather than whatever is on your system `PATH`.

### 1.6 Result codes

lit classifies each test into one of these (the documented set):

| Code | Meaning |
|------|---------|
| **PASS** | Succeeded |
| **FAIL** | Failed |
| **XFAIL** | Failed, and that was **expected** (`XFAIL:` directive) — counts as success |
| **XPASS** | Passed, but was expected to fail — counts as **failure** |
| **UNSUPPORTED** | Skipped because environment lacks a required feature |
| **UNRESOLVED** | Result couldn't be determined (e.g. no RUN lines) |
| **TIMEOUT** | Exceeded `--timeout` |
| **FLAKYPASS** | Passed only after a retry |

FAIL, XPASS, UNRESOLVED, and TIMEOUT all count as failures for the exit code.

### 1.7 Conditional execution: REQUIRES / UNSUPPORTED / XFAIL

These directives (placed alongside RUN lines) gate a test on
`config.available_features`:

```mlir
// REQUIRES: asserts            // run ONLY if all listed features are present
// UNSUPPORTED: system-windows  // skip if ANY listed condition is true
// XFAIL: target=powerpc{{.*}}  // expect failure if ANY condition is true
```

Rule of thumb from the testing guide:
- `REQUIRES` enables the test if **all** expressions are true.
- `UNSUPPORTED` disables the test if **any** expression is true.
- `XFAIL` expects failure if **any** expression is true.

### Try it

> Shortcut: `scripts/try.sh 1` runs everything below automatically.

Build the example once, then drive lit against its generated config. From
`lit-and-filecheck/`:

```bash
cd example && ./run.sh        # configures + builds + runs all 3 tests
```

Now explore lit directly (the build dir now has the generated site config):

```bash
# Put the tools on PATH (adjust to your LLVM build):
export PATH="$PWD/../../../externals/llvm-project/build/bin:$PATH"

# 1. List every discovered test without running anything:
llvm-lit --show-tests build/test

# 2. Run just one test, verbosely:
llvm-lit -v build/test --filter='cse\.mlir'

# 3. Run all tests and time each one:
llvm-lit -v --time-tests build/test
```

Expected: step 2 prints `PASS: LIT_FILECHECK_EXAMPLE :: cse.mlir`.

➡️ Next: [Chapter 2 — FileCheck basics](#chapter-2--filecheck-basics)

---

## Chapter 2 — FileCheck basics

> Source: <https://llvm.org/docs/CommandGuide/FileCheck.html>

### 2.1 What is FileCheck?

> "FileCheck reads two files (one from standard input, and one specified on the
> command line) and uses one to verify the other."

- The **check file** (named on the command line) contains the expected
  patterns, written as `CHECK:` directives.
- The **input** (from stdin, or `--input-file`) is the text to verify — usually
  the output of a compiler tool.

FileCheck exits **0** if every directive matches in order, non-zero otherwise,
printing a diagnostic that shows *which* directive failed and *where*.

#### Why not just `grep` or `diff`?

- `diff` is too strict: it breaks on any whitespace change, renamed SSA values
  (`%0` vs `%c1_i32`), or reordered-but-equivalent output.
- `grep` is too weak: it can't express "this line, then the *next* line", "these
  in any order", "this must *not* appear here", or "capture this value and
  reuse it later".

FileCheck sits in the sweet spot: ordered, regex-capable, whitespace-tolerant,
with variables.

### 2.2 Invocation

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

### 2.3 The `CHECK:` directive

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

### 2.4 Whitespace handling

By default FileCheck **canonicalizes horizontal whitespace**: any run of spaces
or tabs in the pattern matches any run of spaces/tabs in the input. This is what
lets you indent `CHECK:` lines for readability without breaking matches.

Two knobs change this:

- `--strict-whitespace` — whitespace must match exactly (useful when testing a
  pretty-printer's exact formatting).
- `CHECK-EMPTY:` — the only way to assert a truly blank line (see Chapter 3),
  because a normal `CHECK:` with an empty pattern would match anything.

### 2.5 Comments inside check files

To write a comment that FileCheck ignores, use the comment prefix `COM:`:

```mlir
// COM: the next check verifies CSE collapsed the duplicate constant
// CHECK: arith.constant
```

Also, by default `RUN:` is treated as a comment prefix too — so FileCheck won't
try to interpret your RUN lines as checks.

### 2.6 Multiple prefixes — testing several configurations

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

### Try it

> Shortcut: `scripts/try.sh 2` runs everything below automatically.

With the tools on your `PATH` (see [setup](#setup-do-this-once)), from
`lit-and-filecheck/`:

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

➡️ Next: [Chapter 3 — FileCheck directives](#chapter-3--filecheck-directives)

---

## Chapter 3 — FileCheck directives

> Source: <https://llvm.org/docs/CommandGuide/FileCheck.html>

Beyond the plain `CHECK:`, FileCheck has directives that express *relationships*
between matches: adjacency, sameness, ordering-freedom, negation, counting, and
block boundaries. All use the form `PREFIX-DIRECTIVE: pattern`.

### 3.1 `CHECK-NEXT:` — the very next line

Matches only if the pattern is on the line **immediately after** the previous
match (exactly one newline between, no skipped lines).

```mlir
// CHECK-LABEL: func.func @simple_constant
// CHECK-NEXT: arith.constant      // must be the line right after the func line
```

Use it to assert there is *nothing* between two lines. `CHECK-NEXT` cannot be
the first directive (there's no "previous" match to anchor to).

### 3.2 `CHECK-SAME:` — same line as previous

Matches on the **same line** as the previous match. The standard MLIR use is
breaking a long function signature across multiple readable directives:

```mlir
// CHECK-LABEL: func.func @add(
// CHECK-SAME:    %[[A:.*]]: i32,
// CHECK-SAME:    %[[B:.*]]: i32
// CHECK-SAME:  ) -> i32 {
```

All four match within the single `func.func @add(%arg0: i32, %arg1: i32) -> i32 {`
line of the output. Without `CHECK-SAME`, the later patterns would be allowed to
match a *later* line.

### 3.3 `CHECK-NOT:` — must not appear

Asserts a pattern does **not** occur between the previous match and the next
positive match (or to end-of-input if it's last). This is exactly what
`example/test/canonicalize.mlir` does — after folding `x + 0`, the add must be
gone:

```mlir
// CHECK-LABEL: func.func @add_zero
// CHECK-NOT:   arith.addi        // the add was folded away
// CHECK:       return %arg0
```

A common stronger pattern: assert a thing happens exactly N times and never
more, by pairing with `CHECK-COUNT`:

```mlir
// CHECK-COUNT-3: arith.addi
// CHECK-NOT: arith.addi
```

You can also apply a negative check globally with `--implicit-check-not=PATTERN`
on the FileCheck command line — handy for "this opcode must never appear
anywhere in the output."

### 3.4 `CHECK-COUNT-<n>:` — repeated matches

Matches the pattern exactly `n` times, on consecutive matches.

```mlir
// CHECK-COUNT-4: vector.load     // expect exactly four loads in a row
```

### 3.5 `CHECK-DAG:` — order-independent matches

A group of consecutive `CHECK-DAG:` directives may match in **any order**
relative to each other. Use it when a pass emits a set of operations whose
ordering is not guaranteed:

```mlir
// CHECK-DAG: %[[A:.*]] = arith.constant 1
// CHECK-DAG: %[[B:.*]] = arith.constant 2
// the two constants may appear in either order
```

Notes:
- A `CHECK-DAG` skips text that overlaps an earlier `CHECK-DAG` in the same
  block, so each directive matches a distinct piece of input.
- A non-DAG directive (e.g. a plain `CHECK:` or `CHECK-LABEL:`) ends the DAG
  block and acts as a barrier.

### 3.6 `CHECK-EMPTY:` — a blank line

Asserts the next line exists and is **empty**. (You can't do this with `CHECK:`
because an empty pattern matches anything.) Cannot be the first directive.

```mlir
// CHECK: ; end of section
// CHECK-EMPTY:
// CHECK-NEXT: ; next section
```

### 3.7 `CHECK-LABEL:` — block boundaries / resync points

This is the most important structural directive in MLIR tests. `CHECK-LABEL:`
matches like `CHECK:`, but additionally **splits the input into independent
blocks** divided at each label match. FileCheck matches all the labels first,
then runs the directives between consecutive labels only against that block.

Why it matters:
1. **Better error messages** — a failure is localized to one function instead of
   the matcher sliding past it and failing somewhere confusing downstream.
2. **Resynchronization** — each function is checked independently, so a missing
   line in `@foo` doesn't cause spurious matches inside `@bar`.
3. With `--enable-var-scope`, **local variables are cleared** at each label, so
   `%[[ARG]]` defined in one function can't accidentally match another's.

```mlir
// CHECK-LABEL: func.func @foo
// CHECK:   arith.addi
// CHECK-LABEL: func.func @bar
// CHECK:   arith.muli
```

`CHECK-LABEL:` patterns must be self-contained: they **cannot define or use**
`[[...]]` variables (because labels are matched in a separate first pass).

### 3.8 Putting the directives together

This is `example/test/cse.mlir` — read it now with the directives in mind:

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

- `CHECK-LABEL` anchors to the function and isolates this block.
- `CHECK-NEXT` x2 require the constant and the return to be on consecutive lines
  (nothing snuck in between).
- `%[[RESULT:.*]]` captures whatever SSA name CSE chose (it's `%c1_i32`), and
  `%[[RESULT]]` reuses it — proving *both* returns reference the *same* value
  after the duplicate constant was eliminated. (More on capture in Chapter 4.)

### Try it

> Shortcut: `scripts/try.sh 3` runs everything below automatically.

With the tools on your `PATH` (see [setup](#setup-do-this-once)), from
`lit-and-filecheck/`:

```bash
# Inspect the real output, then watch the directives match it:
mlir-opt example/test/cse.mlir -cse | FileCheck example/test/cse.mlir --dump-input=fail && echo PASS
```

Experiment: in `example/test/cse.mlir`, change a `CHECK-NEXT:` to point at a line
that *isn't* actually adjacent (e.g. duplicate it), rerun, and read how the
diagnostic changes. Then revert.

➡️ Next: [Chapter 4 — FileCheck variables](#chapter-4--patterns-and-variables)

---

## Chapter 4 — patterns and variables

> Source: <https://llvm.org/docs/CommandGuide/FileCheck.html>

This is what makes FileCheck powerful: a pattern can contain **regexes**,
**captured string variables**, and **numeric variables with arithmetic**. This
is how a test asserts *structure* ("the result of this op feeds that op")
without hardcoding compiler-chosen names.

### 4.1 Fixed strings vs regex

By default a pattern is a **fixed string** (with whitespace canonicalization).
To embed a regular expression, wrap it in double braces `{{ ... }}`. The regex
syntax is POSIX Extended.

```mlir
// CHECK: register {{r[0-9]+}}        // matches "register r0", "register r42"
// CHECK: offset {{[0-9]+}}(%esp)
```

To match literal braces, escape them: `{{[}][}]}}` matches `}}`.

To turn off *all* special interpretation for a directive (treat everything
literally, including `[[` and `{{`), append `{LITERAL}`:

```mlir
// CHECK{LITERAL}: [[this]] {is} matched verbatim
```

### 4.2 String variables — define and reuse

This is the killer feature for IR tests. Syntax:

- **Define:** `[[NAME:regex]]` — match `regex`, and remember what matched under
  `NAME`.
- **Use:** `[[NAME]]` — match exactly the text previously captured.

```mlir
// CHECK: %[[REG:.*]] = arith.constant 1
// CHECK: return %[[REG]], %[[REG]]    // same SSA value used twice
```

The first line matches whatever SSA name the compiler chose (`%0`, `%c1_i32`,
…) and binds it to `REG`. The second line then requires that *exact same* name
to appear twice. The test verifies a data-flow relationship, not a spelling.

Why `%[[REG:.*]]` and not `[[REG:.*]]`? The literal `%` is part of MLIR's SSA
syntax (outside the brackets); only the *name* after it is captured. `.*` is the
regex that captures the name.

Rules:
- A variable may be redefined; later uses take the newest value.
- A variable **can** be used on the same line it's defined.
- With `--enable-var-scope`, names starting with `$` are global; all others are
  local and **cleared at each `CHECK-LABEL:`** (prevents cross-function leakage).

#### The canonical MLIR idiom

```mlir
// CHECK-LABEL: func.func @simple_constant
// CHECK-NEXT: %[[RESULT:.*]] = arith.constant 1
// CHECK-NEXT: return %[[RESULT]], %[[RESULT]]
func.func @simple_constant() -> (i32, i32) {
  %0 = arith.constant 1 : i32
  %1 = arith.constant 1 : i32
  return %0, %1 : i32, i32
}
```

This is a CSE test: after common-subexpression elimination the two constants
collapse to one, and *both* returns must reference it. The capture proves they
are the *same* value.

### 4.3 Numeric variables

For numbers you can capture, constrain, and do arithmetic. Syntax centers on the
`[[# ... ]]` form.

#### Capture a number

```mlir
// CHECK: load r[[#REG:]]        // capture the number after r into REG
// CHECK: load r[[#REG+1]]       // require the next load uses REG+1
```

#### Capture with an explicit format

`[[#%FMT,NAME:]]` captures using a printf-style format:

| Format | Meaning |
|--------|---------|
| `%u` | unsigned decimal (default) |
| `%d` | signed decimal |
| `%x` / `%X` | hex lower / upper |
| `#` flag | require `0x` prefix |
| `.N` | minimum N digits, zero-padded |

```mlir
// CHECK: value 0x[[#%.8X,ADDR:]]    // matches 0x0000FEFE, captures ADDR=0xFEFE
```

#### Substitute / compute

```mlir
// CHECK: [[#ADDR+7]]               // the value ADDR plus 7
// CHECK: [[#%x, ADDR + 16]]        // formatted as hex
```

Expressions support `+`, `-`, and functions `add()`, `sub()`, `mul()`, `div()`,
`min()`, `max()`.

#### Combined define + constraint

```mlir
// CHECK: offset [[#%x,OFFSET:0x10]]  // capture OFFSET, also require it equals 0x10
```

### 4.4 The `@LINE` pseudo-variable

`@LINE` is the line number of the current `CHECK` directive; `@LINE+N` / `@LINE-N`
offset it. Indispensable for diagnostic tests where an error message embeds a
line number:

```mlir
// CHECK: error at line [[# @LINE + 2]]
// (string form also works: [[@LINE]], [[@LINE-1]])
```

In MLIR diagnostic tests you'll more often use the `@+1` form on the
`expected-error` directive itself (Chapter 5) — same idea, different tool.

### 4.5 Command-line defines: `-D`

Inject a variable value from the RUN line, so one check file works for several
runs:

```mlir
// RUN: mlir-opt %s | FileCheck %s -DWIDTH=32
// CHECK: i[[WIDTH]]
```

Numeric form: `-D#FMT,NAME=EXPR`.

### Try it

> Shortcut: `scripts/try.sh 4` runs everything below automatically.

With the tools on your `PATH` (see [setup](#setup-do-this-once)), from
`lit-and-filecheck/`:

```bash
# example/test/cse.mlir uses capture-and-reuse to verify the duplicate constant
# collapses and BOTH returns reference the one surviving value:
cat example/test/cse.mlir
mlir-opt example/test/cse.mlir -cse | FileCheck example/test/cse.mlir && echo PASS
```

Experiment: in `example/test/cse.mlir`, change one `%[[RESULT]]` *use* to a
different captured name (e.g. `%[[OTHER]]`) and rerun — FileCheck will report an
**undefined variable**, proving the uses are genuinely tied to the definition.
Then revert.

➡️ Next: [Chapter 5 — MLIR testing conventions](#chapter-5--mlir-testing-conventions)

---

## Chapter 5 — MLIR testing conventions

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

### 5.1 Check tests — the standard form

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

### 5.2 Diagnostic tests — `-verify-diagnostics`

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

#### An alternative: capture stderr + FileCheck it

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

### 5.3 Integration / runner tests — execute and check output

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

### 5.4 How the build wires it up

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

### Try it

> Shortcut: `scripts/try.sh 5` runs everything below automatically.

With the tools on your `PATH` (see [setup](#setup-do-this-once)), from
`lit-and-filecheck/`:

```bash
cd example && ./run.sh          # builds + runs all three categories at once

export PATH="$PWD/../../../externals/llvm-project/build/bin:$PATH"

# A check test:
llvm-lit -v build/test --filter='canonicalize\.mlir'

# A diagnostic test (note -verify-diagnostics in its RUN line):
grep -nE 'RUN:|expected-' test/invalid.mlir
llvm-lit -v build/test --filter='invalid\.mlir'
```

➡️ Next: [Chapter 6 — hands-on](#chapter-6--hands-on)

---

## Chapter 6 — hands-on

Time to use everything against the standalone [`example/`](example/) project.

> Shortcut: `scripts/try.sh 6` runs all six labs automatically (it backs up and
> restores the files Labs 4–5 touch, so it's safe to re-run).

Run each block from `lit-and-filecheck/`. First build once:

```bash
cd example
./run.sh
export PATH="$PWD/../../../externals/llvm-project/build/bin:$PATH"   # adjust to your LLVM build
```

`./run.sh` printed `Passed: 3 (100.00%)` and created `example/build/` with the
generated `lit.site.cfg.py`.

### Lab 1 — run a single test three ways

```bash
# (a) Via the build system (rebuilds nothing here, then runs lit):
cmake --build build --target check

# (b) Via llvm-lit, one file, verbose:
llvm-lit -v build/test --filter='cse\.mlir'

# (c) By hand, reproducing the RUN line yourself:
mlir-opt test/cse.mlir -cse > /tmp/out.mlir
FileCheck test/cse.mlir < /tmp/out.mlir && echo "PASS"
cat /tmp/out.mlir      # <-- see exactly what FileCheck verified
```

Compare `/tmp/out.mlir` against the `// CHECK:` lines in `test/cse.mlir`. Confirm
that `%[[RESULT]]` binds to the real SSA name (`%c1_i32`) and that both returns
use it.

### Lab 2 — read a failure

Break a test deliberately and read FileCheck's diagnostic — the single most
useful skill:

```bash
# Demand an op CSE does NOT produce:
printf '// CHECK: arith.muli\n' > /tmp/bad.check
mlir-opt test/cse.mlir -cse | FileCheck /tmp/bad.check --dump-input=fail
```

Read the output. FileCheck prints the directive that failed, the string it was
looking for, and the annotated input it scanned (so you can see there was no
`muli`).

### Lab 3 — break a captured variable

This shows captures are real bindings, not decoration:

```bash
# Temporarily point one use at an undefined variable:
sed 's/%\[\[RESULT\]\], %\[\[RESULT\]\]/%[[RESULT]], %[[OTHER]]/' test/cse.mlir > /tmp/cse_broken.mlir
mlir-opt test/cse.mlir -cse | FileCheck /tmp/cse_broken.mlir
```

FileCheck reports an **undefined variable** `OTHER` — proving the second use was
genuinely tied to the first definition.

### Lab 4 — write a new test (no CMake edit needed)

`add_lit_testsuite` discovers tests by the `.mlir` suffix, so dropping a file in
`test/` and re-running is all it takes:

```bash
cat > test/double_negate.mlir <<'EOF'
// RUN: mlir-opt %s -canonicalize | FileCheck %s

// CHECK-LABEL: func.func @double_negate
// CHECK-NOT: arith.subi
// CHECK: return %arg0
func.func @double_negate(%arg0: i32) -> i32 {
  %c0 = arith.constant 0 : i32
  %0 = arith.subi %c0, %arg0 : i32   // -x
  %1 = arith.subi %c0, %0 : i32      // -(-x) == x
  return %1 : i32
}
EOF

# Fast inner loop (standalone), then the full suite:
mlir-opt test/double_negate.mlir -canonicalize | FileCheck test/double_negate.mlir && echo PASS
./run.sh
```

You just exercised `CHECK-LABEL`, `CHECK-NOT`, and a plain `CHECK` on a real
canonicalization. (`-(-x)` folds back to `x`, so both `subi`s vanish.)

### Lab 5 — add a diagnostic case

Append a third sub-test to `test/invalid.mlir` and confirm it still passes:

```bash
cat >> test/invalid.mlir <<'EOF'

// -----

func.func @bad_return2() -> f32 {
  %0 = arith.constant 1 : i32
  // expected-error @+1 {{doesn't match function result type ('f32')}}
  return %0 : i32
}
EOF
llvm-lit -v build/test --filter='invalid\.mlir'
```

If the expected message doesn't match what `mlir-opt` actually emits, lit will
show you the real diagnostic — tweak the `{{...}}` fragment to match. (This is
the normal authoring loop for diagnostic tests.)

> **Gotcha — unexpected notes.** Try instead adding a type-mismatched
> `arith.addi %a, %b` (with `%a: i32, %b: i64`). It *won't* pass with just an
> `expected-error`, because the parser also emits a standalone
> `note: prior use here`, and `-verify-diagnostics` treats an unexpected note as
> a failure. You'd have to also annotate the operand's declaration with
> `// expected-note {{prior use here}}`. By contrast, the return-type error above
> carries its note *attached* to the error, so it's consumed automatically. Rule
> of thumb: if a diagnostic test fails on `unexpected note:`, add a matching
> `expected-note`.

### Lab 6 — clean up

```bash
rm -f test/double_negate.mlir /tmp/out.mlir /tmp/bad.check /tmp/cse_broken.mlir
git checkout -- test/invalid.mlir 2>/dev/null || true     # from example/, git finds the repo
./run.sh clean
```

### Cheat sheet

| Goal | Command |
|------|---------|
| Configure + build + run all tests | `./run.sh` |
| Run all tests (no reconfigure) | `cmake --build build --target check` |
| Run all tests directly | `llvm-lit -v build/test` |
| Run one test | `llvm-lit -v build/test --filter='NAME\.mlir'` |
| List tests | `llvm-lit --show-tests build/test` |
| Reproduce by hand | `mlir-opt FILE -pass \| FileCheck FILE` |
| Debug a FileCheck fail | add `--dump-input=fail` to the FileCheck call |
| Verbose output of passing tests | `llvm-lit -a ...` |

| FileCheck directive | Use |
|---------------------|-----|
| `CHECK:` | pattern appears at/after here |
| `CHECK-NEXT:` | on the immediately following line |
| `CHECK-SAME:` | on the same line as previous match |
| `CHECK-NOT:` | must NOT appear before next match |
| `CHECK-DAG:` | group matches, any order |
| `CHECK-COUNT-n:` | exactly n consecutive matches |
| `CHECK-LABEL:` | block boundary + resync |
| `CHECK-EMPTY:` | next line is blank |
| `{{regex}}` | embed a regex |
| `[[VAR:regex]]` / `[[VAR]]` | define / use string variable |
| `[[#VAR:]]` / `[[#VAR+1]]` | numeric capture / arithmetic |

You now know the whole pipeline: **lit discovers and runs**, **substitutions fill
in paths**, **the tool transforms or executes IR**, and **FileCheck verifies the
result structurally**. That's the same machinery behind every test in upstream
LLVM and MLIR — and the `example/` project is a complete, standalone instance of
it you can copy and adapt.

---

## References (the primary sources this tutorial is built from)

- **lit** — <https://llvm.org/docs/CommandGuide/lit.html>
- **FileCheck** — <https://llvm.org/docs/CommandGuide/FileCheck.html>
- **LLVM Testing Guide** — <https://llvm.org/docs/TestingGuide.html>
- **MLIR Testing Guide** — <https://mlir.llvm.org/getting_started/TestingGuide/>
