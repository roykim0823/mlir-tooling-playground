//===- toy-opt.cpp - mlir-opt for the Toy dialect -------------------------===//
//
// An out-of-tree `mlir-opt`. MlirOptMain provides everything mlir-opt does
// (parse a file, run `-pass-name` flags or `-pass-pipeline=...`, print,
// `-verify-diagnostics`, `-split-input-file`, `--mlir-print-ir-after-all`, ...)
// given only two things: a DialectRegistry naming the dialects it may parse,
// and the set of passes registered before it starts.
//
//   toy-opt input.mlir -toy-fold
//   toy-opt input.mlir -pass-pipeline='builtin.module(toy-fold{max-iterations=1})'
//   toy-opt input.mlir -toy-fold --mlir-pass-statistics
//   toy-opt --help | grep toy
//
// This is the binary the lit tests in ../test/ drive.
//
//===----------------------------------------------------------------------------===//

#include "Toy/ToyDialect.h"
#include "Toy/ToyPasses.h"

#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/Tools/mlir-opt/MlirOptMain.h"
#include "mlir/Transforms/Passes.h"

int main(int argc, char **argv) {
  // Dialects the tool can parse. Toy is ours; Func is registered so tests can
  // wrap toy ops in `func.func` and use CHECK-LABEL per function, exactly like
  // upstream MLIR tests do.
  mlir::DialectRegistry registry;
  registry.insert<toy::ToyDialect, mlir::func::FuncDialect>();

  // Passes the tool exposes on the command line.
  toy::registerToyPasses();            // generated: -toy-fold
  mlir::registerTransformsPasses();    // stock: -canonicalize, -cse, -symbol-dce, ...

  return mlir::asMainReturnCode(
      mlir::MlirOptMain(argc, argv, "Toy dialect optimizer driver\n", registry));
}
