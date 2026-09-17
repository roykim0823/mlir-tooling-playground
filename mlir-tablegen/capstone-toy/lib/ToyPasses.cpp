//===- ToyPasses.cpp - Toy pass implementations ---------------------------===//
//
// The hand-written half of a TableGen-declared pass. GEN_PASS_DEF_TOYFOLD pulls
// in the generated CRTP base `impl::ToyFoldBase<Derived>`, which already
// implements getArgument()/getName()/getDescription(), the option and
// statistic members, getDependentDialects(), clonePass(), and the
// `createToyFold()` factories. What is left for us is `runOnOperation()`.
//
//===----------------------------------------------------------------------------===//

#include "Toy/ToyPasses.h"
#include "Toy/ToyOps.h"

#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/Rewrite/FrozenRewritePatternSet.h"
#include "mlir/Transforms/GreedyPatternRewriteDriver.h"

namespace toy {
// The generated base class + factories for exactly one pass. Each pass gets its
// own GEN_PASS_DEF_<PASSNAME> macro so a library can spread its passes across
// several .cpp files, each including only the definition it implements.
#define GEN_PASS_DEF_TOYFOLD
#include "Toy/ToyPasses.h.inc"
} // namespace toy

using namespace mlir;

namespace {

// `impl::ToyFoldBase<ToyFoldPass>` is the TableGen-generated base. `Base` is a
// convenience alias it provides so the derived class can name its own base
// class without repeating the template argument.
struct ToyFoldPass : public toy::impl::ToyFoldBase<ToyFoldPass> {
  using Base::Base;   // inherit the default and the ToyFoldOptions constructors

  void runOnOperation() override {
    ModuleOp module = getOperation();   // the anchor op from Pass<"toy-fold", "::mlir::ModuleOp">

    // Count folds by comparing the number of foldable ops before and after; the
    // generated patterns have no hook of their own to bump a statistic.
    // "Foldable" = implements BinaryArithOpInterface, so this needs no update
    // when a new arithmetic op is added.
    auto countFoldable = [&] {
      int64_t n = 0;
      module.walk([&](toy::BinaryArithOpInterface) { ++n; });
      return n;
    };
    int64_t before = countFoldable();

    RewritePatternSet patterns(&getContext());
    toy::populateToyFoldPatterns(patterns);

    // `maxIterations` is the generated Pass::Option<int64_t> member; it holds
    // the command-line value or the .td default. Options convert implicitly to
    // their value type (use .getValue() where a template can't deduce it).
    GreedyRewriteConfig config;
    config.maxIterations = maxIterations;

    // The driver "fails" when it stops at maxIterations without a final
    // no-change iteration to confirm a fixpoint. The IR is still valid, just
    // possibly not fully folded, so this is a remark, not signalPassFailure().
    bool converged =
        succeeded(applyPatternsGreedily(module, std::move(patterns), config));

    int64_t folded = before - countFoldable();

    numFolded += folded;   // the generated Pass::Statistic member

    // `report` is the generated Pass::Option<bool> member. A remark is the
    // portable way to expose a count: statistics are compiled out of release
    // LLVM builds, diagnostics are not.
    if (report) {
      emitRemark(module.getLoc())
          << "toy-fold: folded " << folded << " op(s)"
          << (converged ? ""
                        : "; stopped at max-iterations without confirming a fixpoint");
    }
  }
};

} // namespace
