//===- ToyPasses.td - Toy pass definitions ----------------------*- tablegen -*-===//
//
// The third mlir-tblgen workflow (after ODS and DRR): declaring *passes*.
// `--gen-pass-decls -name Toy` turns each `Pass` record into
//
//   * a `ToyFoldOptions` struct + `createToyFold()` factory     (GEN_PASS_DECL)
//   * a CRTP base class `impl::ToyFoldBase<Derived>` that owns
//     the argument name, description, options, statistics and
//     dependent dialects                                        (GEN_PASS_DEF_TOYFOLD)
//   * `registerToyFold()` / `registerToyPasses()` so the pass
//     shows up as `-toy-fold` in an opt-style tool              (GEN_PASS_REGISTRATION)
//
// The pass *body* (`runOnOperation`) is hand-written in lib/ToyPasses.cpp.
// See ../../passes/ for the standalone lessons on this backend.
//
//===----------------------------------------------------------------------------===//

include "mlir/Pass/PassBase.td"

// `Pass<argument, anchor-op>`: the pass runs once per anchor op. Anchoring on
// ModuleOp means one invocation over the whole module; the greedy driver then
// walks every nested region. Omit the anchor to get an "any op" pass.
def ToyFold : Pass<"toy-fold", "::mlir::ModuleOp"> {
  let summary = "Constant-fold BinaryArithOpInterface ops (add/mul/sub) using the DRR, PDLL and C++ patterns";
  let description = [{
    Applies the DRR `Pat` rewrites declared in ToyOps.td, the PDLL `Pattern`s
    in ToyPatterns.pdll, and the C++ pattern written against
    BinaryArithOpInterface with the greedy pattern rewrite driver until no
    pattern matches or `max-iterations` is reached. Dead `toy.constant`
    operands left behind by a fold are erased by the driver because the ops
    are `Pure`.
  }];

  // Dialects that must be loaded in the MLIRContext before the pass runs — the
  // pass manager reads this from the generated `getDependentDialects()`
  // override. Toy because the pass creates toy ops; the two PDL dialects
  // because the PDLL patterns are PDL IR that is parsed (pdl) and compiled
  // (pdl_interp) when the pattern set is frozen.
  let dependentDialects = [
    "::toy::ToyDialect",
    "::mlir::pdl::PDLDialect",
    "::mlir::pdl_interp::PDLInterpDialect",
  ];

  // Options become `Pass::Option<T>` members plus a `ToyFoldOptions` struct,
  // and are spelled `toy-fold{max-iterations=3 report=true}` in a pipeline.
  let options = [
    Option<"maxIterations", "max-iterations", "int64_t", /*default=*/"10",
           "Maximum number of greedy rewrite iterations (each iteration applies "
           "every matching pattern once)">,
    Option<"report", "report", "bool", /*default=*/"false",
           "Emit a remark on the module with the number of folded ops">,
  ];

  // Statistics become `Pass::Statistic` members, printed by
  // `--mlir-pass-statistics`. NOTE: llvm::Statistic is compiled out of release
  // LLVM builds (Homebrew's included); the report is empty there unless LLVM
  // was built with -DLLVM_FORCE_ENABLE_STATS=ON or assertions.
  let statistics = [
    Statistic<"numFolded", "num-folded", "Number of BinaryArithOpInterface ops folded away">,
  ];
}
