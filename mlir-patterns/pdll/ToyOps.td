//===- ToyOps.td - shared ODS definitions for the PDLL lessons --*- tablegen -*-===//
//
// PDLL patterns can `#include` an ODS .td file. That gives them the ops' names,
// operand/result/attribute NAMES (so you can write `mul.res` or `{value = v}`),
// and the ODS constraints as reusable PDLL constraints. Lesson 1 works without
// this file; Lessons 2-5 include it:
//
//   mlir-pdll -x=mlir -I $MLIR/include -I . 2-constraints/02_constraints.pdll
//                                       ^^^^ so `#include "ToyOps.td"` resolves
//
// The ops are the same tiny toy dialect the ../drr lessons use.
//===----------------------------------------------------------------------------===//

include "mlir/IR/OpBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"   // Pure

def Toy_Dialect : Dialect { let name = "toy"; let cppNamespace = "::toy"; }
class Toy_Op<string m, list<Trait> t = []> : Op<Toy_Dialect, m, t>;

// f64 arithmetic
def ConstantOp : Toy_Op<"constant", [Pure]> { let arguments = (ins F64Attr:$value);          let results = (outs F64:$res); }
def AddOp      : Toy_Op<"add",      [Pure]> { let arguments = (ins F64:$lhs, F64:$rhs);      let results = (outs F64:$res); }
def SubOp      : Toy_Op<"sub",      [Pure]> { let arguments = (ins F64:$lhs, F64:$rhs);      let results = (outs F64:$res); }
def MulOp      : Toy_Op<"mul",      [Pure]> { let arguments = (ins F64:$lhs, F64:$rhs);      let results = (outs F64:$res); }
def FmaOp      : Toy_Op<"fma",      [Pure]> { let arguments = (ins F64:$a, F64:$b, F64:$c); let results = (outs F64:$res); }
def MulTwoOp   : Toy_Op<"mul_two",  [Pure]> { let arguments = (ins F64:$x);                  let results = (outs F64:$res); }
def NegOp      : Toy_Op<"neg",      [Pure]> { let arguments = (ins F64:$operand);            let results = (outs F64:$res); }
def IdentityOp : Toy_Op<"identity", [Pure]> { let arguments = (ins F64:$x);                  let results = (outs F64:$res); }
def ScaleOp    : Toy_Op<"scale",    [Pure]> { let arguments = (ins F64:$x, F64Attr:$factor); let results = (outs F64:$res); }
def CastOp     : Toy_Op<"cast",     [Pure]> { let arguments = (ins F64:$x);                  let results = (outs F64:$res); }
def RoundOp    : Toy_Op<"round",    [Pure]> { let arguments = (ins F64:$x);                  let results = (outs F64:$res); }

// i64 ops with multiple results
def DivModOp : Toy_Op<"divmod", [Pure]> { let arguments = (ins I64:$a, I64:$b); let results = (outs I64:$q, I64:$r); }
def DivOp    : Toy_Op<"div",    [Pure]> { let arguments = (ins I64:$a, I64:$b); let results = (outs I64:$q); }
def RemOp    : Toy_Op<"rem",    [Pure]> { let arguments = (ins I64:$a, I64:$b); let results = (outs I64:$r); }
def UseOp    : Toy_Op<"use",    [Pure]> { let arguments = (ins I64:$x);         let results = (outs I64:$res); }
