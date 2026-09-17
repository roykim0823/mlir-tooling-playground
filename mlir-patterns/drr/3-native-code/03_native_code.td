// =============================================================================
// DRR Lesson 3 — NativeCodeCall: escaping to C++
//
//   When a transform needs real logic (compute an attribute, call a helper),
//   wrap a C++ expression in `NativeCodeCall<"...">`. Inside the string,
//   `$_builder` is the current OpBuilder and `$0`, `$1`, ... are the symbols
//   passed at the use site. mlir-tblgen embeds the string verbatim — it is
//   compiled later, as part of your dialect, not by mlir-tblgen.
//
//   `NativeCodeCall<expr, N>` returns N values; `NativeCodeCallVoid` returns
//   none (used for side-effecting supplemental patterns — see Lesson 4).
// =============================================================================

include "mlir/IR/OpBase.td"
include "mlir/IR/PatternBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def Toy_Dialect : Dialect { let name = "toy"; let cppNamespace = "::toy"; }
class Toy_Op<string m, list<Trait> t = []> : Op<Toy_Dialect, m, t>;

def ConstantOp : Toy_Op<"constant", [Pure]> { let arguments = (ins F64Attr:$value); let results = (outs F64:$res); }
def NegOp      : Toy_Op<"neg",      [Pure]> { let arguments = (ins F64:$operand);   let results = (outs F64:$res); }

// A named NativeCodeCall building a new (negated) attribute from a matched one.
def NegateF64Attr : NativeCodeCall<"negateF64Attr($_builder, $0)">;

// Constant-fold neg(constant v) -> constant (-v), computing the new attribute
// in C++ via the helper above. `$value` is the F64Attr captured from the
// matched constant.
def : Pat<(NegOp (ConstantOp $value)),
          (ConstantOp (NegateF64Attr $value))>;

// NativeCodeCall can also produce a fresh attribute from nothing, e.g. a zero.
def MakeZeroF64 : NativeCodeCall<"$_builder.getF64FloatAttr(0.0)">;

// neg(neg(x)) is x, but here we instead show building a constant 0 result.
def : Pat<(NegOp (NegOp $x)),
          (ConstantOp (MakeZeroF64))>;
