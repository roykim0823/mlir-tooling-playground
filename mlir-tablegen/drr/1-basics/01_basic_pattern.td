// =============================================================================
// DRR Lesson 1 — Basic rewrite patterns (`Pat`)
//
//   A Declarative Rewrite Rule maps a *source pattern* (IR to match) to a
//   *result pattern* (IR to build):  Pat<(source...), (result...)>. Operands
//   are captured with `$name` and reused on the result side. Source patterns
//   nest to match chains of ops. mlir-tblgen --gen-rewriters turns each rule
//   into a C++ RewritePattern.
//
//   DRR patterns are written in terms of ops defined in ODS, so this file
//   defines a small dialect first (see the ods/ lessons for the ODS details).
// =============================================================================

include "mlir/IR/OpBase.td"
include "mlir/IR/PatternBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"   // Pure

def Toy_Dialect : Dialect { let name = "toy"; let cppNamespace = "::toy"; }
class Toy_Op<string m, list<Trait> t = []> : Op<Toy_Dialect, m, t>;

def AddOp    : Toy_Op<"add",     [Pure]> { let arguments = (ins F64:$lhs, F64:$rhs); let results = (outs F64:$res); }
def MulOp    : Toy_Op<"mul",     [Pure]> { let arguments = (ins F64:$lhs, F64:$rhs); let results = (outs F64:$res); }
def FmaOp    : Toy_Op<"fma",     [Pure]> { let arguments = (ins F64:$a, F64:$b, F64:$c); let results = (outs F64:$res); }
def MulTwoOp : Toy_Op<"mul_two", [Pure]> { let arguments = (ins F64:$x); let results = (outs F64:$res); }

// 1) Nested source pattern: fuse a multiply feeding an add into a single fma.
//    Matches  add(mul($a, $b), $c)  and rewrites to  fma($a, $b, $c).
def : Pat<(AddOp (MulOp $a, $b), $c), (FmaOp $a, $b, $c)>;

// 2) Reusing a captured symbol: x + x  ->  mul_two(x).
//    Binding the same `$x` to both operands means "match only when they are
//    the same SSA value".
def : Pat<(AddOp $x, $x), (MulTwoOp $x)>;
