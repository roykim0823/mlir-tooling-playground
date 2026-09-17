//===- ToyPatterns.cpp - Toy rewrite patterns -----------------------------===//
//
// The C++ side of all three pattern flavours:
//   * DRR  (ToyOps.td)        -> ToyPatterns.inc      + the NativeCodeCall helper
//   * PDLL (ToyPatterns.pdll) -> ToyPdllPatterns.h.inc (native bodies are inside)
//   * C++  (below)            -> one pattern written against BinaryArithOpInterface
// and a thin wrapper that puts all of them into one RewritePatternSet.
//
//===----------------------------------------------------------------------------===//

#include "Toy/ToyOps.h"
#include "Toy/ToyPasses.h"   // declares populateToyFoldPatterns

#include "mlir/IR/Builders.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/Parser/Parser.h"   // parseSourceString, used by the generated PDLL C++
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

// mlir-pdll -x=cpp output: one `struct <PatternName> : PDLPatternModule` per
// Pattern, holding the PDL IR as a string plus the native Rewrite bodies as
// static functions, and `populateGeneratedPDLLPatterns`. Requires the pdl
// dialect to be loaded in the context (see ToyPasses.td dependentDialects).
#include "Toy/ToyPdllPatterns.h.inc"

namespace {
// A hand-written pattern that is generic over an INTERFACE: it matches any op
// implementing BinaryArithOpInterface — add, mul, sub, and whatever is added
// later — and never names a concrete op class. OpInterfaceRewritePattern is
// the interface counterpart of OpRewritePattern<ConcreteOp>.
struct FoldBinaryArithConstants
    : public OpInterfaceRewritePattern<toy::BinaryArithOpInterface> {
  using OpInterfaceRewritePattern::OpInterfaceRewritePattern;

  LogicalResult matchAndRewrite(toy::BinaryArithOpInterface op,
                                PatternRewriter &rewriter) const override {
    // getLhsValue/getRhsValue: shared-body interface methods (ToyInterfaces.td).
    auto lhs = op.getLhsValue().getDefiningOp<toy::ConstantOp>();
    auto rhs = op.getRhsValue().getDefiningOp<toy::ConstantOp>();
    if (!lhs || !rhs)
      return failure();
    // evaluate(): implemented per op in ToyInterfaces.cpp.
    // getValue() on an F64Attr accessor yields the llvm::APFloat.
    double result = op.evaluate(lhs.getValue().convertToDouble(),
                                rhs.getValue().convertToDouble());
    rewriter.replaceOpWithNewOp<toy::ConstantOp>(op, result);   // ODS custom builder
    return success();
  }
};
} // namespace

namespace toy {
void populateToyFoldPatterns(RewritePatternSet &patterns) {
  populateWithGenerated(patterns);           // DRR:  add(const, const)
  populateGeneratedPDLLPatterns(patterns);   // PDLL: mul(const, const), mul(x, 1.0)
  patterns.add<FoldBinaryArithConstants>(patterns.getContext());   // C++ via interface: any of them
}
} // namespace toy
