//===- toy-reduce.cpp - mlir-reduce for the Toy dialect -------------------===//
//
// Stock mlir-reduce cannot parse toy ops (it has no plugin flags in LLVM 20),
// so an out-of-tree dialect gets its own reducer the same way it gets its own
// opt: MlirReduceMain + a context that knows the dialect + the passes that
// -opt-reduction-pass may name.
//
//   toy-reduce crash.mlir -reduction-tree='traversal-mode=0 test=./interesting.sh' -o reduced.mlir
//
// See ../../../../mlir-reduce/ for the tutorial.
//
//===----------------------------------------------------------------------------===//

#include "Toy/ToyDialect.h"
#include "Toy/ToyPasses.h"

#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/Tools/mlir-reduce/MlirReduceMain.h"
#include "mlir/Transforms/Passes.h"

int main(int argc, char **argv) {
  // Passes that -opt-reduction-pass='opt-pass=...' may refer to.
  toy::registerToyPasses();
  mlir::registerTransformsPasses();   // canonicalize, cse, symbol-dce, ...

  mlir::DialectRegistry registry;
  registry.insert<toy::ToyDialect, mlir::func::FuncDialect>();
  mlir::MLIRContext context(registry);

  return mlir::failed(mlir::mlirReduceMain(argc, argv, context));
}
