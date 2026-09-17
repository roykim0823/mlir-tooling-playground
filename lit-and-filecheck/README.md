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
[7 split-file & custom substitutions](#tutorial-7--split-file-and-custom-substitutions) ·
[Cheat sheet](#cheat-sheet) ·
[Appendix: setup & troubleshooting](#appendix-setup-and-troubleshooting)

## Setup

You need a prebuilt LLVM/MLIR providing `mlir-opt`, `FileCheck`, and a lit runner.
That's all — the example finds the tools for you.

```bash
cd example
./run.sh
```

Expected tail: `Passed: 6 (100.00%)`.

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
-- Testing: 6 tests, 6 workers --
Testing Time: 0.26s
Total Discovered Tests: 4
  Passed: 6 (100.00%)
```

lit found six tests, ran each, and all passed. That's the whole loop.

### Step 2 — see what lit discovered, and why

```bash
llvm-lit --show-tests build/test
```

```
-- Available Tests --
  LIT_FILECHECK_EXAMPLE :: canonicalize.mlir
  LIT_FILECHECK_EXAMPLE :: cse.mlir
  LIT_FILECHECK_EXAMPLE :: filecheck_directives.mlir
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
- To assert a command **fails**, prefix it with LLVM's **`not`** utility, which
  inverts the exit code:
  `// RUN: not mlir-opt %s -pass-pipeline='…bogus…' 2>&1 | FileCheck %s --check-prefix=ERR`
  passes only when `mlir-opt` *rejects* the input, with FileCheck verifying the
  error message on stderr. (`not` ships with LLVM next to `FileCheck`; lit
  registers it as a substitution.) The `ERR` group of
  `test/filecheck_directives.mlir` uses exactly this pattern — Tutorial 3 runs it.
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

> **Gotcha — a prefix typo silently disables checks.** FileCheck only looks for
> the prefixes it is *told about*. Write `// AA: result_from_a` (or forget the
> `--check-prefix=A` flag) and that directive is never read — the test doesn't
> fail, it just stops checking anything, forever. When you author a prefixed
> check, make it fail once on purpose to prove the RUN line really reads it.
> (Same trap in reverse: a stray `--check-prefix` with zero matching directives
> is itself an error — FileCheck refuses to run with an empty check list.)

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

#### Watch the loophole on real IR — `test/filecheck_directives.mlir`

The danger `CHECK-LABEL` guards against deserves seeing once with your own
eyes: a plain `CHECK` may skip **any number of lines** on its way to a match —
including past the end of the function you meant to test. The committed
`test/filecheck_directives.mlir` is written in the standard upstream shape:
**one input file, several RUN pipelines**, each verified by its own group of
directives selected with `--check-prefix` (Tutorial 2 Step 5), the prefixes
named after the configuration they check:

```mlir
// RUN: mlir-opt %s | FileCheck %s
// RUN: mlir-opt %s -cse | FileCheck %s --check-prefix=CSE
// RUN: mlir-opt %s -canonicalize | FileCheck %s --check-prefix=CANON
// RUN: not mlir-opt %s -pass-pipeline='builtin.module(no-such-pass)' 2>&1 | FileCheck %s --check-prefix=ERR

func.func @dup_constants() -> (i32, i32) {
  %0 = arith.constant 1 : i32
  %1 = arith.constant 1 : i32
  return %0, %1 : i32, i32
}

func.func @add_zero(%arg0: i32) -> i32 {
  %c0 = arith.constant 0 : i32
  %0 = arith.addi %arg0, %c0 : i32
  return %0 : i32
}
```

Only the *second* function contains an `arith.addi` — and the first RUN
line's default `CHECK` group is **deliberately broken as a lesson**: it
claims `@dup_constants` contains one.

```mlir
// CHECK: func.func @dup_constants
// CHECK: arith.addi
```

Run it (from `example/`; `mlir-opt` with no pass flag just parses and
re-prints):

```bash
mlir-opt test/filecheck_directives.mlir \
  | FileCheck test/filecheck_directives.mlir
echo "exit: $?"        # -> 0. The bogus assertion PASSES.
```

After matching the `@dup_constants` line, FileCheck skipped over the rest of
that function, crossed the function boundary, and found `arith.addi` inside
`@add_zero`. A regression in `@dup_constants` would go completely unnoticed.
Now wrap the same bogus assertion in labels (inline check file, as in the
earlier steps):

```bash
mlir-opt test/filecheck_directives.mlir | FileCheck <(printf 'CHECK-LABEL: func.func @dup_constants\nCHECK: arith.addi\nCHECK-LABEL: func.func @add_zero\n')
```

(Note the *second* label: a block only ends at the next label, so with one
label alone the block would run to end-of-input and still leak into
`@add_zero`.)

```
error: CHECK: expected string not found in input
CHECK: arith.addi
       ^
<stdin>:2:26: note: scanning from here
 func.func @dup_constants() -> (i32, i32) {
                         ^
<stdin>:3:12: note: possible intended match here
 %c1_i32 = arith.constant 1 : i32
           ^
```

Now the bug is caught: the labels confine the check to `@dup_constants`'s
block, and the `possible intended match` hint even points at the culprit (a
`constant`, not an `addi`). This is the loophole-closing in action — and the
reason every real MLIR test starts each function with a `CHECK-LABEL`. The
committed `CSE` and `CANON` groups do exactly that, correctly: `CSE` proves
`-cse` collapses the duplicate constants (label + captures), `CANON` proves
`-canonicalize` folds `x + 0` away (label + `-SAME` + `-NOT`) — read them in
the file and you'll recognize every directive from this tutorial.

The fourth RUN line is the `not` utility from Tutorial 1 in its natural
habitat — testing the **error path**. `not` requires `mlir-opt` to *fail* on
the bogus pipeline, and `2>&1` routes its stderr into FileCheck, which
verifies the message:

```mlir
// RUN: not mlir-opt %s -pass-pipeline='builtin.module(no-such-pass)' 2>&1 | FileCheck %s --check-prefix=ERR
// ERR: 'no-such-pass' does not refer to a registered pass
```

This `not`-plus-`ERR` pattern is the standard LLVM idiom for locking in
"this must be rejected" behavior: unlike the `broken/` files, which live
outside `test/` because they fail, an *inverted expectation* is a green test.

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

For one more runnable example, the `CANON` group of
`test/filecheck_directives.mlir` (Tutorial 3's demo file) shows the other
canonical placement of a capture: a `CHECK-LABEL` can't define variables, so
the `-SAME` continuation captures `%[[ARG]]` from the signature line, and the
group asserts `-canonicalize` folds `x + 0` into returning that same argument:

```mlir
// CANON-LABEL: func.func @add_zero(
// CANON-SAME: %[[ARG:.*]]: i32
// CANON-NOT: arith.addi
// CANON: return %[[ARG]]
```

```bash
mlir-opt test/filecheck_directives.mlir -canonicalize \
  | FileCheck test/filecheck_directives.mlir --check-prefix=CANON && echo PASS
```

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
[`example/README.md`](example/README.md) → "Turning this into a real project",
and [`../mlir-capstone/test/`](../mlir-capstone) for a
working suite that drives the out-of-tree `toy-opt` built in that directory).

### Diagnostic tests — `-verify-diagnostics`

> The flags that control how diagnostics *look* when you are not testing them
> (`--mlir-print-op-on-diagnostic`, `--mlir-print-stacktrace-on-diagnostic`,
> verbosity) are in [`../mlir-tools/debugging/`](../mlir-tools/debugging/README.md), Section 4.

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
> (`-split-input-file` is an `mlir-opt` feature for diagnostics. To put several
> standalone inputs for *any* tool in one file, use LLVM's `split-file` —
> Tutorial 7.)

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

### Step 1 — write one by hand

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
./run.sh        # now reports 7 tests
```

You just used `CHECK-LABEL` (block boundary), `CHECK-NOT` (a pattern that must
*not* appear), and a plain `CHECK` on a real transformation.

### Step 2 — draft exhaustive checks with `generate-test-checks.py`

The checks above are *loose*: they pin down two facts and ignore everything
else. Real MLIR lowering tests often pin down the **entire** output — every op,
every operand, every SSA value captured and cross-referenced. Writing 35
lines of captures by hand is not realistic, so LLVM ships an authoring aid,
`mlir/utils/generate-test-checks.py`. Be precise about how it
relates to FileCheck, because the two are easy to conflate:

- **FileCheck is a verifier that runs every time the test runs.** Input: the
  pass's actual output + your `CHECK` directives. Output: an exit code. It
  generates nothing.
- **`generate-test-checks.py` is a generator that runs once, at authoring
  time.** Input: one concrete output of your pass. Output: a **draft** of the
  `CHECK` lines for you to review and paste in. It verifies nothing, never runs
  at test time, and leaves no trace — FileCheck neither knows nor cares that
  the directives were generated.

So the division of labor is: the *script* writes a first draft once;
*FileCheck* enforces it forever after.

The script lives in LLVM's *source tree*, not in installed toolchains
(Homebrew's `llvm@20` doesn't ship it). It is a single self-contained Python
file, so this repo carries a copy at
[`scripts/generate-test-checks.py`](scripts/generate-test-checks.py) (from the
`llvmorg-20.1.8` tag, Apache-2.0 with LLVM exceptions, unmodified apart from a
provenance note at the top). If you prefer the upstream file:

```bash
curl -sLo /tmp/generate-test-checks.py \
  https://raw.githubusercontent.com/llvm/llvm-project/release/20.x/mlir/utils/generate-test-checks.py
```

Feed it the pass output for the test from Step 1 (from `example/`):

```bash
mlir-opt test/double_negate.mlir -canonicalize | python3 ../scripts/generate-test-checks.py
```

```
// NOTE: Assertions have been autogenerated by utils/generate-test-checks.py

// The script is designed to make adding checks to
// a test case fast, it is *not* designed to be authoritative
// about what constitutes a good test! The CHECK should be
// minimized and named to reflect the test intent.

// CHECK-LABEL:   func.func @double_negate(
// CHECK-SAME:                             %[[VAL_0:.*]]: i32) -> i32 {
// CHECK:           return %[[VAL_0]] : i32
// CHECK:         }
```

Everything from Tutorials 3–4 is in the draft: a `CHECK-LABEL` on the
signature, a `CHECK-SAME` continuation *carrying the argument capture* (a
label can't hold captures, so the script moved it to the next line), and `%[[VAL_0]]`
reused to assert the returned value is the function's argument. The intended
workflow is:

```
run the pass  →  pipe output through generate-test-checks.py
              →  REVIEW the draft: trim what's incidental,
                 rename VAL_0, VAL_1, … to meaningful names
              →  paste into the test file
              →  from now on, lit + FileCheck enforce it on every run
```

The script's own disclaimer is the important part: the draft is a starting
point, not a finished test. Machine names like `VAL_0` say nothing about
intent — rename them (`ARG`, `RESULT`, …) so a human can read the assertion.
And trim: the draft asserts *everything* the pass printed, including details
your test doesn't care about.

**Loose vs. exhaustive is a judgment call.** Exhaustive checks catch more
regressions; loose checks survive harmless changes to the pass's output. The
trap with exhaustive checks is that regenerating them is so cheap that when
one breaks, it's tempting to "fix" the test by regenerating *without reading
the diff* — which silently bakes a genuine regression into the expected
output. If you regenerate, diff the old and new checks and convince yourself
every change is intended.

```bash
# clean up — remove the test you added in Step 1:
rm test/double_negate.mlir
```

➡️ Next: [Tutorial 7 — split-file and custom substitutions](#tutorial-7--split-file-and-custom-substitutions)

---

## Tutorial 7 — split-file and custom substitutions

Two lit features that upstream tests use constantly and that turn "one test =
one file = one tool" into something more flexible. Both are wired into the
example: `test/split_file.mlir` and `test/custom_subst.mlir`.

### Step 1 — several standalone inputs in one file: `split-file`

Sometimes a test wants *independent* inputs: three small modules that must be
processed separately, or two valid cases next to one that must fail to
parse. `-split-input-file` (Tutorial 5) only helps for diagnostics, and only
inside `mlir-opt`. LLVM's **`split-file`** tool is the general answer: it cuts
a file at `//--- NAME` markers and writes each part to a directory.

```mlir
// RUN: split-file %s %t
// RUN: mlir-opt %t/cse.mlir -cse | FileCheck %t/cse.mlir
// RUN: mlir-opt %t/canon.mlir -canonicalize | FileCheck %t/canon.mlir
// RUN: not mlir-opt %t/bad.mlir 2>&1 | FileCheck %t/bad.mlir

//--- cse.mlir
// CHECK-LABEL: func.func @dup
func.func @dup() -> (i32, i32) { ... }

//--- canon.mlir
// CHECK-LABEL: func.func @times_one
func.func @times_one(%x: i32) -> i32 { ... }

//--- bad.mlir
// CHECK: error: use of value '%b' expects different type than prior uses: 'i32' vs 'i64'
func.func @bad(%a: i32, %b: i64) -> i32 { %0 = arith.addi %a, %b : i32 ... }
```

How to read it:

- `%t` is the per-test temp path; `split-file` **creates it as a directory**
  and writes `%t/cse.mlir`, `%t/canon.mlir`, `%t/bad.mlir`.
- Text **before the first marker is discarded** — so the RUN lines live there
  and never end up inside a part.
- Each part is a complete file: it carries its **own** `CHECK` lines and is
  passed to *both* `mlir-opt` and `FileCheck` by its own path (`%t/cse.mlir`),
  not `%s`. FileCheck never sees the other parts' checks, so no prefixes are
  needed.
- The third part is a **parse error on purpose**: `not` inverts `mlir-opt`'s
  exit code and FileCheck pins the diagnostic. In a single-module file this
  case could not coexist with the valid ones.

```bash
llvm-lit -v build/test --filter='split_file\.mlir'
ls build/test/Output/split_file.mlir.tmp/        # cse.mlir  canon.mlir  bad.mlir
```

Markers take the file's comment leader (`//---` here, `;---` for LLVM IR,
`#---` for Python/asm); `split-file --leading-lines` keeps line numbers aligned
with the original by padding each part with blank lines, which makes
diagnostics point at the right line of the *combined* file.

### Step 2 — your own `%{name}` substitutions

`%s`, `%t`, and the tool names are substitutions lit performs on every RUN line
(Tutorial 1). A suite can define its own. In `test/lit.cfg.py`:

```python
config.substitutions.append(("%{canon}", "mlir-opt %s -canonicalize"))
config.substitutions.append(("%{canon-generic}", "%{canon} --mlir-print-op-generic"))
config.recursiveExpansionLimit = 3
```

and in `test/custom_subst.mlir`:

```mlir
// RUN: %{canon} | FileCheck %s
// RUN: %{canon-generic} | FileCheck %s --check-prefix=GENERIC
```

The braces are the modern spelling (`%{name}`); they avoid the prefix clashes
bare `%name` tokens suffer from. What they buy you:

- **One place to change a pipeline.** If every lowering test starts with the
  same six flags, put them in `%{lower}` and change them once.
- **Hide paths and tools.** Upstream configs define things like `%{python}`
  and `%{mlir_runner_utils}`; a site config can point them at build-specific
  locations without touching tests.

Two rules apply, and breaking either shows up in the failure output:

1. **A replacement may contain other substitutions** (`%s` inside `%{canon}`)
   — lit walks its substitution list in order, once. For a substitution that
   expands to *another custom* substitution (`%{canon-generic}` → `%{canon}`)
   set **`config.recursiveExpansionLimit`**; without it `%{canon}` stays
   literal and the RUN line fails with `%{canon}: command not found`.
2. **Register substitutions after `use_default_substitutions()`** so the
   standard ones (`%s`, `FileCheck`, …) exist, and keep names unique — lit
   will happily replace `%{canon}` inside `%{canon-generic}` textually if you
   let the names overlap.

```bash
llvm-lit -a build/test --filter='custom_subst\.mlir'     # -a shows the expanded RUN lines even on PASS
```

Look for `RUN: at line 12:` in the output (the second RUN line of the file):
the nested token has become a full
`mlir-opt <path> -canonicalize --mlir-print-op-generic` command.

---

That's the whole pipeline: **lit discovers and runs**, **substitutions fill in
paths**, **the tool transforms or executes IR**, and **FileCheck verifies the
result structurally**. It's the same machinery behind every test in upstream
LLVM and MLIR. For the CMake + lit wiring and how to turn this into a real
out-of-tree project with your own `my-opt` driver, see
[`example/README.md`](example/README.md); the
[`mlir-capstone/`](../mlir-capstone/README.md) build
does exactly that with its `toy-opt` tool and `test/` suite.

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
| Assert a RUN command *fails* | prefix it with `not`: `... \| not FileCheck %s --check-prefix=BAD` (`not --crash` for "must crash") |
| Draft exhaustive CHECK lines | `mlir-opt FILE -pass \| python3 ../scripts/generate-test-checks.py` (Tutorial 6) |
| Several inputs in one test file | `split-file %s %t`, then `mlir-opt %t/NAME.mlir … \| FileCheck %t/NAME.mlir` (Tutorial 7) |
| Suite-wide shorthand for a pipeline | `config.substitutions.append(("%{name}", "..."))` in `lit.cfg.py`; `config.recursiveExpansionLimit` for nesting (Tutorial 7) |

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

### Pointing run.sh at your LLVM, and the lit runner

Both of these are `run.sh`'s job, and they're documented next to the script in
[`example/README.md`](example/README.md#using-a-different-llvmmlir). The short
version:

- `run.sh` finds MLIR automatically (an explicit `MLIR_DIR`, then a from-source
  build at `../../../externals/llvm-project/build`, then `llvm-config` on your
  `PATH`). Override with `MLIR_DIR=/path/to/lib/cmake/mlir ./run.sh`.
- A missing `llvm-lit` never blocks you: an *installed* LLVM (Homebrew
  included) doesn't ship it, so `run.sh` and `scripts/try.sh` fall back to the
  `lit` package (`brew install lit`), bootstrapping it into a private
  `example/.lit-venv/` on first run if needed. Set
  `LLVM_EXTERNAL_LIT=/path/to/lit` to force a specific runner.

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
[the section above](#pointing-runsh-at-your-llvm-and-the-lit-runner)), so you
can ignore it. If you
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
