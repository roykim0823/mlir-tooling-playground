//===- 03_anchors_dialects.td - Lesson 3: anchors, dependent dialects, constructors -*- tablegen -*-===//
//
// Three more knobs on a Pass record:
//   * the ANCHOR (second template argument) decides what op the pass runs on,
//   * `dependentDialects` tells the pass manager which dialects must already
//     be loaded because the pass may *create* their ops,
//   * `constructor` replaces the generated factory with your own.
//
//   mlir-tblgen --gen-pass-decls -name Toy -I $MLIR/include 03_anchors_dialects.td
//
//===----------------------------------------------------------------------------===//

include "mlir/Pass/PassBase.td"

// --- Anchors ---------------------------------------------------------------

// Anchored on ModuleOp: runs once for the whole module. Use this when the pass
// needs to see everything at once (e.g. it touches symbols across functions).
def ToyFoldModule : Pass<"toy-fold-module", "::mlir::ModuleOp"> {
  let summary = "Fold, once per module";
}

// Anchored on func.func: the pass manager runs one instance PER FUNCTION, in
// parallel, and the pass may only touch IR inside its function. This is the
// common choice for local transformations. The pipeline spelling becomes
// `builtin.module(func.func(toy-fold-func))`.
def ToyFoldFunc : Pass<"toy-fold-func", "::mlir::func::FuncOp"> {
  let summary = "Fold, once per function";
}

// No anchor: an "any-op" pass (`OperationPass<>`), schedulable on any op.
// `getOperation()` returns a plain `Operation *`.
def ToyFoldAny : Pass<"toy-fold-any"> {
  let summary = "Fold, on whatever op it is scheduled on";
}

// InterfacePass: anchored on an *interface* instead of a concrete op, so it
// runs on every op implementing it — here any function-like op, whichever
// dialect it comes from. Generated base: `::mlir::InterfacePass<FunctionOpInterface>`.
def ToyFoldAnyFunc : InterfacePass<"toy-fold-any-func", "::mlir::FunctionOpInterface"> {
  let summary = "Fold, on any op implementing FunctionOpInterface";
}

// --- Dependent dialects ---------------------------------------------------------

// If a pass can CREATE ops/types/attrs of a dialect, that dialect must be loaded
// in the MLIRContext before the pass runs — otherwise the pass manager would be
// racing dialect loading against other passes running in parallel. Listing
// dialects here generates a `getDependentDialects(DialectRegistry&)` override
// that inserts them. Dialects the pass only *reads* need not be listed (the
// parser already loaded them).
def ToyLowerToArith : Pass<"toy-lower-to-arith", "::mlir::func::FuncOp"> {
  let summary = "Lower toy.add/toy.mul to arith.addf/arith.mulf";
  let dependentDialects = ["::mlir::arith::ArithDialect"];
}

// --- Custom constructor -------------------------------------------------------

// By default the backend generates `createToyFold()` (and a
// `createToyFold(Options)` overload if there are options) as friend functions
// of the base class. Set `constructor` to hand-write the factory instead: the
// generated registration will call THIS expression, and no default factory is
// emitted. Useful when the pass needs arguments an Option can't express (a
// callback, a pointer to analysis data, ...).
def ToyFoldCustom : Pass<"toy-fold-custom", "::mlir::ModuleOp"> {
  let summary = "Fold, created through a hand-written factory";
  let constructor = "::toy::createToyFoldCustomPass()";
}
