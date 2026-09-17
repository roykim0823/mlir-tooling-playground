//===- ToyPlugin.cpp - Toy as an mlir-opt plugin ---------------------------===//
//
// Lets the STOCK `mlir-opt` parse the Toy dialect and run its passes, with no
// custom tool at all:
//
//   mlir-opt --load-dialect-plugin=build/ToyPlugin.dylib \
//            --load-pass-plugin=build/ToyPlugin.dylib    test/fold.mlir -toy-fold
//   (.so on Linux; LLVM MODULE libraries carry no `lib` prefix)
//
// A plugin is a shared library exporting one or both of these C entry points.
// mlir-opt dlopen()s the file, looks the symbol up by name, checks apiVersion,
// and calls the callback:
//   * mlirGetDialectPluginInfo — asked to add dialects to the DialectRegistry
//   * mlirGetPassPluginInfo    — asked to register passes (so -toy-fold exists)
// One library may provide both, as here.
//
// The plugin must link the SAME MLIR the host does — the libMLIR.dylib that
// mlir-opt itself uses — never a private static copy, or every TypeID would
// exist twice and casts across the boundary would fail. See CMakeLists.txt.
//
//===----------------------------------------------------------------------------===//

#include "Toy/ToyDialect.h"
#include "Toy/ToyPasses.h"

#include "mlir/IR/DialectRegistry.h"
#include "mlir/Tools/Plugins/DialectPlugin.h"
#include "mlir/Tools/Plugins/PassPlugin.h"
#include "llvm/Config/llvm-config.h"   // LLVM_VERSION_STRING

extern "C" LLVM_ATTRIBUTE_WEAK ::mlir::DialectPluginLibraryInfo
mlirGetDialectPluginInfo() {
  return {MLIR_PLUGIN_API_VERSION, "Toy", LLVM_VERSION_STRING,
          [](::mlir::DialectRegistry *registry) {
            registry->insert<toy::ToyDialect>();
          }};
}

extern "C" LLVM_ATTRIBUTE_WEAK ::mlir::PassPluginLibraryInfo
mlirGetPassPluginInfo() {
  return {MLIR_PLUGIN_API_VERSION, "ToyPasses", LLVM_VERSION_STRING,
          []() { toy::registerToyPasses(); }};
}
