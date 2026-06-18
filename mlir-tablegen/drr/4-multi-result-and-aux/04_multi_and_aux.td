// =============================================================================
// DRR Lesson 4 — Multi-result ops, auxiliary ops, supplemental patterns
//
//   `Pattern` (the general form of `Pat`) takes a *list* of result patterns:
//     Pattern<(source), [(result0), (result1), ...]>
//
//   * If the source op has N results, the first N result patterns supply their
//     replacements.
//   * `$sym__K` references result K of a multi-result captured op.
//   * The 4th `Pattern` argument is a list of *supplemental* patterns, run for
//     side effects after the rewrite (often `NativeCodeCallVoid`).
// =============================================================================

include "mlir/IR/OpBase.td"
include "mlir/IR/PatternBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def Toy_Dialect : Dialect { let name = "toy"; let cppNamespace = "::toy"; }
class Toy_Op<string m, list<Trait> t = []> : Op<Toy_Dialect, m, t>;

def DivModOp : Toy_Op<"divmod", [Pure]> { let arguments = (ins I64:$a, I64:$b); let results = (outs I64:$q, I64:$r); }
def DivOp    : Toy_Op<"div",    [Pure]> { let arguments = (ins I64:$a, I64:$b); let results = (outs I64:$q); }
def RemOp    : Toy_Op<"rem",    [Pure]> { let arguments = (ins I64:$a, I64:$b); let results = (outs I64:$r); }
def UseOp    : Toy_Op<"use",    [Pure]> { let arguments = (ins I64:$x);         let results = (outs I64:$res); }

// 1) Split a 2-result op into two single-result ops. The two result patterns
//    replace divmod's quotient and remainder respectively.
def : Pattern<(DivModOp $a, $b), [(DivOp $a, $b), (RemOp $a, $b)]>;

// 2) `$sym__K`: when a *result* pattern builds a multi-result op, bind it with
//    `:$sym` and refer to individual results as `$sym__K`. Here the first
//    result pattern builds a divmod (auxiliary), and the replacement for the
//    source op's single result is divmod's remainder, `$dm__1`.
def : Pattern<(UseOp $x),
              [(DivModOp:$dm $x, $x),   // auxiliary: builds the 2-result op
               (UseOp $dm__1)]>;        // replacement uses result index 1

// 3) Supplemental pattern: after rewriting, run a void C++ call for a side
//    effect (e.g. copy metadata). It produces no IR value.
def CopyAttrs : NativeCodeCallVoid<"copyAttrs($0, $1)">;
def : Pattern<(DivOp:$old $a, $b),
              [(RemOp $a, $b)],            // the replacement
              [],                          // additional constraints (none)
              [(CopyAttrs $old, $a)]>;     // supplemental: side-effect only
