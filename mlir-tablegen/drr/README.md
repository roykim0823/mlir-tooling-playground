# DRR — Table-driven Declarative Rewrite Rules

**DRR** is MLIR's TableGen-based way to *rewrite IR*. You write a **source
pattern** (the IR to match) and a **result pattern** (the IR to build) as
TableGen DAGs, and `mlir-tblgen --gen-rewriters` turns each rule into a C++
`RewritePattern` (collected into a `populateWithGenerated(RewritePatternSet&)`).

> DRR is the MLIR analog of LLVM's SelectionDAG instruction-selection patterns
> (`--gen-dag-isel`). It **builds on ODS**: a pattern's DAG operators *are* the
> ops defined in [`../ods/`](../ods), so each lesson here defines a small `toy`
> dialect first. Required include: `mlir/IR/PatternBase.td`.

DRR is sugar — it emits the same `OpRewritePattern` C++ you could hand-write.
When a transform needs real logic, you escape to C++ via `NativeCodeCall`
(Lesson 3); for anything DRR can't express (regions, complex matching), you drop
to a hand-written pattern or PDL.

## Table of Contents

- 1 — [Basic rewrite patterns (`Pat`)](#lesson-1--basic-rewrite-patterns-pat) · `1-basics/`
- 2 — [Constraints](#lesson-2--constraints) · `2-constraints/`
- 3 — [NativeCodeCall: escaping to C++](#lesson-3--nativecodecall-escaping-to-c) · `3-native-code/`
- 4 — [Multi-result ops, auxiliary ops, supplemental patterns](#lesson-4--multi-result-ops-auxiliary-ops-supplemental-patterns) · `4-multi-result-and-aux/`
- 5 — [Rewrite directives](#lesson-5--rewrite-directives) · `5-directives/`

The `Pat` / `Pattern` signatures used throughout:

```tablegen
Pat<dag source, dag result, list<dag> preds = [], list<dag> supplemental = [],
    dag benefit = (addBenefit 0)>
Pattern<dag source, list<dag> results, list<dag> preds = [],
        list<dag> supplemental = [], dag benefit = (addBenefit 0)>
```
`Pat` is the common single-result form; `Pattern` takes a *list* of result
patterns (Lesson 4).

---

## Lesson 1 — Basic rewrite patterns (`Pat`)

*Source: `1-basics/01_basic_pattern.td`*

A rule maps a source pattern to a result pattern. Operands are captured with
`$name` and reused on the result side; source patterns **nest** to match chains
of ops; reusing one symbol for two operands means "match only when they are the
same SSA value".

```tablegen
// fuse  add(mul($a,$b), $c)  ->  fma($a,$b,$c)
def : Pat<(AddOp (MulOp $a, $b), $c), (FmaOp $a, $b, $c)>;

// x + x  ->  mul_two(x)
def : Pat<(AddOp $x, $x), (MulTwoOp $x)>;
```

## Lesson 2 — Constraints

*Source: `2-constraints/02_constraints.td`*

The third `Pat` argument is a list of *additional constraints* over captured
symbols. Use built-in attribute/type constraints, or define your own with
`Constraint<CPred<"...">>` (the C++ string is spliced into the matcher, with
`$0`, `$1`, … bound to the passed symbols). Built-in `ConstantAttr<Attr,"v">`
matches a specific attribute value.

```tablegen
def HasOneUse : Constraint<CPred<"$0.hasOneUse()">, "value has exactly one use">;

// only fuse when the multiply feeds exactly one consumer
def : Pat<(AddOp (MulOp:$mul $a, $b), $c), (FmaOp $a, $b, $c), [(HasOneUse $mul)]>;

// match mul(x, 1.0) and fold it to x  (replaceWithValue — see Lesson 5)
def : Pat<(MulOp $x, (ConstantOp ConstantAttr<F64Attr, "1.0">)), (replaceWithValue $x)>;
```

## Lesson 3 — NativeCodeCall: escaping to C++

*Source: `3-native-code/03_native_code.td`*

`NativeCodeCall<"...">` wraps a C++ expression for use in a result pattern.
`$_builder` is the current builder; `$0`, `$1`, … are the passed symbols.
`mlir-tblgen` embeds the string verbatim — it's compiled later as part of your
dialect, not by `mlir-tblgen`. `NativeCodeCall<expr, N>` returns N values;
`NativeCodeCallVoid` returns none.

```tablegen
def NegateF64Attr : NativeCodeCall<"negateF64Attr($_builder, $0)">;

// constant-fold  neg(constant v)  ->  constant (-v)
def : Pat<(NegOp (ConstantOp $value)), (ConstantOp (NegateF64Attr $value))>;
```

## Lesson 4 — Multi-result ops, auxiliary ops, supplemental patterns

*Source: `4-multi-result-and-aux/04_multi_and_aux.td`*

`Pattern` takes a *list* of result patterns. If the source op has N results, the
first N replace them; extra patterns build **auxiliary** ops. Bind a built
multi-result op with `:$sym` and reference its results as `$sym__K`. The 4th
`Pattern` argument is a list of **supplemental** patterns run for side effects
(often `NativeCodeCallVoid`).

```tablegen
// split a 2-result op into two single-result ops
def : Pattern<(DivModOp $a, $b), [(DivOp $a, $b), (RemOp $a, $b)]>;

// $sym__K: build divmod (auxiliary), replace the use with its remainder
def : Pattern<(UseOp $x), [(DivModOp:$dm $x, $x), (UseOp $dm__1)]>;

// supplemental side-effect after the rewrite
def CopyAttrs : NativeCodeCallVoid<"copyAttrs($0, $1)">;
def : Pattern<(DivOp:$old $a, $b), [(RemOp $a, $b)], [], [(CopyAttrs $old, $a)]>;
```

## Lesson 5 — Rewrite directives

*Source: `5-directives/05_directives.td`*

Directives are special pseudo-ops:

- `replaceWithValue $x` — replace the matched op's uses with an existing value
  instead of building a new op.
- `(either (a, b))` — in a *source* pattern, match two operands in either order.
- `(returnType ...)` — give an **auxiliary** op's result type when it can't be
  inferred (not allowed on the root replacement, whose types come from the
  matched op).
- `(addBenefit N)` — the last `Pat` argument; raises priority among competing
  patterns.

```tablegen
def : Pat<(IdentityOp $x), (replaceWithValue $x)>;
def : Pat<(AddOp (either (ConstantOp $c), $x)), (ScaleOp $x, $c)>;
def : Pattern<(RoundOp $x), [(CastOp:$c $x, (returnType $x)), (MulTwoOp $c)]>;
def : Pat<(IdentityOp $x), (MulTwoOp $x), [], [], (addBenefit 10)>;
```

---

## Generating the C++

From the `mlir-tablegen/` root, `./gen-all.sh` runs `--gen-rewriters` over every
DRR lesson into `generated/`. By hand:

```bash
MLIR=/opt/homebrew/opt/llvm@20
$MLIR/bin/mlir-tblgen --gen-rewriters -I $MLIR/include \
  drr/1-basics/01_basic_pattern.td
```

The output is a set of `RewritePattern` structs plus a
`populateWithGenerated(RewritePatternSet &)` function. To use it you `#include`
the `.inc` into your pass and call `populateWithGenerated(patterns)` — compiled
against `libMLIR` with your dialect registered. See the top-level
[README](../README.md#building-a-real-dialect-the-mlir_tablegen-cmake-flow).
