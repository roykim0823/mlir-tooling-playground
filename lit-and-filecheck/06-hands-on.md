# Chapter 6 — hands-on

Time to use everything against the standalone [`example/`](example/) project.

> Shortcut: `scripts/try-06.sh` runs all six labs automatically (it backs up and
> restores the files Labs 4–5 touch, so it's safe to re-run).

Run each block from `tutorials/lit-and-filecheck/`. First build once:

```bash
cd example
./run.sh
export PATH="$PWD/../../../externals/llvm-project/build/bin:$PATH"   # adjust to your LLVM build
```

`./run.sh` printed `Passed: 3 (100.00%)` and created `example/build/` with the
generated `lit.site.cfg.py`.

## Lab 1 — run a single test three ways

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

## Lab 2 — read a failure

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

## Lab 3 — break a captured variable

This shows captures are real bindings, not decoration:

```bash
# Temporarily point one use at an undefined variable:
sed 's/%\[\[RESULT\]\], %\[\[RESULT\]\]/%[[RESULT]], %[[OTHER]]/' test/cse.mlir > /tmp/cse_broken.mlir
mlir-opt test/cse.mlir -cse | FileCheck /tmp/cse_broken.mlir
```

FileCheck reports an **undefined variable** `OTHER` — proving the second use was
genuinely tied to the first definition.

## Lab 4 — write a new test (no CMake edit needed)

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

## Lab 5 — add a diagnostic case

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

## Lab 6 — clean up

```bash
rm -f test/double_negate.mlir /tmp/out.mlir /tmp/bad.check /tmp/cse_broken.mlir
git -C ../../.. checkout -- tutorials/lit-and-filecheck/example/test/invalid.mlir 2>/dev/null || true
./run.sh clean
```

## Cheat sheet

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
