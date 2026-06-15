# Chapter 4 — patterns and variables

> Source: <https://llvm.org/docs/CommandGuide/FileCheck.html>

This is what makes FileCheck powerful: a pattern can contain **regexes**,
**captured string variables**, and **numeric variables with arithmetic**. This
is how a test asserts *structure* ("the result of this op feeds that op")
without hardcoding compiler-chosen names.

## 4.1 Fixed strings vs regex

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

## 4.2 String variables — define and reuse

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

### The canonical MLIR idiom

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

## 4.3 Numeric variables

For numbers you can capture, constrain, and do arithmetic. Syntax centers on the
`[[# ... ]]` form.

### Capture a number

```mlir
// CHECK: load r[[#REG:]]        // capture the number after r into REG
// CHECK: load r[[#REG+1]]       // require the next load uses REG+1
```

### Capture with an explicit format

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

### Substitute / compute

```mlir
// CHECK: [[#ADDR+7]]               // the value ADDR plus 7
// CHECK: [[#%x, ADDR + 16]]        // formatted as hex
```

Expressions support `+`, `-`, and functions `add()`, `sub()`, `mul()`, `div()`,
`min()`, `max()`.

### Combined define + constraint

```mlir
// CHECK: offset [[#%x,OFFSET:0x10]]  // capture OFFSET, also require it equals 0x10
```

## 4.4 The `@LINE` pseudo-variable

`@LINE` is the line number of the current `CHECK` directive; `@LINE+N` / `@LINE-N`
offset it. Indispensable for diagnostic tests where an error message embeds a
line number:

```mlir
// CHECK: error at line [[# @LINE + 2]]
// (string form also works: [[@LINE]], [[@LINE-1]])
```

In MLIR diagnostic tests you'll more often use the `@+1` form on the
`expected-error` directive itself (Chapter 5) — same idea, different tool.

## 4.5 Command-line defines: `-D`

Inject a variable value from the RUN line, so one check file works for several
runs:

```mlir
// RUN: mlir-opt %s | FileCheck %s -DWIDTH=32
// CHECK: i[[WIDTH]]
```

Numeric form: `-D#FMT,NAME=EXPR`.

## Try it

> Shortcut: `scripts/try-04.sh` runs everything below automatically.

With the tools on your `PATH` (see [setup](README.md#setup-do-this-once)), from
`tutorials/lit-and-filecheck/`:

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

➡️ Next: [Chapter 5 — MLIR testing conventions](05-mlir-testing.md)
