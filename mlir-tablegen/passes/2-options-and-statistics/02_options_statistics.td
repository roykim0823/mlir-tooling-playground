//===- 02_options_statistics.td - Lesson 2: options & statistics --*- tablegen -*-===//
//
// Passes are parameterised through `options` and report through `statistics`.
// Both are declared here and materialised as members of the generated base
// class, so the hand-written pass body simply reads `maxIterations` or does
// `numFolded += n`.
//
//   mlir-tblgen --gen-pass-decls -name Toy -I $MLIR/include 02_options_statistics.td
//   mlir-tblgen --gen-pass-doc         -I $MLIR/include 02_options_statistics.td
//
//===----------------------------------------------------------------------------===//

include "mlir/Pass/PassBase.td"

def ToyFold : Pass<"toy-fold", "::mlir::ModuleOp"> {
  let summary = "Constant-fold toy.add(constant, constant)";

  // Option<cppName, "cli-name", "C++ type", "default (C++ expression)", "desc">
  //
  // Each becomes:
  //   * a field in `struct ToyFoldOptions { int64_t maxIterations = 10; ... }`
  //   * a `::mlir::Pass::Option<int64_t> maxIterations{*this, "max-iterations", ...}`
  //     member of the base class (it converts implicitly to int64_t)
  //   * a `createToyFold(ToyFoldOptions)` overload
  //   * command-line syntax:  -pass-pipeline='builtin.module(toy-fold{max-iterations=3 report=true})'
  //     or, with the plain flag form:  -toy-fold='max-iterations=3 report=true'
  //     (options are space-separated inside ONE quoted value; they are NOT
  //     standalone --flags, even though --help lists them indented under the pass)
  let options = [
    Option<"maxIterations", "max-iterations", "int64_t", /*default=*/"10",
           "Maximum number of greedy rewrite iterations">,
    Option<"report", "report", "bool", /*default=*/"false",
           "Emit a remark with the number of folded ops">,
    // Enum-valued options pass the llvm::cl::values(...) clause as the extra
    // argument. The type must be visible where the generated code is included.
    Option<"strategy", "strategy", "::toy::FoldStrategy",
           /*default=*/"::toy::FoldStrategy::Greedy",
           "Which rewrite driver to use",
           [{::llvm::cl::values(
               clEnumValN(::toy::FoldStrategy::Greedy,  "greedy",  "greedy worklist driver"),
               clEnumValN(::toy::FoldStrategy::Walk,    "walk",    "single top-down walk"))}]>,
    // ListOption<cppName, "cli-name", "element type", "desc">
    //   -> `::mlir::Pass::ListOption<std::string> skipFuncs{...}`, spelled
    //      toy-fold{skip-funcs=main,helper}
    ListOption<"skipFuncs", "skip-funcs", "std::string",
               "Functions to leave untouched">,
  ];

  // Statistic<cppName, "display-name", "desc">
  //   -> `::mlir::Pass::Statistic numFolded{this, "num-folded", "..."}`
  //   -> printed by `--mlir-pass-statistics` (only in LLVM builds where
  //      llvm::Statistic is enabled: assertions on, or LLVM_FORCE_ENABLE_STATS).
  let statistics = [
    Statistic<"numFolded", "num-folded", "Number of toy.add ops folded away">,
  ];
}
