# PDLL — MLIR's pattern language (`mlir-pdll`)

**PDLL** is MLIR's dedicated language for writing rewrite patterns. It is the
third way to express a pattern, next to hand-written C++ `RewritePattern`s and
TableGen [DRR](../drr): a small, purpose-built language with its
own compiler, **`mlir-pdll`**, and its own LSP server. Where DRR generates C++
that is compiled into your library, PDLL compiles to **PDL** — a dialect of
MLIR *IR that describes patterns* — which the pattern rewrite driver compiles
to bytecode and interprets at runtime.

```
ToyPatterns.pdll ──mlir-pdll -x=mlir──► pdl.pattern IR      (inspect / test)
                 ──mlir-pdll -x=cpp ──► C++ embedding it    (link into your dialect library)
                                              │
                          RewritePatternSet::add<...>  ─freeze─►  pdl → pdl_interp → bytecode
                                                                  interpreted by the greedy driver
```

> PDLL has its own language server, `mlir-pdll-lsp-server` (hover shows the
> ODS summary of an `op<...>`, completion knows operand names). The
> [`../../mlir-tools/lsp/`](../../mlir-tools/lsp/README.md) track shows how to run it and wire
> it into an editor.
>
> Every lesson here mirrors one in [`../drr/`](../drr):
> same toy dialect, same rewrites, the other language. Read them side by side.
> The [capstone](../../mlir-capstone) then runs a DRR pattern and a
> PDLL pattern in the **same** pass.

## Prerequisites

An LLVM/MLIR install with `mlir-pdll` and the MLIR `.td` includes (e.g.
`brew install llvm@20`; the lessons target **MLIR 20**). MLIR must be built with
`MLIR_ENABLE_PDL_IN_PATTERNMATCH` (the default) for PDL patterns to run.

```bash
MLIR=/opt/homebrew/opt/llvm@20
$MLIR/bin/mlir-pdll --help | grep -- '-x='
```

## Running the lessons

`mlir-pdll` takes one `.pdll` and an output kind:

| Flag | Output | Use it to |
|---|---|---|
| `-x=mlir` | the **PDL dialect IR** the pattern compiles to | see exactly what will be matched/built; test with FileCheck |
| `-x=cpp` | **C++** with one `struct : PDLPatternModule` per pattern + `populateGeneratedPDLLPatterns()` | include into your dialect library |
| `-x=ast` | the parsed AST | debug the frontend's view of your file |

```bash
MLIR=/opt/homebrew/opt/llvm@20
$MLIR/bin/mlir-pdll -x=mlir 1-basics/01_basic_pattern.pdll
$MLIR/bin/mlir-pdll -x=cpp  -I $MLIR/include -I . 2-constraints/02_constraints.pdll
#                            ^^^^^^^^^^^^^^^^^^^^^ Lessons 2-5 #include "ToyOps.td"
./gen-all.sh                 # both forms for every lesson -> generated/
```

Lessons 2–5 `#include` [`ToyOps.td`](ToyOps.td), a shared ODS file with the
same toy ops the DRR lessons define. `-I $MLIR/include` is for the `OpBase.td`
that file pulls in; `-I .` is for the file itself.

## Table of Contents

| # | Lesson | Source | DRR counterpart |
|---|---|---|---|
| 1 | [A first pattern](#lesson-1--a-first-pattern) | `1-basics/01_basic_pattern.pdll` | `Pat<(AddOp (MulOp $a,$b), $c), (FmaOp ...)>` |
| 2 | [Constraints & ODS names](#lesson-2--constraints--ods-names) | `2-constraints/02_constraints.pdll` | `Constraint<CPred<...>>`, `ConstantAttr` |
| 3 | [Native rewrites](#lesson-3--native-rewrites) | `3-native-code/03_native_code.pdll` | `NativeCodeCall` |
| 4 | [Multiple results, auxiliary ops, erase](#lesson-4--multiple-results-auxiliary-ops-erase) | `4-multi-result/04_multi_result.pdll` | `Pattern<..., [...]>`, `$dm__1`, `NativeCodeCallVoid` |
| 5 | [DRR directives, PDLL style](#lesson-5--drr-directives-pdll-style) | `5-directives-and-types/05_directives.pdll` | `replaceWithValue`, `either`, `returnType`, `addBenefit` |
| — | [From `.pdll` to a running pass](#from-pdll-to-a-running-pass) | capstone | — |
| — | [DRR vs PDLL vs C++](#drr-vs-pdll-vs-c) | | |

The shape of every pattern:

```pdll
Pattern Name with benefit(N) {      // `with benefit` optional
  // MATCH section: `let` bindings and constraint calls
  let x = op<dialect.name>(operands...) {attr = ...} -> (result types...);
  let root = op<...>(x, ...);
  SomeConstraint(x);
  // REWRITE section: exactly one of
  replace root with <op or values>;
  rewrite root with { ...statements...; };
  erase root;
}
```

---

## Lesson 1 — A first pattern

*Source: `1-basics/01_basic_pattern.pdll` — no ODS needed*

```pdll
// DRR:  def : Pat<(AddOp (MulOp $a, $b), $c), (FmaOp $a, $b, $c)>;
Pattern FuseMulAdd {
  let mul = op<toy.mul>(a: Value, b: Value);   // `name: Value` declares + binds
  let root = op<toy.add>(mul, c: Value);       // `mul` here = all its results
  replace root with op<toy.fma>(a, b, c);      // result types inferred from root
}

// DRR:  def : Pat<(AddOp $x, $x), (MulTwoOp $x)>;
Pattern AddSelf {
  let root = op<toy.add>(x: Value, x);         // same name twice = same value
  replace root with op<toy.mul_two>(x);
}
```

`-x=mlir` shows what it compiles to — every `let` is a `pdl.*` op, the
rewrite section is a `rewrite` region (locations stripped here):

```mlir
pdl.pattern @FuseMulAdd : benefit(0) {
  %0 = operand
  %1 = operand
  %2 = types
  %3 = operation "toy.mul"(%0, %1 : !pdl.value, !pdl.value) -> (%2 : !pdl.range<type>)
  %4 = results of %3
  %5 = operand
  %6 = types
  %7 = operation "toy.add"(%4, %5 : !pdl.range<value>, !pdl.value) -> (%6 : !pdl.range<type>)
  rewrite %7 {
    %8 = operation "toy.fma"(%0, %1, %5 : !pdl.value, !pdl.value, !pdl.value)
    replace %7 with %8
  }
}
```

Two rules are already visible. The root is the op the `rewrite` region is
attached to, and an op created directly as the replacement needs no result
types, because PDL takes them from the root. `-x=cpp` wraps that same IR in a class:

```cpp
struct FuseMulAdd : ::mlir::PDLPatternModule {
  template <typename... ConfigsT>
  FuseMulAdd(::mlir::MLIRContext *context, ConfigsT &&...configs)
    : ::mlir::PDLPatternModule(::mlir::parseSourceString<::mlir::ModuleOp>(
R"mlir(pdl.pattern @FuseMulAdd : benefit(0) { ... })mlir", context), ...) {}
};
template <typename... ConfigsT>
static void populateGeneratedPDLLPatterns(::mlir::RewritePatternSet &patterns, ConfigsT &&...configs) {
  patterns.add<FuseMulAdd>(patterns.getContext(), configs...);
  patterns.add<AddSelf>(patterns.getContext(), configs...);
}
```

## Lesson 2 — Constraints & ODS names

*Source: `2-constraints/02_constraints.pdll`*

`#include "ToyOps.td"` teaches PDLL the ops' **names**: results (`mul.res`),
attributes (`{value = v}`), and every ODS constraint (`F64Attr`, `F64`, …)
becomes a PDLL constraint.

```pdll
#include "ToyOps.td"

// NATIVE constraint: C++ body, must return success(). `rewriter` is in scope.
// DRR:  def HasOneUse : Constraint<CPred<"$0.hasOneUse()">, "...">;
Constraint HasOneUse(v: Value) [{ return success(v.hasOneUse()); }];

// DRR:  def : Pat<(AddOp (MulOp:$mul $a, $b), $c), (FmaOp $a, $b, $c), [(HasOneUse $mul)]>;
Pattern FuseMulAddOneUse with benefit(2) {
  let mul = op<toy.mul>(a: Value, b: Value);
  HasOneUse(mul.res);                          // constraint = a statement
  let root = op<toy.add>(mul.res, c: Value);
  replace root with op<toy.fma>(a, b, c);
}

// ATTRIBUTE literal + replace-with-existing-value
// DRR:  def : Pat<(MulOp $x, (ConstantOp ConstantAttr<F64Attr, "1.0">)), (replaceWithValue $x)>;
Pattern MulByOne {
  let root = op<toy.mul>(x: Value, op<toy.constant> {value = attr<"1.0 : f64">});
  replace root with x;
}

// TYPE constraint on a value
Pattern AddF64Only {
  let root = op<toy.add>(x: Value<type<"f64">>, y: Value<type<"f64">>);
  replace root with op<toy.fma>(x, y, x);
}

// ODS constraint reused: binds v AND checks it is an f64 attribute
Pattern ScaleByConstant {
  let c = op<toy.constant> {value = v: F64Attr};
  let root = op<toy.mul>(x: Value, c.res);
  replace root with op<toy.scale>(x) {factor = v};
}
```

In the PDL output, native constraints become `apply_native_constraint` and
literal types/attributes become constrained `pdl.type` / `pdl.attribute` ops:

```mlir
// AddF64Only
%0 = type : f64
%1 = operand : %0
// ScaleByConstant
%1 = attribute
apply_native_constraint "F64Attr"(%1 : !pdl.attribute)
```

The ODS constraint travelled all the way: `-x=cpp` emits a
`F64AttrPDLFn(PatternRewriter&, Attribute)` derived from the TableGen predicate
and calls `registerConstraintFunction("F64Attr", F64AttrPDLFn)` on the pattern.

## Lesson 3 — Native rewrites

*Source: `3-native-code/03_native_code.pdll`*

DRR's `NativeCodeCall` only *names* a C++ function you write elsewhere. A PDLL
`Rewrite` can carry the body:

```pdll
// DRR:  def NegateF64Attr : NativeCodeCall<"negateF64Attr($_builder, $0)">;
Rewrite NegateF64Attr(a: Attr) -> Attr [{
  return rewriter.getF64FloatAttr(-llvm::cast<FloatAttr>(a).getValueAsDouble());
}];

// DRR:  def : Pat<(NegOp (ConstantOp $value)), (ConstantOp (NegateF64Attr $value))>;
Pattern NegConst {
  let root = op<toy.neg>(op<toy.constant> {value = v: Attr});
  replace root with op<toy.constant> {value = NegateF64Attr(v)};   // called like a function
}

Rewrite MakeZeroF64() -> Attr [{ return rewriter.getF64FloatAttr(0.0); }];

Pattern SubSelf {                                   // x - x -> 0.0
  let root = op<toy.sub>(x: Value, x);
  replace root with op<toy.constant> {value = MakeZeroF64()};
}

// EXTERNAL: declared here, implemented + registered in C++ at runtime
Rewrite LogRewrite(op: Op);

Pattern NegNeg {                                    // neg(neg x) -> x, logged
  let root = op<toy.neg>(op<toy.neg>(x: Value));
  rewrite root with {
    LogRewrite(root);
    replace root with x;
  };
}
```

Notes:

- **Result types.** The new `toy.constant` has none written, and none are
  needed: an op created *directly* as the replacement takes its result types
  from the root at rewrite time (the capstone's `FoldMulConstants` relies on
  this and its lit test proves it). Ops built as intermediates *do* need
  `-> (types)`; Lesson 4 shows how to bind them from the root with
  `-> (t: Type)`. `mlir-pdll` warns when an intermediate op's types are left
  to be inferred and the op lacks `InferTypeOpInterface`.
- **`rewrite root with { ... }`** is a block of statements executed in order;
  it must end up replacing or erasing the root (or modifying it in place via a
  native rewrite, Lesson 5).
- **External** natives (`Rewrite LogRewrite(op: Op);`, no body) compile to a
  bare `apply_native_rewrite "LogRewrite"`. Provide the function from C++:

  ```cpp
  patterns.getPDLPatterns().registerRewriteFunction(
      "LogRewrite", [](PatternRewriter &rewriter, Operation *op) { llvm::errs() << *op << "\n"; });
  ```

  Inline bodies (`[{ ... }]`) are registered for you by the generated C++.

## Lesson 4 — Multiple results, auxiliary ops, erase

*Source: `4-multi-result/04_multi_result.pdll`*

```pdll
// DRR:  def : Pattern<(DivModOp $a, $b), [(DivOp $a, $b), (RemOp $a, $b)]>;
Pattern SplitDivMod {
  let root = op<toy.divmod>(a: Value, b: Value) -> (q: Type, r: Type);
  rewrite root with {
    let div = op<toy.div>(a, b) -> (q);
    let rem = op<toy.rem>(a, b) -> (r);
    replace root with (div, rem);               // result #0 <- div, #1 <- rem
  };
}

// DRR:  def : Pattern<(UseOp $x), [(DivModOp:$dm $x, $x), (UseOp $dm__1)]>;
Pattern UseRemainder {
  let root = op<toy.use>(x: Value);
  rewrite root with {
    let dm = op<toy.divmod>(x, x) -> (type<"i64">, type<"i64">);  // auxiliary: types required
    replace root with op<toy.use>(dm.r);        // ODS name instead of $dm__1
  };
}

Constraint HasNoUses(v: Value) [{ return success(v.use_empty()); }];
Pattern EraseDeadDiv {
  let root = op<toy.div>;                       // operands unconstrained
  HasNoUses(root.q);
  erase root;
}

// DRR:  def CopyAttrs : NativeCodeCallVoid<"copyAttrs($0, $1)">;   (supplemental)
Rewrite CopyAttrs(from: Op, to: Op);
Pattern DivToRemKeepAttrs {
  let root = op<toy.div>(a: Value, b: Value) -> (t: Type);
  rewrite root with {
    let rem = op<toy.rem>(a, b) -> (t);
    CopyAttrs(root, rem);
    replace root with rem;
  };
}
```

Where DRR needs the `Pattern` class, `$sym__N` indices and a separate
*supplemental* list, PDLL uses one `rewrite` block with ordinary statements.

## Lesson 5 — DRR directives, PDLL style

*Source: `5-directives-and-types/05_directives.pdll`*

| DRR directive | PDLL |
|---|---|
| `(replaceWithValue $x)` | `replace root with x;` |
| `(either A, B)` | **no equivalent** — write both operand orders as two patterns |
| `(returnType $x)` / `(returnType "...")` | `-> (t)` on the created op, with `t` bound from the match or a `type<"...">` literal |
| `(addBenefit N)` | `Pattern P with benefit(N)` |

```pdll
Pattern DropIdentity {                         // replaceWithValue
  let root = op<toy.identity>(x: Value);
  replace root with x;
}
Pattern AddConstLeft {                         // either: pattern #1
  let root = op<toy.add>(op<toy.constant> {value = c: Attr}, x: Value);
  replace root with op<toy.scale>(x) {factor = c};
}
Pattern AddConstRight {                        // either: pattern #2
  let root = op<toy.add>(x: Value, op<toy.constant> {value = c: Attr});
  replace root with op<toy.scale>(x) {factor = c};
}
Pattern RoundViaCast {                         // returnType
  let root = op<toy.round>(x: Value) -> (t: Type);
  rewrite root with {
    let c = op<toy.cast>(x) -> (t);            // auxiliary: type given
    replace root with op<toy.mul_two>(c.res);  // direct replacement: inferred
  };
}
Pattern IdentityToMulTwo with benefit(10) {    // addBenefit
  let root = op<toy.identity>(x: Value);
  replace root with op<toy.mul_two>(x);
}
```

And two things DRR cannot express:

```pdll
// WILDCARD root: op<> matches any op. You can't rebuild an op you can't name,
// so modify it in place through a native rewrite.
Rewrite ReplaceOperandWith(root: Op, old: Value, new: Value) [{
  rewriter.modifyOpInPlace(root, [&] { root->replaceUsesOfWith(old, new); });
}];
Pattern BypassIdentityOperand {
  let ident = op<toy.identity>(x: Value);
  let root = op<>(ident.res);
  rewrite root with { ReplaceOperandWith(root, ident.res, x); };
}

// Free-standing typed `let` with an initializer
Pattern ScaleByOneIsIdentity {
  let one: Attr = attr<"1.0 : f64">;
  let root = op<toy.scale>(x: Value) {factor = one};
  replace root with x;
}
```

## From `.pdll` to a running pass

The [capstone](../../mlir-capstone/README.md) runs
[`ToyPatterns.pdll`](../../mlir-capstone/include/Toy/ToyPatterns.pdll)
next to its DRR pattern inside the `-toy-fold` pass. The four pieces:

1. **CMake** — `add_mlir_pdll_library` runs `mlir-pdll -x=cpp` with the
   directory's include paths as `-I`, so `#include "Toy/ToyOps.td"` resolves:
   ```cmake
   add_mlir_pdll_library(ToyPdllIncGen include/Toy/ToyPatterns.pdll include/Toy/ToyPdllPatterns.h.inc)
   add_mlir_dialect_library(MLIRToy ... DEPENDS ToyPdllIncGen
     LINK_LIBS PUBLIC MLIRParser MLIRPDLDialect MLIRPDLInterpDialect MLIRRewrite ...)
   ```
2. **Populate** — include the generated header and call its function next to
   the DRR one (`lib/ToyPatterns.cpp`):
   ```cpp
   #include "Toy/ToyPdllPatterns.h.inc"
   populateWithGenerated(patterns);           // DRR
   populateGeneratedPDLLPatterns(patterns);   // PDLL
   ```
3. **Dialects** — the PDL IR is *parsed* (needs `pdl`) and *compiled* when the
   set is frozen (needs `pdl_interp`), so the pass declares both as
   `dependentDialects` in `ToyPasses.td`; a hand-rolled driver loads them itself.
4. **Test** — `test/fold.mlir` has `@mul_fold_pdll`, `@mul_by_one_pdll`, and
   `@mixed_drr_pdll`, where a PDLL fold feeds a DRR fold in one greedy run.

## DRR vs PDLL vs C++

| | DRR (TableGen) | PDLL | C++ `RewritePattern` |
|---|---|---|---|
| Compiled to | C++ `RewritePattern` subclasses | PDL IR → `pdl_interp` bytecode, **interpreted** | native code |
| Native code | `NativeCodeCall` names an external C++ function | inline `[{ }]` bodies *or* external declarations | everything |
| ODS awareness | full (it *is* TableGen) | via `#include` of the `.td` | via generated op classes |
| Result types | inferred, or `returnType` | inferred for the direct replacement, else `-> (…)` | explicit |
| Commutative match | `either` | two patterns | code |
| Regions / control flow | no | no | yes |
| Wildcard op | no | `op<>` | yes |
| Tooling | TableGen LSP | `mlir-pdll-lsp-server`, `-x=ast/mlir` | clangd |
| Runtime cost | none beyond C++ | bytecode interpretation; pattern compile at freeze | none |

**When to use which.** DRR when the pattern is a pure DAG-to-DAG rewrite and
you already live in TableGen. PDLL when the pattern needs light native logic,
wildcards, or you want to inspect/test the pattern as IR; it also plays with
other PDL producers (the Transform dialect's `pdl_match`). Hand-written C++
when the match involves regions, control flow, or non-local reasoning.

## References

- PDLL language reference — <https://mlir.llvm.org/docs/PDLL/>
- PDL dialect (what PDLL compiles to) — <https://mlir.llvm.org/docs/Dialects/PDLOps/>
- PDL interpreter dialect — <https://mlir.llvm.org/docs/Dialects/PDLInterpOps/>
- The DRR lessons these mirror — [`../drr/`](../drr/README.md)
