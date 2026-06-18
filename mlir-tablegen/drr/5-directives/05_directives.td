// =============================================================================
// DRR Lesson 5 — Rewrite directives
//
//   Directives are special pseudo-ops usable in result patterns:
//     replaceWithValue $x   - replace the matched op's uses with an existing
//                             value instead of building a new op.
//     returnType ...        - explicitly give a result's type when it can't be
//                             inferred (a value to copy from, or a C++ snippet).
//     location ...          - set the source location of a built op.
//     either(...)           - in a *source* pattern, match two operands in
//                             either order (matcher tries both).
//     (addBenefit N)        - the last Pat argument; raises a pattern's priority.
// =============================================================================

include "mlir/IR/OpBase.td"
include "mlir/IR/PatternBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def Toy_Dialect : Dialect { let name = "toy"; let cppNamespace = "::toy"; }
class Toy_Op<string m, list<Trait> t = []> : Op<Toy_Dialect, m, t>;

def ConstantOp : Toy_Op<"constant", [Pure]> { let arguments = (ins F64Attr:$value); let results = (outs F64:$res); }
def IdentityOp : Toy_Op<"identity", [Pure]> { let arguments = (ins F64:$x);         let results = (outs F64:$res); }
def AddOp      : Toy_Op<"add",      [Pure]> { let arguments = (ins F64:$lhs, F64:$rhs); let results = (outs F64:$res); }
def ScaleOp    : Toy_Op<"scale",    [Pure]> { let arguments = (ins F64:$x, F64Attr:$factor); let results = (outs F64:$res); }
def CastOp     : Toy_Op<"cast",     [Pure]> { let arguments = (ins F64:$x);         let results = (outs F64:$res); }
def MulTwoOp   : Toy_Op<"mul_two",  [Pure]> { let arguments = (ins F64:$x);         let results = (outs F64:$res); }
def RoundOp    : Toy_Op<"round",    [Pure]> { let arguments = (ins F64:$x);         let results = (outs F64:$res); }

// replaceWithValue: drop an identity op, forwarding its input to all users.
def : Pat<(IdentityOp $x), (replaceWithValue $x)>;

// either: match add(constant, x) regardless of operand order. Rewrites to a
// scale by the constant's value.
def : Pat<(AddOp (either (ConstantOp $c), $x)), (ScaleOp $x, $c)>;

// returnType: build an *auxiliary* cast whose result type can't be inferred, so
// we state it by copying `$x`'s type. (returnType is only allowed on auxiliary
// ops — not on the op that replaces the matched root, whose types come from the
// matched op.) The cast feeds the root replacement.
def : Pattern<(RoundOp $x),
              [(CastOp:$c $x, (returnType $x)),   // auxiliary, explicit type
               (MulTwoOp $c)]>;                    // root replacement

// addBenefit: this rule competes with the identity rule above on `IdentityOp`;
// the higher benefit makes the rewriter try this one first. The empty lists are
// the (additional-constraints, supplemental-patterns) arguments before it.
def : Pat<(IdentityOp $x), (MulTwoOp $x), [], [], (addBenefit 10)>;
