//===- toy-capstone.cpp - Drive the Toy dialect ---------------------------===//
//
// A standalone program (no input file needed) that:
//   1. loads the Toy dialect into an MLIRContext,
//   2. builds  toy.print(toy.add(toy.constant 1.0, toy.constant 2.0))  using the
//      ODS-generated builders,
//   3. prints the module,
//   4. applies the DRR fold pattern and prints again — add(1.0, 2.0) collapses
//      to a single constant 3.0.
//
//===----------------------------------------------------------------------------===//

#include "Toy/ToyDialect.h"
#include "Toy/ToyOps.h"

#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/Verifier.h"
#include "mlir/Rewrite/FrozenRewritePatternSet.h"
#include "mlir/Transforms/GreedyPatternRewriteDriver.h"
#include "llvm/Support/raw_ostream.h"

namespace toy {
void populateToyFoldPatterns(mlir::RewritePatternSet &patterns);
} // namespace toy

int main() {
  mlir::MLIRContext context;
  context.getOrLoadDialect<toy::ToyDialect>();

  mlir::OpBuilder builder(&context);
  mlir::Location loc = builder.getUnknownLoc();

  // Build a module:  print(add(constant 1.0, constant 2.0))
  mlir::ModuleOp module = mlir::ModuleOp::create(loc);
  builder.setInsertionPointToEnd(module.getBody());

  mlir::Value c1 = builder.create<toy::ConstantOp>(loc, 1.0);   // custom builder
  mlir::Value c2 = builder.create<toy::ConstantOp>(loc, 2.0);
  mlir::Value sum =
      builder.create<toy::AddOp>(loc, builder.getF64Type(), c1, c2);
  builder.create<toy::PrintOp>(loc, sum);

  // The custom type and attribute (see ../attrs-and-types/). Build them with
  // the generated `get` and let the dialect's generated printer format them.
  toy::ArrayType arrayTy = toy::ArrayType::get(&context, 3, builder.getF64Type());
  toy::ShapeAttr shape = toy::ShapeAttr::get(&context, 3, 4);
  llvm::outs() << "=== custom type & attribute ===\n";
  llvm::outs() << "type : " << arrayTy << "\n";   // !toy.array<3 x f64>
  llvm::outs() << "attr : " << shape << "\n\n";   // #toy.shape<3 x 4>

  if (mlir::failed(mlir::verify(module))) {
    llvm::errs() << "module failed to verify\n";
    return 1;
  }

  llvm::outs() << "=== before ===\n";
  module.print(llvm::outs());
  llvm::outs() << "\n";

  // Apply the generated constant-folding pattern.
  mlir::RewritePatternSet patterns(&context);
  toy::populateToyFoldPatterns(patterns);
  if (mlir::failed(mlir::applyPatternsGreedily(
          module, mlir::FrozenRewritePatternSet(std::move(patterns))))) {
    llvm::errs() << "pattern application failed\n";
    return 1;
  }

  llvm::outs() << "=== after folding add(constant, constant) ===\n";
  module.print(llvm::outs());
  llvm::outs() << "\n";
  return 0;
}
