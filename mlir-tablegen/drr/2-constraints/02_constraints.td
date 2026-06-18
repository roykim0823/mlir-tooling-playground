// =============================================================================
// DRR Lesson 2 — Constraints
//
//   The third `Pat`/`Pattern` argument is a list of *additional constraints*:
//   extra conditions that must hold for the match to succeed. They reference
//   captured symbols. You can use built-in attribute/type constraints, or
//   define your own with `Constraint<CPred<"...">>` (the C++ string is embedded
//   verbatim into the generated matcher).
// =============================================================================

include "mlir/IR/OpBase.td"
include "mlir/IR/PatternBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def Toy_Dialect : Dialect { let name = "toy"; let cppNamespace = "::toy"; }
class Toy_Op<string m, list<Trait> t = []> : Op<Toy_Dialect, m, t>;

def ConstantOp : Toy_Op<"constant", [Pure]> { let arguments = (ins F64Attr:$value); let results = (outs F64:$res); }
def AddOp      : Toy_Op<"add",      [Pure]> { let arguments = (ins F64:$lhs, F64:$rhs); let results = (outs F64:$res); }
def MulOp      : Toy_Op<"mul",      [Pure]> { let arguments = (ins F64:$lhs, F64:$rhs); let results = (outs F64:$res); }
def FmaOp      : Toy_Op<"fma",      [Pure]> { let arguments = (ins F64:$a, F64:$b, F64:$c); let results = (outs F64:$res); }

// A custom constraint: the C++ predicate is spliced into the matcher, with
// `$0`, `$1`, ... bound to the symbols passed at the use site.
def HasOneUse : Constraint<CPred<"$0.hasOneUse()">, "value has exactly one use">;

// 1) Only fuse when the multiply's result feeds exactly one consumer
//    (otherwise fusing would duplicate the multiply). `:$mul` captures the
//    inner op's result so the constraint can inspect it.
def : Pat<(AddOp (MulOp:$mul $a, $b), $c), (FmaOp $a, $b, $c), [(HasOneUse $mul)]>;

// 2) Matching an *attribute value*: built-in `ConstantAttr` constrains the
//    constant to 1.0, so this matches only `mul(x, 1.0)`. The result side uses
//    the `replaceWithValue` directive (covered fully in Lesson 5) to fold it
//    away to `x`.
def : Pat<(MulOp $x, (ConstantOp ConstantAttr<F64Attr, "1.0">)), (replaceWithValue $x)>;
