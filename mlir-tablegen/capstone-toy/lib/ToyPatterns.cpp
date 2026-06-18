//===- ToyPatterns.cpp - Toy rewrite patterns -----------------------------===//
//
// The C++ side of the DRR fold: the NativeCodeCall helper plus a thin wrapper
// exposing the generated `populateWithGenerated` to the rest of the project.
//
//===----------------------------------------------------------------------------===//

#include "Toy/ToyOps.h"

#include "mlir/IR/Builders.h"
#include "mlir/IR/PatternMatch.h"
#include "llvm/Support/Casting.h"

using namespace mlir;

// Helper invoked by the FoldAddF64 NativeCodeCall in ToyOps.td. `a` and `b` are
// the `value` attributes captured from the two folded toy.constant ops.
static FloatAttr foldAddF64(OpBuilder &builder, Attribute a, Attribute b) {
  double lhs = llvm::cast<FloatAttr>(a).getValueAsDouble();
  double rhs = llvm::cast<FloatAttr>(b).getValueAsDouble();
  return builder.getF64FloatAttr(lhs + rhs);
}

// --gen-rewriters output (the GeneratedConvert* patterns + populateWithGenerated).
// Included in an anonymous namespace so the generated symbols stay TU-local.
namespace {
#include "Toy/ToyPatterns.inc"
} // namespace

namespace toy {
void populateToyFoldPatterns(RewritePatternSet &patterns) {
  populateWithGenerated(patterns);
}
} // namespace toy
