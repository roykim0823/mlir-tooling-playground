# lit & FileCheck — a hands-on tutorial

The two tools that drive almost every LLVM/MLIR regression test:

- **`lit`** — the test *runner*. Finds test files and runs the shell commands written inside them.
- **`FileCheck`** — the output *pattern matcher*. Reads `// CHECK:` patterns from a file and verifies they appear, in order, in text you pipe to it.

A typical MLIR test is a single `.mlir` file holding *both* the command to run
and the expected output, written as comments — a `// RUN:` line for lit and
`// CHECK:` lines for FileCheck. Here's a complete one, `example/test/cse.mlir`:

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

When lit runs it:

- `lit` sees the `// RUN:` line, substitutes `%s` with the file's path, and runs `mlir-opt %s -cse | FileCheck %s`.
- `FileCheck` re-reads the same file for `// CHECK:` lines and checks them against the piped-in transformed IR.
- Exit code 0 → `lit` reports **PASS**.

> **What's `-cse`?** It's a *pass flag* for `mlir-opt`, naming a single
> transformation to run. **CSE** (Common Subexpression Elimination) finds
> operations that compute the same thing and collapses them into one — here the
> two identical `arith.constant 1`s become a single value both returns share.
> `mlir-opt FILE -cse` therefore means "parse this IR, run *only* CSE, print the
> result." You'll also see `-canonicalize` (algebraic folding/cleanup, in
> `canonicalize.mlir`). These tests deliberately run one minimal pass, not `-O3`,
> so the expected output is predictable and a failure has exactly one cause.

This tutorial is **self-contained**: every example runs against a small standalone
CMake project in [`example/`](example/) using the stock `mlir-opt` and
`FileCheck`. The only prerequisite is a prebuilt LLVM/MLIR.

**Contents.** [Setup](#setup) · [Quick start](#quick-start) ·
Tutorials: [1 lit basics](#tutorial-1--lit-basics) ·
[2 FileCheck basics](#tutorial-2--filecheck-basics) ·
[3 directives](#tutorial-3--filecheck-directives) ·
[4 patterns & variables](#tutorial-4--patterns-and-variables) ·
[5 MLIR conventions](#tutorial-5--mlir-testing-conventions) ·
[6 write your own](#tutorial-6--write-your-own-test) ·
[Cheat sheet](#cheat-sheet) ·
[Appendix: setup & troubleshooting](#appendix-setup-and-troubleshooting)

## Setup

You need a prebuilt LLVM/MLIR providing `mlir-opt`, `FileCheck`, and a lit runner.
That's all — the example finds the tools for you.

```bash
cd example
./run.sh
```

Expected tail: `Passed: 3 (100.00%)`.

If `run.sh` can't find your LLVM, or you're on Homebrew and see "llvm-lit not
found", that's normal and handled — see the
[appendix](#appendix-setup-and-troubleshooting) for overrides and troubleshooting.

The tutorials below also run `mlir-opt`, `FileCheck`, and `llvm-lit` directly, so
put them on your `PATH` (check with `which mlir-opt FileCheck`; the appendix has
the details):

```bash
export PATH="$(brew --prefix llvm@20)/bin:$PATH"   # Homebrew; or your from-source bin/
```

## Quick start

You just ran the whole suite. Here's what one test actually *does* — bypass lit
and run its RUN-line pipeline yourself (needs only `mlir-opt` and `FileCheck`):

```bash
cd example

# What does the pass produce? (the IR FileCheck will verify)
mlir-opt test/cse.mlir -cse

# Pipe it through FileCheck — silence + exit 0 means the CHECK lines matched:
mlir-opt test/cse.mlir -cse | FileCheck test/cse.mlir && echo PASS
```

FileCheck confirmed the transformed IR matches the `// CHECK:` lines: CSE
collapsed the two identical constants into one, and both `return`s reference it.
lit just automates exactly this pipeline. The tutorials below build it up one
idea at a time — run something small, see what happened, then add the next idea.

> Tutorials 1 and 5 drive the built example with `llvm-lit`; Tutorials 2–4 mostly
> feed a few lines of made-up text straight into `FileCheck`, so they need only it
> on your `PATH`. Run them from the `example/` directory.

---

## Tutorial 1 — lit basics

> Source: <https://llvm.org/docs/CommandGuide/lit.html> and
> <https://llvm.org/docs/TestingGuide.html>

`lit` (the **L**LVM **I**ntegrated **T**ester) is a test *runner*. It discovers
test files, runs the shell commands written inside them, and reports PASS/FAIL.
It knows nothing about compilers or IR — verifying output is FileCheck's job.
Let's watch it do each part.

### Step 1 — run the suite

From `example/`:

```bash
llvm-lit build/test
```

```
-- Testing: 3 tests, 3 workers --
Testing Time: 0.26s
Total Discovered Tests: 3
  Passed: 3 (100.00%)
```

lit found three tests, ran each, and all passed. That's the whole loop.

### Step 2 — see what lit discovered, and why

```bash
llvm-lit --show-tests build/test
```

```
-- Available Tests --
  LIT_FILECHECK_EXAMPLE :: canonicalize.mlir
  LIT_FILECHECK_EXAMPLE :: cse.mlir
  LIT_FILECHECK_EXAMPLE :: invalid.mlir
```

It picked up exactly the `.mlir` files — because the config said so. lit looks
for two Python config files:

- **`lit.cfg.py`** — hand-written, checked into source. Declares the suite name,
  that `.mlir` files are tests (`config.suffixes = [".mlir"]`), and the
  `ShTest` format ("RUN lines are shell commands").
- **`lit.site.cfg.py`** — *generated* by CMake into the build dir from a
  `lit.site.cfg.py.in` template. It bakes in absolute tool paths, then
  `load_config()`s the hand-written one.

That split is why you point lit at `build/test` even though the `.mlir` files
live in source:

```
build/test/lit.site.cfg.py   (generated: absolute paths)
        └── load_config ──►  test/lit.cfg.py   (the real, hand-written config)
```

(For the full CMake wiring, see [`example/README.md`](example/README.md).)

### Step 3 — watch one RUN line execute

`-v` shows the command for failing tests; `-a` shows it for *every* test. Use
`-a` to see exactly what lit ran:

```bash
llvm-lit -a build/test --filter='canonicalize\.mlir'
```

The interesting part of the output:

```
RUN: at line 1: /opt/homebrew/.../bin/mlir-opt .../test/canonicalize.mlir -canonicalize \
                | /opt/homebrew/.../bin/FileCheck .../test/canonicalize.mlir
```

Compare that to the RUN line in the file:

```mlir
// RUN: mlir-opt %s -canonicalize | FileCheck %s
```

lit **expanded** it before running. That's the next idea.

### Step 4 — substitutions

Before running a RUN line, lit replaces magic tokens. In the expansion above:

- `%s` → the absolute path of *this* test file (twice).
- `mlir-opt` and `FileCheck` → absolute paths to the prebuilt binaries (not
  whatever is on your shell `PATH`), because `lit.cfg.py` registered them as tool
  substitutions.

The essential tokens:

| Token | Expands to |
|-------|------------|
| `%s` | the **source** path of the test file being run |
| `%S` | the **directory** containing the test file |
| `%t` | a temp file path **unique to this test** (safe scratch space) |
| `%T` | a temp **directory** unique to this test |
| `%%` | a literal `%` |

So `// RUN: mlir-opt %s -cse | FileCheck %s` means "run the freshly-built
`mlir-opt` on *me*, pipe to the freshly-built `FileCheck`, checking against *me*."

### Step 5 — RUN line rules

```mlir
// RUN: mlir-opt %s -cse > %t      // first command: write IR to a temp file
// RUN: FileCheck %s < %t          // second: check it
```

- The comment marker is the file's own (`//` for MLIR/C++, `;` for LLVM IR, `#` for asm).
- Multiple RUN lines run **in sequence**; any non-zero exit FAILs the test.
- Pipes and redirection (`|`, `>`, `<`) work; split a long line with trailing `\`.
- Keep them minimal — verify with FileCheck, not `grep`.

### Reference tables

<details><summary><b>Common <code>llvm-lit</code> options</b></summary>

| Option | Meaning |
|--------|---------|
| `-v`, `--verbose` | Show the command + output for **failed** tests |
| `-a`, `--show-all` | Like `-v`, but for **all** tests |
| `-q`, `--quiet` | Only show failures |
| `-s`, `--succinct` | Less output + a progress bar |
| `--filter REGEXP` | Run only tests whose **name** matches the regex |
| `-j N`, `--workers N` | Run N tests in parallel (default: auto) |
| `--time-tests` | Report wall-clock time per test |
| `--show-suites` / `--show-tests` | List discovered suites / tests and exit |
| `--order {smart,random,lexical}` | Execution order (`smart` = previously-failed first) |

Set `LIT_OPTS` to inject options when lit runs indirectly:
`LIT_OPTS="--filter=cse -a" cmake --build build --target check`.
</details>

<details><summary><b>The <code>config</code> object (in <code>lit.cfg.py</code>)</b></summary>

| Attribute | Purpose |
|-----------|---------|
| `config.name` | Suite name shown in reports |
| `config.test_format` | `ShTest()` = "RUN lines are shell commands" |
| `config.suffixes` | Which extensions are tests (`[".mlir"]`) |
| `config.test_source_root` | Where the test files live |
| `config.test_exec_root` | Where tests execute (build dir) |
| `config.substitutions` | Text substitutions (FileCheck, %s, %t, tool names…) |
| `config.environment` | Env vars for the test process (e.g. `PATH`) |
| `config.available_features` | Names usable in `REQUIRES`/`UNSUPPORTED`/`XFAIL` |
</details>

<details><summary><b>Result codes</b></summary>

| Code | Meaning |
|------|---------|
| **PASS** | Succeeded |
| **FAIL** | Failed |
| **XFAIL** | Failed, and that was expected (`XFAIL:`) — counts as success |
| **XPASS** | Passed but expected to fail — counts as **failure** |
| **UNSUPPORTED** | Skipped; environment lacks a required feature |
| **UNRESOLVED** | Couldn't determine a result (e.g. no RUN lines) |
| **TIMEOUT** | Exceeded `--timeout` |

FAIL, XPASS, UNRESOLVED, and TIMEOUT count as failures for the exit code.
</details>

<details><summary><b>Conditional execution: REQUIRES / UNSUPPORTED / XFAIL</b></summary>

```mlir
// REQUIRES: asserts            // run ONLY if all listed features are present
// UNSUPPORTED: system-windows  // skip if ANY listed condition is true
// XFAIL: target=powerpc{{.*}}  // expect failure if ANY condition is true
```

`REQUIRES` enables if **all** are true; `UNSUPPORTED` disables if **any** is true;
`XFAIL` expects failure if **any** is true.
</details>

➡️ Next: [Tutorial 2 — FileCheck basics](#tutorial-2--filecheck-basics)

---

## Tutorial 2 — FileCheck basics

> Source: <https://llvm.org/docs/CommandGuide/FileCheck.html>

FileCheck reads **two** things: a *check file* of `CHECK:` patterns (named on the
command line) and *input* text (from stdin). It verifies the input contains the
patterns, in order, and exits 0 if so. We'll feed it tiny made-up inputs so you
can see each rule in isolation — no compiler needed.

### Step 1 — the smallest possible check

```bash
printf 'alpha\nbeta\ngamma\n' | FileCheck <(printf 'CHECK: alpha\nCHECK: gamma\n')
echo "exit: $?"        # -> 0
```

The input has `alpha … gamma`; both patterns matched in order, so FileCheck is
silent and exits 0. (`<(...)` is just a throwaway check file; in a real test it'd
be the `.mlir` file itself.)

### Step 2 — ordered, but not adjacent

Notice that worked even though `beta` sits *between* `alpha` and `gamma`. Plain
`CHECK:` means "appears on this line or any later line." Anything is allowed in
between. Order is enforced; adjacency is not — flip the patterns and it fails:

```bash
printf 'alpha\nbeta\ngamma\n' | FileCheck <(printf 'CHECK: gamma\nCHECK: alpha\n')
echo "exit: $?"        # -> 1  (alpha never appears AFTER gamma)
```

To forbid the gap between two lines, you need `CHECK-NEXT` (Tutorial 3).

### Step 3 — substring by default, and read a failure

A pattern matches a **substring** of a line — `CHECK: lph` would match `alpha`.
Now make it fail on purpose and read what FileCheck tells you:

```bash
printf 'alpha\nbeta\ngamma\n' | FileCheck <(printf 'CHECK: delta\n')
```

```
error: CHECK: expected string not found in input
CHECK: delta
       ^
note: scanning from here
```

It names the directive, the string it wanted (`delta`), and where it was
scanning. Add `--dump-input=fail` to also print the annotated input — the single
most useful debugging flag. For the same failure on *real* IR, run the committed
`broken/expects_muli.mlir` from `example/` (it demands an op the pass never
produces):

```bash
mlir-opt broken/expects_muli.mlir -cse | FileCheck broken/expects_muli.mlir --dump-input=fail
```

`broken/` holds intentionally-failing tests; they live outside `test/` so lit
never runs them as part of the suite.

### Step 4 — whitespace is canonicalized

By default any run of spaces/tabs in the pattern matches any run in the input, so
you can indent `CHECK:` lines for readability:

```bash
printf 'a      b\n' | FileCheck <(printf 'CHECK: a b\n') && echo "PASS (spaces collapsed)"
```

Pass `--strict-whitespace` when exact spacing matters (e.g. testing a
pretty-printer). To assert a genuinely *blank* line, use `CHECK-EMPTY:`
(Tutorial 3) — a `CHECK:` with an empty pattern matches anything.

### Step 5 — comments and multiple prefixes

`COM:` is a comment FileCheck ignores; `RUN:` is also ignored by default, so your
RUN lines aren't read as checks. And one file can drive several pipelines by
giving each its own prefix:

```mlir
// RUN: mlir-opt %s -pass-a | FileCheck %s --check-prefix=A
// RUN: mlir-opt %s -pass-b | FileCheck %s --check-prefix=B
// A: result_from_a
// B: result_from_b
```

`--check-prefixes=CHECK,A` activates several at once.

### Reference table

<details><summary><b>Common <code>FileCheck</code> options</b></summary>

| Option | Meaning |
|--------|---------|
| `--check-prefix PREFIX` | Use `PREFIX:` instead of `CHECK:` |
| `--check-prefixes A,B` | Multiple prefixes from one file |
| `--input-file FILE` | Read input from a file instead of stdin |
| `--match-full-lines` | A match must span the whole line, not a substring |
| `--strict-whitespace` | Don't canonicalize whitespace |
| `--implicit-check-not PAT` | Add an implicit `CHECK-NOT: PAT` between every directive |
| `-DVAR=VALUE` | Predefine a pattern variable from the command line |
| `--dump-input=fail` | On failure, print the annotated input |
</details>

➡️ Next: [Tutorial 3 — FileCheck directives](#tutorial-3--filecheck-directives)

---

## Tutorial 3 — FileCheck directives

> Source: <https://llvm.org/docs/CommandGuide/FileCheck.html>

Plain `CHECK:` only says "appears later." The other directives express
*relationships* — adjacency, sameness, order-freedom, negation, counting, block
boundaries. Each takes the form `PREFIX-DIRECTIVE: pattern`. We'll prove each one
with a two-line input.

### `CHECK-NEXT:` — the very next line

Matches only on the line **immediately after** the previous match. Same line
between two patterns → pass; a gap → fail:

```bash
# adjacent: passes
printf 'alpha\nbeta\n'        | FileCheck <(printf 'CHECK: alpha\nCHECK-NEXT: beta\n')  && echo PASS
# gap: fails (gamma is not right after alpha)
printf 'alpha\nbeta\ngamma\n' | FileCheck <(printf 'CHECK: alpha\nCHECK-NEXT: gamma\n'); echo "exit: $?"
```

`CHECK-NEXT` can't be the first directive (there's no previous match to anchor to).

### `CHECK-SAME:` — same line as previous

Matches on the **same** line as the previous match. The standard use is breaking
a long signature across readable lines:

```mlir
// CHECK-LABEL: func.func @add(
// CHECK-SAME:    %[[A:.*]]: i32,
// CHECK-SAME:    %[[B:.*]]: i32
// CHECK-SAME:  ) -> i32 {
```

All four match within the single `func.func @add(%arg0: i32, %arg1: i32) -> i32 {`
output line.

### `CHECK-NOT:` — must not appear

Asserts a pattern does **not** occur between the previous match and the next one:

```bash
# beta IS present between alpha and gamma -> fails
printf 'alpha\nbeta\ngamma\n' | FileCheck <(printf 'CHECK: alpha\nCHECK-NOT: beta\nCHECK: gamma\n'); echo "exit: $?"
```

This is what `example/test/canonicalize.mlir` uses: after folding `x + 0`, the
`arith.addi` must be gone. You can also apply it globally with
`--implicit-check-not=PATTERN` on the command line.

### `CHECK-COUNT-<n>:` — exactly n times

```bash
printf 'x\nx\nx\n' | FileCheck <(printf 'CHECK-COUNT-3: x\n') && echo "PASS (three in a row)"
```

Pair with `CHECK-NOT` to mean "exactly n and no more."

### `CHECK-DAG:` — any order

Consecutive `CHECK-DAG:` directives may match in **any** order — for passes that
emit a set of ops with no guaranteed ordering. Both input orders pass:

```bash
printf 'one\ntwo\n' | FileCheck <(printf 'CHECK-DAG: one\nCHECK-DAG: two\n') && echo PASS
printf 'two\none\n' | FileCheck <(printf 'CHECK-DAG: one\nCHECK-DAG: two\n') && echo PASS
```

A non-DAG directive (plain `CHECK:` or `CHECK-LABEL:`) ends the DAG block.

### `CHECK-EMPTY:` — a blank line

Asserts the next line exists and is empty (can't be the first directive):

```mlir
// CHECK: end of section
// CHECK-EMPTY:
// CHECK-NEXT: next section
```

### `CHECK-LABEL:` — block boundaries / resync

The most important structural directive in MLIR tests. It matches like `CHECK:`
but **splits the input into independent blocks** at each label. FileCheck matches
all labels first, then checks the directives between two labels only against that
block. Why it matters:

1. **Localized errors** — a failure points at the right function, not somewhere
   downstream.
2. **Resynchronization** — a missing line in `@foo` can't cause spurious matches
   in `@bar`.
3. With `--enable-var-scope`, local `[[...]]` variables are **cleared** at each
   label, so a capture in one function can't leak into another.

```mlir
// CHECK-LABEL: func.func @foo
// CHECK:   arith.addi
// CHECK-LABEL: func.func @bar
// CHECK:   arith.muli
```

Label patterns must be self-contained: they **cannot** define or use `[[...]]`
variables (labels are matched in a separate first pass).

### Putting it together — read a real test

Now `example/test/cse.mlir` reads naturally:

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

`CHECK-LABEL` isolates the function; the two `CHECK-NEXT`s require the constant
and the return on consecutive lines; and `%[[RESULT]]` is a captured variable —
the subject of [Tutorial 4](#tutorial-4--patterns-and-variables).

➡️ Next: [Tutorial 4 — patterns and variables](#tutorial-4--patterns-and-variables)

---

## Tutorial 4 — patterns and variables

> Source: <https://llvm.org/docs/CommandGuide/FileCheck.html>

This is what lets a test assert *structure* — "the result of this op feeds that
op" — without hardcoding compiler-chosen names. A pattern can hold regexes,
captured string variables, and numeric variables with arithmetic.

### Step 1 — embed a regex with `{{ ... }}`

Patterns are fixed strings by default. Wrap a POSIX-extended regex in double
braces to match variable text:

```bash
printf 'register r42\n' | FileCheck <(printf 'CHECK: register {{r[0-9]+}}\n') && echo "PASS (r-any-number)"
```

To match literal braces, escape: `{{[}][}]}}` matches `}}`. To disable *all*
special interpretation for one directive, append `{LITERAL}`:
`// CHECK{LITERAL}: [[x]] {y}`.

### Step 2 — capture a string and reuse it

The killer feature. **Define** `[[NAME:regex]]` captures what `regex` matched;
**use** `[[NAME]]` requires that exact same text again. The example's `cse.mlir`
is built on this — from `example/`:

```bash
mlir-opt test/cse.mlir -cse | FileCheck test/cse.mlir && echo "PASS (both returns share one value)"
```

Its check lines are:

```mlir
// CHECK-NEXT: %[[RESULT:.*]] = arith.constant 1
// CHECK-NEXT: return %[[RESULT]], %[[RESULT]]
```

`%[[RESULT:.*]]` captures whatever SSA name CSE picked (here `%c1_i32`); the next
line requires that *same* name twice — proving both returns reference the one
surviving constant. Now see what happens when a use has no definition. The
committed `broken/undefined_var.mlir` changes the second `%[[RESULT]]` to
`%[[OTHER]]`:

```bash
mlir-opt broken/undefined_var.mlir -cse | FileCheck broken/undefined_var.mlir   # -> error: undefined variable: OTHER
```

That "undefined variable" proves captures are real bindings, not decoration. Why
`%[[RESULT:.*]]` and not `[[RESULT:.*]]`? The `%` is literal SSA syntax outside
the brackets; only the name after it is captured. This is the canonical MLIR
capture idiom.

### Step 3 — numeric variables and arithmetic

Use `[[# ... ]]` for numbers you can capture and compute on:

```bash
printf 'load r3\nload r4\n' | FileCheck <(printf 'CHECK: load r[[#REG:]]\nCHECK: load r[[#REG+1]]\n') && echo "PASS (consecutive registers)"
```

`[[#REG:]]` captures the number after `r`; `[[#REG+1]]` requires the next load to
use one more. Expressions support `+`, `-`, and `add/sub/mul/div/min/max()`. You
can also format and constrain:

```mlir
// CHECK: value 0x[[#%.8X,ADDR:]]    // capture as 8-digit hex
// CHECK: next  0x[[#%x, ADDR + 16]] // reuse, formatted, plus 16
```

### Step 4 — `@LINE` and command-line `-D`

`@LINE` is the current directive's line number (`@LINE+N` / `@LINE-N` offset it) —
handy when an expected message embeds a line number. And `-D` injects a value
from the RUN line so one check file serves several runs:

```mlir
// RUN: mlir-opt %s | FileCheck %s -DWIDTH=32
// CHECK: i[[WIDTH]]                  // matches i32
```

### Reference table

<details><summary><b>Numeric capture formats <code>[[#%FMT,NAME:]]</code></b></summary>

| Format | Meaning |
|--------|---------|
| `%u` | unsigned decimal (default) |
| `%d` | signed decimal |
| `%x` / `%X` | hex lower / upper |
| `#` flag | require `0x` prefix |
| `.N` | minimum N digits, zero-padded |
</details>

➡️ Next: [Tutorial 5 — MLIR testing conventions](#tutorial-5--mlir-testing-conventions)

---

## Tutorial 5 — MLIR testing conventions

> Source: <https://mlir.llvm.org/getting_started/TestingGuide/> and
> <https://llvm.org/docs/TestingGuide.html>

lit + FileCheck are generic; this tutorial is how **MLIR** uses them. MLIR tests
fall into four kinds:

1. **Check tests** — transform IR with `mlir-opt`, FileCheck the result.
2. **Diagnostic tests** — assert the compiler emits a specific error/warning.
3. **Integration / runner tests** — execute lowered code, FileCheck its stdout.
4. **C++ unit tests** — googletest (not covered here).

### Check tests — the conventions

You've already run these (`cse.mlir`, `canonicalize.mlir`). The conventions to
internalize:

- **`CHECK-LABEL: func.func @name`** at every function — isolates blocks, clean
  failure locations.
- **Capture SSA values** with `%[[NAME:.*]]` / `%[[NAME]]` — never hardcode `%0`,
  `%1`; the compiler renumbers freely.
- **`CHECK-SAME:`** to spread a long signature across readable lines.
- Run a **minimal pipeline** (`-cse`, `-canonicalize`), not `-O3` — isolate one
  transformation.

In a real out-of-tree project you swap `mlir-opt` for your own `my-opt` driver;
the RUN/CHECK mechanics are identical (see
[`example/README.md`](example/README.md) → "Turning this into a real project").

### Diagnostic tests — `-verify-diagnostics`

These check that *invalid* input produces the *right* error. You annotate the IR
with `expected-*` directives and pass `-verify-diagnostics`; the run passes when
the emitted diagnostics match. Run the example's diagnostic test and watch the
authoring loop:

```bash
llvm-lit -v build/test --filter='invalid\.mlir'     # PASS
```

`example/test/invalid.mlir`:

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

Try editing one `expected-error` message to something wrong and re-running — lit
prints the *actual* diagnostic mlir-opt emitted, so you can copy a stable
fragment back. That's the normal authoring loop. Key pieces:

| Construct | Meaning |
|-----------|---------|
| `-verify-diagnostics` | Turn on diagnostic verification mode |
| `expected-error {{msg}}` | Expect an error **containing** `msg` (substring) on **this** line |
| `expected-warning` / `expected-remark {{...}}` | Same, for warnings / remarks |
| `expected-error @+1 {{...}}` | Diagnostic is on the line **1 below** the comment (`@-2`, `@above`, `@below` too) |
| `-split-input-file` + five-dash separator | Split the file into independent sub-tests |

The `{{...}}` is FileCheck-style regex *inside* the message, matched as a substring.

> **Gotcha:** `-split-input-file` splits on **any** line matching the five-dash
> separator — including one buried in a prose `//` comment. Keep that separator
> out of explanatory comments or you'll create a bogus extra sub-test.

> **Gotcha — unexpected notes:** if a test fails on `unexpected note:`, the
> compiler emitted a standalone `note:` (e.g. `prior use here`) that you must also
> annotate with `// expected-note {{...}}`. Notes attached to an error are
> consumed automatically; standalone ones are not.

### Integration / runner tests — execute and check stdout

The strongest signal: lower the IR all the way, **run it**, and FileCheck the
program's printed output.

```mlir
// RUN: mlir-opt %s --some-lowering-pipeline \
// RUN:   | mlir-runner -e main --entry-point-result=void \
// RUN:       --shared-libs=%mlir_runner_utils \
// RUN:   | FileCheck %s

func.func @main() {
  // ... compute and print something ...
  // CHECK: 42
  return
}
```

Here `// CHECK: 42` checks **runtime stdout**, not IR. These cost more (they build
and execute), so they're reserved for validating an entire lowering pipeline
end-to-end. Upstream examples live under `mlir/test/Integration/`.

➡️ Next: [Tutorial 6 — write your own test](#tutorial-6--write-your-own-test)

---

## Tutorial 6 — write your own test

Tests are discovered by their `.mlir` suffix, so adding one needs no CMake edit —
drop a file in `test/` and re-run. Here's a canonicalization test (`-(-x)` folds
back to `x`, so both `subi`s must vanish):

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

# Fast inner loop by hand, then the full suite picks it up automatically:
mlir-opt test/double_negate.mlir -canonicalize | FileCheck test/double_negate.mlir && echo PASS
./run.sh        # now reports 4 tests

# clean up — remove the test you just added:
rm test/double_negate.mlir
```

You just used `CHECK-LABEL` (block boundary), `CHECK-NOT` (a pattern that must
*not* appear), and a plain `CHECK` on a real transformation.

---

That's the whole pipeline: **lit discovers and runs**, **substitutions fill in
paths**, **the tool transforms or executes IR**, and **FileCheck verifies the
result structurally**. It's the same machinery behind every test in upstream
LLVM and MLIR. For the CMake + lit wiring and how to turn this into a real
out-of-tree project with your own `my-opt` driver, see
[`example/README.md`](example/README.md).

## Cheat sheet

| Goal | Command |
|------|---------|
| Configure + build + run all tests | `./run.sh` |
| Configure only (generate `build/` + lit config) | `./run.sh configure` |
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

---

## Appendix: setup and troubleshooting

The [Setup](#setup) section gives the one-line happy path. This appendix is the
fallback: pointing the example at your LLVM, the lit-runner story, putting tools
on `PATH`, and fixing common errors.

### What you need

A prebuilt **LLVM/MLIR** that provides three things:

| Tool | Role | Always present? |
|------|------|-----------------|
| `mlir-opt` | the compiler driver under test | yes |
| `FileCheck` | the output pattern matcher | yes |
| a lit runner (`llvm-lit` **or** `lit`) | the test runner | see below |

That's the *only* prerequisite. The standalone `example/` project reuses these
prebuilt binaries — it does **not** build LLVM. `./run.sh clean` removes the
build directory; `./run.sh configure` stops after generating `build/` and the lit
config.

### Pointing run.sh at your LLVM

`run.sh` finds MLIR automatically, in this order:

1. an explicit `MLIR_DIR` you export,
2. a from-source build at `../../../externals/llvm-project/build`,
3. whatever `llvm-config` on your `PATH` points at (e.g. Homebrew's `llvm@20`).

Override it explicitly when needed:

```bash
MLIR_DIR=/path/to/your/llvm-build/lib/cmake/mlir ./run.sh
# Homebrew:  MLIR_DIR=$(brew --prefix llvm@20)/lib/cmake/mlir ./run.sh
```

### About the lit runner

A *from-source* LLVM build ships a runner named **`llvm-lit`**. An *installed*
LLVM — Homebrew's `llvm@20` included — does **not**: it ships lit's engine but
not the `llvm-lit` wrapper name.

This is not a problem. The `lit` PyPI/Homebrew package is the same tool under a
different name. Both `run.sh` and `scripts/try.sh` fall back automatically:

1. use `llvm-lit` if on `PATH`, else
2. use `lit` if on `PATH` (`brew install lit`), else
3. bootstrap `lit` into a private `example/.lit-venv/` on first run.

So a missing `llvm-lit` never blocks you. Set `LLVM_EXTERNAL_LIT=/path/to/lit`
to force a specific runner.

### Putting the tools on your PATH

The tutorials and `scripts/try.sh` invoke `mlir-opt`, `FileCheck`, and `llvm-lit`
directly. To do that yourself, put the tool directory on your `PATH`. From the
`example/` directory:

```bash
# From-source build (ships llvm-lit):
export PATH="$PWD/../../../externals/llvm-project/build/bin:$PATH"
# Homebrew instead:
export PATH="$(brew --prefix llvm@20)/bin:$PATH"

# Sanity check — mlir-opt and FileCheck must resolve; at least one lit runner should:
which mlir-opt FileCheck
which llvm-lit || which lit
```

`scripts/try.sh` does this for you and auto-detects the toolchain; override with
`LLVM_BIN=/path/to/llvm-build/bin scripts/try.sh`.

### Troubleshooting

**macOS / Homebrew: "llvm-lit not found".** After `brew install llvm@20`, the
sanity check shows `mlir-opt` and `FileCheck` resolving but `llvm-lit` missing:

```text
$ which mlir-opt FileCheck llvm-lit
/opt/homebrew/opt/llvm@20/bin/mlir-opt
/opt/homebrew/opt/llvm@20/bin/FileCheck
llvm-lit not found
```

This is expected, not an error — `run.sh`/`try.sh` fall back to `lit` (see
[About the lit runner](#about-the-lit-runner)), so you can ignore it. If you
specifically want the literal `llvm-lit …` commands to work in your own shell,
install `lit` and expose it under that name:

```bash
brew install lit
ln -sf "$(brew --prefix lit)/bin/lit" /opt/homebrew/bin/llvm-lit
which llvm-lit            # -> /opt/homebrew/bin/llvm-lit
```

The symlink points at Homebrew's stable `opt/` path, so it survives
`brew upgrade lit`. (If you later install the full `brew install llvm`, it ships
its own `llvm-lit`; remove this symlink first to avoid a link conflict.)

**"could not locate MLIR's CMake package".** `run.sh` couldn't find any of its
three MLIR locations. Point it at yours: `MLIR_DIR=/path/to/lib/cmake/mlir ./run.sh`.
The path must contain `MLIRConfig.cmake` (from-source: `build/lib/cmake/mlir`;
Homebrew: `$(brew --prefix llvm@20)/lib/cmake/mlir`).

**Tests don't get discovered / "0 tests".** The `check` target runs lit over the
**generated** config in `example/build/test/lit.site.cfg.py`. If you edited
configs or moved files, reconfigure from scratch: `./run.sh clean && ./run.sh`. A
new `.mlir` file is auto-discovered by its suffix (no CMake edit), but you must
re-run so lit re-scans the directory.

**`mlir-opt` / `FileCheck` "command not found".** You skipped the `PATH` export —
see [Putting the tools on your PATH](#putting-the-tools-on-your-path), or just let
`scripts/try.sh` set it up for you.

## References

- **lit** — <https://llvm.org/docs/CommandGuide/lit.html>
- **FileCheck** — <https://llvm.org/docs/CommandGuide/FileCheck.html>
- **LLVM Testing Guide** — <https://llvm.org/docs/TestingGuide.html>
- **MLIR Testing Guide** — <https://mlir.llvm.org/getting_started/TestingGuide/>
