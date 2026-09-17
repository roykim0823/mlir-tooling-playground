//===- toy-lsp-server.cpp - mlir-lsp-server for the Toy dialect -----------===//
//
// The stock mlir-lsp-server reports `Dialect 'toy' not found` on Toy IR: it
// only knows the dialects compiled into it (and, in LLVM 20, has no plugin
// flags). An out-of-tree dialect therefore gets its own language server the
// same way it gets its own opt — MlirLspServerMain + a registry.
//
// Point your editor at it (VS Code: "mlir.server_path") or drive it by hand:
//
//   toy-lsp-server --lit-test < session.txt
//
// See ../../../mlir-tools/lsp/ for the tutorial and ../test/lsp.mlir for a
// session used as a lit test.
//
//===----------------------------------------------------------------------------===//

#include "Toy/ToyDialect.h"

#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/Tools/mlir-lsp-server/MlirLspServerMain.h"

int main(int argc, char **argv) {
  mlir::DialectRegistry registry;
  registry.insert<toy::ToyDialect, mlir::func::FuncDialect>();
  return mlir::failed(mlir::MlirLspServerMain(argc, argv, registry));
}
