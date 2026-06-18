// =============================================================================
// ODS Lesson 7 — Regions and Successors
//
//   Regions hold nested blocks of IR (the bodies of if/for/func/...). They are
//   declared in `regions = (region ...)`:
//     AnyRegion        - any number of blocks
//     SizedRegion<N>   - exactly N blocks
//
//   Successors are control-flow target blocks (for branch-like terminators),
//   declared in `successors = (successor ...)`. Branch ops are Terminators.
// =============================================================================

include "mlir/IR/OpBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
}

class Toy_Op<string mnemonic, list<Trait> traits = []>
    : Op<Toy_Dialect, mnemonic, traits>;

// A structured loop carrying a single-block body region.
def WhileOp : Toy_Op<"while"> {
  let summary = "runs its body region while the condition holds";
  let arguments = (ins I1:$cond);
  let regions = (region SizedRegion<1>:$body);
}

// A conditional branch: a terminator with two successor blocks.
def CondBranchOp : Toy_Op<"cond_br", [Terminator]> {
  let summary = "branches to one of two blocks based on a predicate";
  let arguments = (ins I1:$cond);
  let successors = (successor AnySuccessor:$trueDest, AnySuccessor:$falseDest);
}
