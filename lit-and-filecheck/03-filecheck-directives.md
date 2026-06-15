# Chapter 3 — FileCheck directives

> Source: <https://llvm.org/docs/CommandGuide/FileCheck.html>

Beyond the plain `CHECK:`, FileCheck has directives that express *relationships*
between matches: adjacency, sameness, ordering-freedom, negation, counting, and
block boundaries. All use the form `PREFIX-DIRECTIVE: pattern`.

## 3.1 `CHECK-NEXT:` — the very next line

Matches only if the pattern is on the line **immediately after** the previous
match (exactly one newline between, no skipped lines).

```mlir
// CHECK-LABEL: func.func @simple_constant
// CHECK-NEXT: arith.constant      // must be the line right after the func line
```

Use it to assert there is *nothing* between two lines. `CHECK-NEXT` cannot be
the first directive (there's no "previous" match to anchor to).

## 3.2 `CHECK-SAME:` — same line as previous

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

## 3.3 `CHECK-NOT:` — must not appear

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

## 3.4 `CHECK-COUNT-<n>:` — repeated matches

Matches the pattern exactly `n` times, on consecutive matches.

```mlir
// CHECK-COUNT-4: vector.load     // expect exactly four loads in a row
```

## 3.5 `CHECK-DAG:` — order-independent matches

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

## 3.6 `CHECK-EMPTY:` — a blank line

Asserts the next line exists and is **empty**. (You can't do this with `CHECK:`
because an empty pattern matches anything.) Cannot be the first directive.

```mlir
// CHECK: ; end of section
// CHECK-EMPTY:
// CHECK-NEXT: ; next section
```

## 3.7 `CHECK-LABEL:` — block boundaries / resync points

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

## 3.8 Putting the directives together

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

## Try it

> Shortcut: `scripts/try-03.sh` runs everything below automatically.

With the tools on your `PATH` (see [setup](README.md#setup-do-this-once)), from
`tutorials/lit-and-filecheck/`:

```bash
# Inspect the real output, then watch the directives match it:
mlir-opt example/test/cse.mlir -cse | FileCheck example/test/cse.mlir --dump-input=fail && echo PASS
```

Experiment: in `example/test/cse.mlir`, change a `CHECK-NEXT:` to point at a line
that *isn't* actually adjacent (e.g. duplicate it), rerun, and read how the
diagnostic changes. Then revert.

➡️ Next: [Chapter 4 — FileCheck variables](04-filecheck-variables.md)
