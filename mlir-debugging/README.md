# Debugging & introspection — seeing what `mlir-opt` (and your own `*-opt`) is doing

Every MLIR tool built on `MlirOptMain` — stock `mlir-opt`, and the capstone's
`toy-opt` — carries a set of flags for looking *inside* a run: print the IR
between passes, switch printing modes, get a reproducer when a pass fails,
time the pipeline, and control diagnostics. The official docs list them in
several places; this tutorial runs each one on a small input and shows what
comes out. A second, shorter part does the same for TableGen and PDLL.

Every command in this file is replayed by one script:

```bash
./try.sh          # all seven sections, as a transcript
./try.sh 3        # one section
```

Only a prebuilt LLVM/MLIR is needed (`brew install llvm@20`; `try.sh` finds it
through `llvm-config`, or set `LLVM_BIN=/path/to/bin`). Lines that use the
capstone's `toy-opt` are skipped with a hint unless
[`../mlir-tablegen/capstone-toy/`](../mlir-tablegen/capstone-toy/README.md)
has been built. Commands below are written as `try.sh` runs them, from the
[`examples/`](examples) directory.

| # | Section | Flags |
|---|---|---|
| 1 | [Watching a pipeline](#1-watching-a-pipeline) | `--mlir-print-ir-{before,after}[-all]`, `-after-change`, `--mlir-print-ir-module-scope`, `--mlir-print-ir-tree-dir`, `--dump-pass-pipeline`, `--list-passes`, `--show-dialects` |
| 2 | [Reading the IR you get](#2-reading-the-ir-you-get) | `--mlir-print-op-generic`, `--mlir-print-debuginfo`, `--mlir-pretty-debuginfo`, `--mlir-print-value-users`, `--mlir-elide-elementsattrs-if-larger`, `--mlir-print-unique-ssa-ids`, `--mlir-print-local-scope`, `--mlir-print-skip-regions` |
| 3 | [When a pass fails](#3-when-a-pass-fails) | `--mlir-print-ir-after-failure`, `--mlir-pass-pipeline-crash-reproducer`, `--mlir-pass-pipeline-local-reproducer`, `--run-reproducer`, `--mlir-generate-reproducer`, `--verify-each`, `--verify-roundtrip` |
| 4 | [Diagnostics](#4-diagnostics) | `--mlir-print-op-on-diagnostic`, `--mlir-print-stacktrace-on-diagnostic`, `--mlir-diagnostic-verbosity-level`, `-verify-diagnostics` |
| 5 | [Timing and statistics](#5-timing-and-statistics) | `--mlir-timing`, `--mlir-timing-display`, `--mlir-pass-statistics`, `--mlir-disable-threading` |
| 6 | [TableGen and PDLL introspection](#6-tablegen-and-pdll-introspection) | `llvm-tblgen --print-records / --print-detailed-records / --dump-json`, `mlir-tblgen --print-records`, `mlir-pdll -x=ast` |
| 7 | [What needs a debug build](#7-what-needs-a-debug-build) | `-debug`, `-debug-only=`, statistics |

The inputs: [`examples/pipeline.mlir`](examples/pipeline.mlir) (duplicate
constants and `x * 1.0`, so `-cse` and `-canonicalize` both change it, with
explicit `loc(...)`s), [`examples/big_constant.mlir`](examples/big_constant.mlir)
(a dense tensor constant), [`examples/invalid.mlir`](examples/invalid.mlir)
(fails the verifier).

---

## 1. Watching a pipeline

**Print after every pass.** The single most used flag. Output goes to
**stderr**, so it survives `-o /dev/null`:

```bash
mlir-opt pipeline.mlir -cse -canonicalize --mlir-print-ir-after-all -o /dev/null
```
```
// -----// IR Dump After CSE (cse) //----- //
module {
  func.func @compute(%arg0: f64) -> f64 {
    %cst = arith.constant 1.000000e+00 : f64
    %cst_0 = arith.constant 0.000000e+00 : f64
    %0 = arith.mulf %arg0, %cst : f64
    %1 = arith.addf %0, %0 : f64
    ...
// -----// IR Dump After Canonicalizer (canonicalize) //----- //
module {
  func.func @compute(%arg0: f64) -> f64 {
    %cst = arith.constant 0.000000e+00 : f64
    %0 = arith.addf %arg0, %arg0 : f64
    ...
```

Variants:

| Flag | Prints |
|---|---|
| `--mlir-print-ir-before=<pass-arg>` / `--mlir-print-ir-after=<pass-arg>` | around one named pass (`--mlir-print-ir-before=canonicalize`) |
| `--mlir-print-ir-before-all` | before every pass |
| `--mlir-print-ir-after-all --mlir-print-ir-after-change` | after a pass **only if it changed the IR** — a *modifier* for `-after-all`, useless on its own. `-cse -cse` prints one dump, not two. |
| `--mlir-print-ir-after-failure` | only for a pass that failed (Section 3) |

**Scope.** A pass nested on `func.func` prints only its function. To always see
the whole module add `--mlir-print-ir-module-scope`, which requires
`--mlir-disable-threading` (the printer must not race other functions' passes):

```bash
mlir-opt pipeline.mlir -pass-pipeline='builtin.module(func.func(cse))' --mlir-print-ir-after-all -o /dev/null
# // -----// IR Dump After CSE (cse) //----- //
# func.func @compute(%arg0: f64) -> f64 {
mlir-opt pipeline.mlir -pass-pipeline='builtin.module(func.func(cse))' --mlir-print-ir-after-all \
         --mlir-print-ir-module-scope --mlir-disable-threading -o /dev/null
# // -----// IR Dump After CSE (cse) ('func.func' operation: @compute) //----- //
# module {
```

**To files instead of the terminal**, one per pass, in a tree mirroring the op
nesting — indispensable for long pipelines:

```bash
mlir-opt pipeline.mlir -cse -canonicalize --mlir-print-ir-after-all --mlir-print-ir-tree-dir=/tmp/tree -o /dev/null
find /tmp/tree -type f
# /tmp/tree/builtin_module_no-symbol-name/0_cse.mlir
# /tmp/tree/builtin_module_no-symbol-name/1_canonicalize.mlir
```

**What pipeline is actually running?** `--dump-pass-pipeline` prints it in
the textual form `-pass-pipeline` accepts, with every option spelled out —
copy it to reproduce a run exactly:

```bash
mlir-opt pipeline.mlir -cse -canonicalize --dump-pass-pipeline -o /dev/null
# Pass Manager with 2 passes:
# builtin.module(cse,canonicalize{  max-iterations=10 max-num-rewrites=-1 region-simplify=normal test-convergence=false top-down=true})
```

**What is registered?** `--show-dialects` and `--list-passes` answer "why
does my tool not parse `x.y`" and "what is this pass called":

```bash
mlir-opt --show-dialects              # Available Dialects: acc,affine,amdgpu,...
mlir-opt --list-passes | grep -A3 -- '--canonicalize'
toy-opt --show-dialects               # Available Dialects: builtin,func,toy
toy-opt --list-passes | grep -A2 -- '--toy-fold'
```

Both also confirm that a **plugin** loaded (the capstone builds one, see its
README section 4): the dialect and the pass appear in stock `mlir-opt`'s lists.

```bash
mlir-opt --load-dialect-plugin=../../mlir-tablegen/capstone-toy/build/ToyPlugin.dylib --show-dialects | tr ',' '\n' | grep toy
mlir-opt --load-pass-plugin=../../mlir-tablegen/capstone-toy/build/ToyPlugin.dylib --list-passes | grep -A1 -- '--toy-fold'
```

## 2. Reading the IR you get

These change *how* IR is printed, on the final output and on every dump above.

```bash
mlir-opt pipeline.mlir --mlir-print-op-generic | head -6
```
```
module {
  "func.func"() <{function_type = (f64) -> f64, sym_name = "compute"}> ({
  ^bb0(%arg0: f64):
    %0 = "arith.constant"() <{value = 1.000000e+00 : f64}> : () -> f64
```

**Generic form** bypasses every `assemblyFormat` / custom printer: what you
see is exactly the operation's name, operands, properties, attributes, and
types. Reach for it when a custom format hides something, when the pretty form
fails to *parse* back, and whenever you write a `-verify-diagnostics` test for
a verifier (a hand-written op in generic form is how `invalid.mlir` gets a type
mismatch past the parser).

```bash
mlir-opt pipeline.mlir -cse --mlir-print-debuginfo
mlir-opt pipeline.mlir -cse --mlir-print-debuginfo --mlir-pretty-debuginfo
```
```
    %cst = arith.constant 1.000000e+00 : f64 loc(#loc3)        # debuginfo: aliases, defined at the bottom
    %cst = arith.constant 1.000000e+00 : f64 pipeline.mlir:7:9 # + pretty: inline file:line:col
```

Locations survive transformations (CSE kept the *first* constant's location),
which makes `--mlir-print-debuginfo` the way to find out *which* source op a
result came from.

```bash
mlir-opt big_constant.mlir --mlir-print-value-users
```
```
    %cst = arith.constant dense<[1, 2, 3, 4, 5, 6, 7, 8]> : tensor<8xi32> // users: %2, %1
    %1 = arith.addi %cst, %cst : tensor<8xi32> // users: %3, %2
    %2 = arith.muli %cst, %1 : tensor<8xi32> // user: %3
    return %1, %2 : tensor<8xi32>, tensor<8xi32> // id: %3
```

| Flag | Effect | When |
|---|---|---|
| `--mlir-print-value-users` | comment on each op listing who uses its results (ops without results get an `id`) | "who keeps this value alive?" |
| `--mlir-elide-elementsattrs-if-larger=N` | prints `dense_resource<__elided__>` for constants with more than N elements | dumping models with big weights |
| `--mlir-print-unique-ssa-ids` | numbers values uniquely across regions instead of restarting `%0` per region | diffing dumps |
| `--mlir-print-local-scope` | no `#loc`/`#map` aliases; everything inline | grepping a dump |
| `--mlir-print-skip-regions` | `module {...}` — op headers only | huge modules |

## 3. When a pass fails

A pass fails by calling `signalPassFailure()`; the pass manager then stops and
`mlir-opt` exits 1. To have something that fails deterministically we ask the
canonicalizer to prove convergence in a single iteration on IR that needs
more than one:

```bash
mlir-opt pipeline.mlir -canonicalize='max-iterations=1 test-convergence=true' -o /dev/null
# exit 1, no diagnostic — the pass simply failed
```

**See the IR the pass left behind:**

```bash
mlir-opt pipeline.mlir -cse -canonicalize='max-iterations=1 test-convergence=true' --mlir-print-ir-after-failure -o /dev/null
# // -----// IR Dump After Canonicalizer Failed (canonicalize) //----- //
# module { ... }
```

**Get a reproducer.** A `.mlir` file holding the IR *as it was before the
failing pass* plus the pipeline, embedded as an external resource:

```bash
mlir-opt pipeline.mlir -cse -canonicalize='max-iterations=1 test-convergence=true' \
         --mlir-pass-pipeline-crash-reproducer=/tmp/crash.mlir -o /dev/null
# pipeline.mlir:0:0: error: Failures have been detected while processing an MLIR pass pipeline
# pipeline.mlir:0:0: note: Pipeline failed while executing [`Canonicalizer` on 'builtin.module' operation]: reproducer generated at `/tmp/crash.mlir`
```
```mlir
{-#
  external_resources: {
    mlir_reproducer: {
      pipeline: "builtin.module(cse, canonicalize{  max-iterations=1 ... test-convergence=true top-down=true})",
      disable_threading: false,
      verify_each: true
    }
  }
#-}
```

Replay it with `--run-reproducer` — no need to remember the flags:

```bash
mlir-opt /tmp/crash.mlir --run-reproducer -o /dev/null      # exit 1 again
```

`--mlir-pass-pipeline-local-reproducer` shrinks the pipeline to the failing
pass only (here `cse` is dropped). It requires `--mlir-disable-threading`;
without it the tool aborts with `Local crash reproduction can't be setup on a
pass-manager without disabling multi-threading first`.

```bash
mlir-opt pipeline.mlir -cse -canonicalize='max-iterations=1 test-convergence=true' \
         --mlir-pass-pipeline-crash-reproducer=/tmp/local.mlir --mlir-pass-pipeline-local-reproducer --mlir-disable-threading -o /dev/null
grep 'pipeline:' /tmp/local.mlir
#       pipeline: "builtin.module(canonicalize{  max-iterations=1 ... test-convergence=true top-down=true})",
```

`--mlir-generate-reproducer=<file>` writes the same kind of file for a run
that did **not** fail — a handy way to hand someone "this input, this
pipeline" as one file. A reproducer is also the natural input for
**shrinking** the failing case down: see the
[`mlir-reduce/`](../mlir-reduce/README.md) track.

**Catch bad IR early.** `--verify-each` runs the verifier after every pass
(default on in `mlir-opt`; `--verify-each=false` to skip). `--verify-roundtrip`
additionally prints the IR after parsing and parses it back, catching
printer/parser mismatches in your dialect's `assemblyFormat`s.

## 4. Diagnostics

`invalid.mlir` fails the verifier. By default MLIR attaches the offending op as
a note:

```bash
mlir-opt invalid.mlir
```
```
invalid.mlir:5:8: error: 'arith.addi' op requires the same type for all operands and results
  %0 = "arith.addi"(%a, %b) : (i32, i64) -> i32
       ^
invalid.mlir:5:8: note: see current operation: %0 = "arith.addi"(%arg0, %arg1) <{overflowFlags = #arith.overflow<none>}> : (i32, i64) -> i32
```

| Flag | Effect |
|---|---|
| `--mlir-print-op-on-diagnostic=false` | drop the `see current operation` note (quieter logs; the note is *generic* form, so it can be long) |
| `--mlir-print-stacktrace-on-diagnostic` | add a note with the C++ stack at the `emitError` — finds *which pass or verifier* emitted a message |
| `--mlir-diagnostic-verbosity-level=errors\|warnings\|remarks` | filter what is shown; `errors` hides the capstone's `-toy-fold=report=true` remark |
| `-verify-diagnostics` | turn diagnostics into a **test**: pass iff every emitted diagnostic matches an `expected-error @+1 {{...}}` line and vice versa (the lit track covers this) |

```bash
mlir-opt invalid.mlir --mlir-print-stacktrace-on-diagnostic 2>&1 | head -8
# ...
# invalid.mlir:5:8: note: diagnostic emitted with trace:
#  #0 ... llvm::sys::PrintStackTrace(...)
#  #1 ... emitDiag(mlir::Location, mlir::DiagnosticSeverity, llvm::Twine const&)
#  #2 ... mlir::Operation::emitError(llvm::Twine const&)
mlir-opt invalid.mlir -verify-diagnostics && echo matched      # exit 0: the error was expected
```

## 5. Timing and statistics

```bash
mlir-opt pipeline.mlir -cse -canonicalize --mlir-timing -o /dev/null
```
```
===-------------------------------------------------------------------------===
                         ... Execution time report ...
===-------------------------------------------------------------------------===
  Total Execution Time: 0.0005 seconds

  ----Wall Time----  ----Name----
    0.0002 ( 29.8%)  Parser
    0.0000 (  2.8%)  CSE
    0.0000 (  0.0%)    (A) DominanceInfo
    0.0000 (  4.6%)  Canonicalizer
    0.0000 (  8.5%)  Output
    0.0003 ( 54.3%)  Rest
    0.0005 (100.0%)  Total
```

The default display is a **tree** following the pipeline (analyses are
indented under the pass that ran them, marked `(A)`);
`--mlir-timing-display=list` flattens and sorts by time. Works in release
builds — this is the tool for "which pass is slow".

`--mlir-pass-statistics` prints per-pass counters, but only in LLVM builds where
`llvm::Statistic` is compiled in (Section 7); on Homebrew's release build the
report is empty for every pass.

`--mlir-disable-threading` is not a debugging flag by itself, but three things
above need it (`--mlir-print-ir-module-scope`, the local reproducer) or become
deterministic with it (the order of per-function dumps and diagnostics).

## 6. TableGen and PDLL introspection

TableGen questions ("what does this class expand to?", "which records exist?")
are answered without any backend: **`llvm-tblgen` reads MLIR `.td` files too**,
and has three dump modes that `mlir-tblgen` lacks (it only has
`--print-records`). Run from `examples/`, on the capstone's dialect:

```bash
MLIR=/opt/homebrew/opt/llvm@20/include
TOY=../../mlir-tablegen/capstone-toy/include          # -I for `include "Toy/ToyInterfaces.td"`
TD=$TOY/Toy/ToyOps.td

llvm-tblgen --print-records -I $MLIR -I $TOY $TD | sed -n '/^def AddOp {/,/^}/p'     # the fully-resolved record
```
```
def AddOp {	// Op Toy_Op
  Dialect opDialect = Toy_Dialect;
  string opName = "add";
  string cppNamespace = "::toy";
  string summary = "f64 addition";
  ...
  dag arguments = (ins F64:$lhs, F64:$rhs);
  dag results = (outs F64:$result);
  string assemblyFormat = "$lhs `,` $rhs attr-dict";
  list<Trait> traits = [Pure, anonymous_359];
  ...
}
```

`--print-detailed-records` adds **where each field was set** — the fastest
way to learn which default you are inheriting from `OpBase.td`:

```
AddOp  |ToyOps.td:84|
  Superclasses: (Op) Toy_Op
  Fields:
    Dialect opDialect = Toy_Dialect  |OpBase.td:325|
    string summary = "f64 addition"  |ToyOps.td:85|
```

`--dump-json` gives every record as JSON, for `jq` or Python:

```bash
llvm-tblgen --dump-json -I $MLIR -I $TOY $TD | jq '.AddOp | {opName, summary, traits: [.traits[].def], assemblyFormat}'
# { "opName": "add", "summary": "f64 addition", "traits": ["Pure", "anonymous_359"], "assemblyFormat": "$lhs `,` $rhs attr-dict" }
llvm-tblgen --dump-json -I $MLIR -I $TOY $TD | jq -r 'to_entries[] | select(.value | type == "object" and (.["!superclasses"] // [] | index("Op"))) | .key'
# AddOp ConstantOp MulOp PrintOp SubOp
```

(`anonymous_359` is the `DeclareOpInterfaceMethods<...>` instance from the
interfaces track — anonymous records get numbered names.)

For PDLL, `mlir-pdll -x=ast` shows how the frontend parsed a pattern
(`-x=mlir`, the PDL it compiles to, is in the [PDLL track](../mlir-pdll/README.md)):

```bash
mlir-pdll -x=ast -I $MLIR -I $TOY $TOY/Toy/ToyPatterns.pdll | grep -A4 'PatternDecl'
#  |-PatternDecl 0x... Name<FoldMulConstants>
#  | `-CompoundStmt 0x...
#  |   |-LetStmt 0x...
#  |   | `-VariableDecl 0x... Name<root> Type<Op<toy.mul>>
```

## 7. What needs a debug build

Some of the most talked-about flags do not exist in a release LLVM, Homebrew's
included. `LLVM_DEBUG(...)` blocks and `llvm::Statistic` compile to nothing
without assertions:

```bash
mlir-opt pipeline.mlir -canonicalize -debug-only=greedy-rewriter -o /dev/null
# mlir-opt: Unknown command line argument '-debug-only=greedy-rewriter'.
mlir-opt pipeline.mlir -cse --mlir-pass-statistics -o /dev/null
# ... Pass statistics report ...   (empty)
```

| Flag | What it gives you in an assertions build |
|---|---|
| `-debug` | every `LLVM_DEBUG` line in the whole tool — far too much |
| `-debug-only=greedy-rewriter` | each pattern tried/applied/failed by the greedy driver (`applyPatternsGreedily`, i.e. `-canonicalize` and the capstone's `-toy-fold`) |
| `-debug-only=dialect-conversion` | the legalization log of `applyPartialConversion` / `applyFullConversion`: which op was illegal, which pattern matched, why it was rolled back |
| `-debug-only=pattern-logging-listener` | (LLVM ≥ 20) which pattern created/replaced/erased which op |
| `--mlir-pass-statistics` | the counters declared with `Statistic<...>` in a pass's `.td` (see the [passes track](../mlir-tablegen/passes/README.md)) |
| `--debug-counter` / `--mlir-debug-counter` | bisect: skip the first N and run only M applications of a counted action |

To get them, build LLVM/MLIR from source with
`-DLLVM_ENABLE_ASSERTIONS=ON` (statistics alone can be had with
`-DLLVM_FORCE_ENABLE_STATS=ON`, and a `RelWithDebInfo` + assertions build is
the usual developer configuration). Until then, Sections 1–5 cover most of the
same ground: `--mlir-print-ir-after-all` instead of `-debug-only=greedy-rewriter`,
the capstone's `report` remark instead of a statistic.

## References

- Pass infrastructure: IR printing, reproducers, timing — <https://mlir.llvm.org/docs/PassManagement/#pass-instrumentation>
- Diagnostics — <https://mlir.llvm.org/docs/Diagnostics/>
- Debugging tips (upstream) — <https://mlir.llvm.org/getting_started/Debugging/>
- TableGen backends & `--dump-json` — <https://llvm.org/docs/TableGen/BackEnds.html#json-reference>
- Related tracks: [`lit-and-filecheck/`](../lit-and-filecheck/README.md) (turning diagnostics into tests), [`mlir-tablegen/passes/`](../mlir-tablegen/passes/README.md) (declaring the statistics and options these flags show)
