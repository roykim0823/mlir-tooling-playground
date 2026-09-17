# Test-case reduction — `mlir-reduce` and `llvm-reduce`

You have a 3000-line module that makes a pass crash, miscompile, or emit the
wrong thing. Before you can debug it (or file a bug) you want the *smallest*
input that still shows the symptom. **Reducers** do that mechanically: you give
them the input and a script that answers "does this candidate still show the
symptom?", and they delete as much as they can while the answer stays yes.

MLIR has `mlir-reduce` for MLIR files and LLVM has `llvm-reduce` for LLVM IR.
Same idea, different tools, and — the first thing to know — **opposite
exit-code conventions** for the script.

To replay every command below:

```bash
./try.sh          # sections 2–6 as a transcript (section 1 has no commands)
./try.sh 3        # one section
```

Needs a prebuilt LLVM/MLIR with `mlir-opt`, `mlir-reduce`, `llvm-reduce`,
`opt`, `FileCheck` (`brew install llvm@20`; `try.sh` finds them via
`llvm-config`, or set `LLVM_BIN`). Section 5 uses the capstone's `toy-reduce`
and is skipped with a hint until
[`../../mlir-capstone/`](../../mlir-capstone/README.md) is
built. Commands below are as `try.sh` runs them, from [`examples/`](examples).

| # | Section |
|---|---|
| 1 | [The contract: an interestingness test](#1-the-contract-an-interestingness-test) |
| 2 | [`mlir-reduce` on a stock-dialect input](#2-mlir-reduce-on-a-stock-dialect-input) |
| 3 | [Reducing with optimization passes](#3-reducing-with-optimization-passes) |
| 4 | [Writing the interestingness test](#4-writing-the-interestingness-test) |
| 5 | [Your own dialect: `toy-reduce`](#5-your-own-dialect-toy-reduce) |
| 6 | [`llvm-reduce`](#6-llvm-reduce) |
| 7 | [From crash to lit test: the workflow](#7-from-crash-to-lit-test-the-workflow) |

---

## 1. The contract: an interestingness test

Both tools drive the same loop: *propose a smaller candidate → run your script
on it → keep it if the script says "still interesting" → repeat*. The script is
called the **interestingness test** (or *tester*). It receives the candidate
file's path as its **last argument** and must answer through its **exit code**:

| Tool | Flag | "Interesting" exit code | Not interesting |
|---|---|---|---|
| `mlir-reduce` | `-reduction-tree='... test=SCRIPT'` | **1** (any non-zero) | 0 |
| `llvm-reduce` | `--test=SCRIPT` | **0** | non-zero |

The two conventions really are opposite. Get one wrong and `llvm-reduce` says `Input isn't
interesting! Verify interesting-ness test` while `mlir-reduce` exits 1 with no
message and no output file (Section 2 shows both).

"Interesting" should mean **the specific symptom you are chasing** — an
assertion message, a wrong result, an op that should have been folded — not
just "the tool fails". Section 4 is about writing that script well.

## 2. `mlir-reduce` on a stock-dialect input

[`examples/crash.mlir`](examples/crash.mlir) has three functions; the story is
"canonicalize does something wrong around `arith.divui` in `@suspect`".
[`examples/interesting.sh`](examples/interesting.sh) encodes the symptom as
"after `-canonicalize`, `@suspect` still contains an `arith.divui`" and exits 1
when that holds:

```bash
./interesting.sh crash.mlir && echo 'exit 0 = NOT interesting' || echo 'exit 1 = interesting'
# exit 1 = interesting
```

Reduce. The **reduction tree** is `mlir-reduce`'s generic algorithm: it tries
erasing operations and keeps the smallest candidate the tester accepts.
`traversal-mode=0` is single-path (greedy); it is also the **only** mode
implemented in LLVM 20 — `1` and `2` fail with `unsupported traversal mode
detected`.

```bash
mlir-reduce crash.mlir -reduction-tree='traversal-mode=0 test=./interesting.sh' -o reduced.mlir 2>noise.txt
cat reduced.mlir
```
```mlir
module {
  func.func @suspect(%arg0: i32, %arg1: i32, %arg2: i32) -> i32 {
    %c2_i32 = arith.constant 2 : i32
    %0 = arith.addi %arg0, %arg1 : i32
    %1 = arith.subi %0, %arg2 : i32
    %2 = arith.divui %1, %c2_i32 : i32
    return %2 : i32
  }
}
```

Gone: both unrelated functions, the two dead ops, and the `x + 0`. Kept: the
chain the `divui` depends on (it feeds `return`, so nothing on it can be
erased). The result is deterministic — run it twice, diff, identical.

Some behaviour to expect:

- **stderr is noisy.** Each rejected candidate that fails the verifier prints
  an error (`null operand found`, `block with no terminator`). That is the
  reducer probing, not a problem with your input; redirect it.
- **No output file means the original was not interesting.** `mlir-reduce`
  exits 1 *silently* in that case. Always run the tester by hand on the
  original first (as above).
- The script path may be relative (`test=./interesting.sh`) or absolute; it is
  run from your current directory.
- What the generic reducer can do in this install: erase ops whose results are
  unused, erase whole functions, and forward an op's operand to its users. No
  upstream dialect ships the `DialectReductionPatternInterface` that would add
  smarter, dialect-specific rewrites, so for anything else you combine it with
  real passes — next section.

## 3. Reducing with optimization passes

`-opt-reduction-pass` runs an ordinary pass over the input and keeps the result
if the tester still says yes. It is the way to get *semantic* shrinking
(folding, DCE, symbol removal) rather than blind erasure:

```bash
mlir-reduce crash.mlir -opt-reduction-pass='opt-pass=canonicalize test=./interesting.sh' -o canon.mlir
```

Canonicalize alone removes the dead ops and the `x + 0` in every function but
keeps all three functions. Reduction passes form a **pipeline in the order
given**, so the usual recipe is passes first, then the tree:

```bash
mlir-reduce crash.mlir \
  -opt-reduction-pass='opt-pass=canonicalize test=./interesting.sh' \
  -reduction-tree='traversal-mode=0 test=./interesting.sh' -o both.mlir
```

**What blocks the tree.** [`examples/calls.mlir`](examples/calls.mlir) has a
`call` from `@suspect` to a private `@helper`, plus an unused private
`@unused_helper`. With a symbol reference in play the op-erasing reducer leaves
*all* functions alone, including the unused one:

```bash
mlir-reduce calls.mlir -reduction-tree='traversal-mode=0 test=./interesting.sh' -o t.mlir 2>/dev/null && grep func.func t.mlir
#   func.func private @helper(...)
#   func.func private @unused_helper(...)      <- not removed
#   func.func @suspect(...)
mlir-reduce calls.mlir -opt-reduction-pass='opt-pass=symbol-dce test=./interesting.sh' -o d.mlir 2>/dev/null && grep func.func d.mlir
#   func.func private @helper(...)
#   func.func @suspect(...)                    <- symbol-dce removed the unused private one
```

`symbol-dce` only removes *private* unused symbols; public functions stay by
definition. Any pass the tool knows can be named in `opt-pass=` (`mlir-reduce
--help` lists them); typical choices are `canonicalize`, `cse`, `symbol-dce`,
`inline`, `sccp`.

## 4. Writing the interestingness test

[`examples/interesting.sh`](examples/interesting.sh) in full:

```bash
#!/usr/bin/env bash
mlir-opt "$1" -canonicalize 2>/dev/null | FileCheck "$0" >/dev/null 2>&1 && exit 1
exit 0
# CHECK: func.func @suspect
# CHECK: arith.divui
```

Four habits that make a tester reliable:

1. **Check the symptom, not the failure.** `FileCheck` on the tool's output (or
   `grep` for the exact assertion text on stderr, `2>&1 | grep -q 'Assertion
   .*isa<'`) pins *your* bug. A bare "mlir-opt exited non-zero" test lets the
   reducer wander off to any input that fails for any reason — very often a
   parse error in a mangled candidate.
2. **Treat "does not parse" as not interesting.** Many candidates are invalid
   IR. `2>/dev/null` on the tool plus a pipeline into FileCheck means those
   fall through to `exit 0`. Without it, a candidate that fails to parse but
   happens to print the pattern in an error message could be accepted.
3. **Keep the CHECK lines in the script.** `FileCheck "$0"` reads them from the
   script itself, so the test is one self-contained file you can commit next
   to the reproducer. Everything the [lit track](../../lit-and-filecheck/README.md)
   teaches about directives applies.
4. **Parameterise with `test-arg`.** Extra arguments arrive *before* the
   candidate path. [`examples/interesting-arg.sh`](examples/interesting-arg.sh)
   takes the pattern from the command line:
   ```bash
   mlir-reduce crash.mlir -reduction-tree='traversal-mode=0 test=./interesting-arg.sh test-arg=arith.divui' -o out.mlir
   ```

Also: the script runs *hundreds* of times, so keep it fast (a single
`mlir-opt` invocation, no builds), and wrap tools that might hang in
`timeout`. Use tools from `PATH` or absolute paths — the reducer inherits your
environment but not your shell aliases.

## 5. Your own dialect: `toy-reduce`

Stock `mlir-reduce` only knows upstream dialects and, in LLVM 20, has no
`--load-dialect-plugin`. An out-of-tree dialect gets its own reducer exactly
the way it gets its own opt — `MlirReduceMain` plus a context that knows the
dialect. The capstone's [`tools/toy-reduce.cpp`](../../mlir-capstone/tools/toy-reduce.cpp):

```cpp
int main(int argc, char **argv) {
  toy::registerToyPasses();            // so -opt-reduction-pass='opt-pass=toy-fold ...' resolves
  mlir::registerTransformsPasses();    // canonicalize, cse, symbol-dce, ...
  mlir::DialectRegistry registry;
  registry.insert<toy::ToyDialect, mlir::func::FuncDialect>();
  mlir::MLIRContext context(registry);
  return mlir::failed(mlir::mlirReduceMain(argc, argv, context));
}
```

```cmake
add_llvm_executable(toy-reduce tools/toy-reduce.cpp)
target_link_libraries(toy-reduce PRIVATE MLIRToy MLIRReduceLib MLIRFuncDialect MLIRTransforms)
```

Its tester,
[`test/Inputs/interesting.sh`](../../mlir-capstone/test/Inputs/interesting.sh),
says "after `-toy-fold` a `toy.sub` remains":

```bash
toy-reduce ../../../mlir-capstone/test/reduce.mlir \
  -reduction-tree='traversal-mode=0 test=../../../mlir-capstone/test/Inputs/interesting.sh' -o toy.mlir
```
```mlir
module {
  func.func @suspect(%arg0: f64) -> f64 {
    %0 = toy.constant 3.000000e+00
    %1 = toy.constant 1.000000e+00
    %2 = toy.mul %arg0, %1
    %3 = toy.sub %2, %0
    %4 = toy.add %3, %arg0
    return %4 : f64
  }
}
```

The unrelated function and the dead `toy.mul` are gone. The same run is a lit
test, [`test/reduce.mlir`](../../mlir-capstone/test/reduce.mlir): a
`RUN:` line reduces into `%t` and a second one FileChecks it. The tester needs
`toy-opt`; it takes `$TOY_OPT`, then `toy-opt` on `PATH` (which `lit.cfg.py`
arranges), then the default `build/` next to the test tree — so it also works
when you run it by hand, as above. A tester that cannot find its tool fails
silently, and the reducer then reports every candidate as not interesting.

## 6. `llvm-reduce`

Same loop for LLVM IR (and MIR), **exit 0 = interesting**.
[`examples/big.ll`](examples/big.ll) and
[`examples/interesting-ll.sh`](examples/interesting-ll.sh): "instcombine keeps
a `udiv`":

```bash
./interesting-ll.sh big.ll && echo 'exit 0 = interesting'
llvm-reduce --test=./interesting-ll.sh big.ll -o reduced.ll
cat reduced.ll
```
```llvm
declare i32 @helper(i32)

define i32 @suspect(i32 %c) {
entry:
  %q = udiv i32 %c, 3
  %h = call i32 @helper(i32 %q)
  ret i32 0
}
```

This goes much further than `mlir-reduce`'s generic tree: it dropped
unused *arguments*, turned `@helper` into a declaration, and replaced the
return value with `0` — all through its built-in **delta passes**, which it
runs in sequence and logs on stderr:

```
*** Reducing Functions...
 **** SUCCESS | Saved new best reduction to reduced.ll
*** Reducing Function Bodies...
 ...
```

| Flag | Use |
|---|---|
| `-o FILE` | output (default: `reduced.ll` in the current directory) |
| `--print-delta-passes` | list the passes; `--delta-passes=functions,instructions` / `--skip-delta-passes=` to restrict |
| `--test-arg=X` | extra arguments for the script, passed before the file |
| `--ir-passes='...'` | run an `opt -passes` pipeline as a reduction step (the analogue of `-opt-reduction-pass`) |
| `--abort-on-invalid-reduction` | stop if a delta pass produced invalid IR (debugging the reducer itself) |
| `--in-place` | overwrite the input — the tool warns for a reason |

Why the divisor in `big.ll` is `3`: instcombine turns `udiv x, 2` into a
shift, so with `2` the *original* is not interesting and the run stops
immediately:

```bash
sed 's/udiv i32 %diff, 3/udiv i32 %diff, 2/' big.ll > pow2.ll
llvm-reduce --test=./interesting-ll.sh pow2.ll -o never.ll
# Input isn't interesting! Verify interesting-ness test
```

That message means the tester is wrong or the symptom is not what you think.
It is better to learn that immediately than after the reducer has run for an hour.

## 7. From crash to lit test: the workflow

1. **Capture.** A failing pipeline gives you the IR just before the failing
   pass with `--mlir-pass-pipeline-crash-reproducer=repro.mlir`
   ([debugging track](../debugging/README.md), Section 3). Strip the
   `{-# ... #-}` resource block or run it with `--run-reproducer`.
2. **Write the tester** around the exact symptom (Section 4), and check it
   returns "interesting" on the original.
3. **Reduce**: passes first, then the tree (Section 3). Iterate on the tester
   if the result is not what you meant.
4. **Turn it into a test.** The reduced file plus the CHECK lines from your
   tester are already most of a `.mlir` lit test
   ([lit track](../../lit-and-filecheck/README.md)): add a `RUN:` line and
   commit it next to the fix.

## References

- `mlir-reduce` — <https://mlir.llvm.org/docs/Tools/mlir-reduce/>
- `llvm-reduce` — <https://llvm.org/docs/CommandGuide/llvm-reduce.html>
- `DialectReductionPatternInterface` (dialect-specific reductions) — `mlir/Reducer/ReductionPatternInterface.h`
