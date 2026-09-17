//===- toy-translate.cpp - mlir-translate for the Toy dialect -------------===//
//
//   toy-translate --mlir-to-toytext in.mlir        # export
//   toy-translate --toytext-to-mlir in.toytext     # import
//   toy-translate --help | grep toytext
//
// mlirTranslateMain does the same work as mlir-translate's main: it parses the
// command line, picks the requested translation, sets up a context with the
// dialects that translation asked for, and handles -o, -split-input-file and
// -verify-diagnostics. The tool only has to register its translations first.
//
//===----------------------------------------------------------------------------===//

#include "mlir/Tools/mlir-translate/MlirTranslateMain.h"

namespace toy {
void registerToyTranslations();
}

int main(int argc, char **argv) {
  toy::registerToyTranslations();
  return mlir::failed(mlir::mlirTranslateMain(argc, argv, "Toy translation tool"));
}
