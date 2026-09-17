//===- 01_pass.td - Lesson 1: a first Pass ------------------------*- tablegen -*-===//
//
// The third mlir-tblgen workflow. ODS *defines* ops and DRR *rewrites* them;
// a Pass is the unit that the pass manager schedules to run a transformation
// (such as a set of DRR patterns) over the IR. Passes are declared in TableGen
// so that the boilerplate — command-line argument, name, description, factory
// function, registration — is generated, leaving only `runOnOperation()` to
// hand-write in C++.
//
//   mlir-tblgen --gen-pass-decls -name Toy -I $MLIR/include 01_pass.td
//
// `-name Toy` is REQUIRED for this backend: it names the pass *group* and
// becomes the generated `registerToyPasses()` that registers every pass in
// this file at once.
//
//===----------------------------------------------------------------------------===//

include "mlir/Pass/PassBase.td"

// Pass<"cli-argument", "anchor op">
//   * the argument is what you type:  toy-opt file.mlir -toy-fold
//   * the anchor is the op type the pass runs on; the generated base class is
//     `::mlir::OperationPass<::mlir::ModuleOp>`, and inside runOnOperation()
//     `getOperation()` returns a `ModuleOp`.
//   * the record name (ToyFold) becomes the C++ names: ToyFoldBase,
//     createToyFold(), registerToyFold(), GEN_PASS_DEF_TOYFOLD.
def ToyFold : Pass<"toy-fold", "::mlir::ModuleOp"> {
  // One line, shown by `toy-opt --help` next to --toy-fold.
  let summary = "Constant-fold toy.add(constant, constant)";

  // Long form, used by --gen-pass-doc (Markdown) — not by the C++.
  let description = [{
    Repeatedly rewrites `toy.add` whose operands are both `toy.constant` into a
    single `toy.constant` holding the sum, until nothing changes.
  }];
}
