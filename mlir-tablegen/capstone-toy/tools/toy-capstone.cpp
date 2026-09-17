//===- toy-capstone.cpp - Drive the Toy dialect ---------------------------===//
//
// A standalone program (no input file needed) that:
//   1. loads the Toy dialect into an MLIRContext,
//   2. builds  toy.print(toy.add(toy.constant 1.0, toy.constant 2.0)),
//              toy.print(toy.mul(toy.constant 2.0, toy.constant 3.0)) and
//              toy.print(toy.sub(toy.constant 5.0, toy.constant 3.0))  using the
//      ODS-generated builders,
//   3. queries the ops through BinaryArithOpInterface and the array type
//      through ContainerTypeInterface, without naming concrete classes,
//   4. prints the module,
//   5. applies the fold patterns and prints again — the add collapses to 3.0
//      (DRR pattern, ToyOps.td), the mul to 6.0 (PDLL pattern,
//      ToyPatterns.pdll), the sub to 2.0 (C++ pattern via the interface).
//
//===----------------------------------------------------------------------------===//

#include "Toy/ToyDialect.h"
#include "Toy/ToyOps.h"
#include "Toy/ToyPasses.h"   // populateToyFoldPatterns (+ the PDL dialect headers)

#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/Verifier.h"
#include "mlir/Rewrite/FrozenRewritePatternSet.h"
#include "mlir/Transforms/GreedyPatternRewriteDriver.h"
#include "llvm/Support/raw_ostream.h"

int main() {
  mlir::MLIRContext context;
  context.getOrLoadDialect<toy::ToyDialect>();
  // The PDLL patterns are PDL IR: parsing them needs the pdl dialect, and
  // freezing the pattern set compiles them to pdl_interp. Inside a pass this
  // is handled by `dependentDialects` (ToyPasses.td); a hand-rolled driver
  // must load them itself.
  context.loadDialect<mlir::pdl::PDLDialect, mlir::pdl_interp::PDLInterpDialect>();

  mlir::OpBuilder builder(&context);
  mlir::Location loc = builder.getUnknownLoc();

  // Build a module:  print(add(constant 1.0, constant 2.0))
  //                  print(mul(constant 2.0, constant 3.0))
  mlir::ModuleOp module = mlir::ModuleOp::create(loc);
  builder.setInsertionPointToEnd(module.getBody());

  mlir::Value c1 = builder.create<toy::ConstantOp>(loc, 1.0);   // custom builder
  mlir::Value c2 = builder.create<toy::ConstantOp>(loc, 2.0);
  mlir::Value sum =
      builder.create<toy::AddOp>(loc, builder.getF64Type(), c1, c2);
  builder.create<toy::PrintOp>(loc, sum);

  mlir::Value c3 = builder.create<toy::ConstantOp>(loc, 2.0);
  mlir::Value c4 = builder.create<toy::ConstantOp>(loc, 3.0);
  mlir::Value product =
      builder.create<toy::MulOp>(loc, builder.getF64Type(), c3, c4);
  builder.create<toy::PrintOp>(loc, product);

  mlir::Value c5 = builder.create<toy::ConstantOp>(loc, 5.0);
  mlir::Value c6 = builder.create<toy::ConstantOp>(loc, 3.0);
  mlir::Value difference =
      builder.create<toy::SubOp>(loc, builder.getF64Type(), c5, c6);
  builder.create<toy::PrintOp>(loc, difference);

  // The custom type and attribute (see ../attrs-and-types/). Build them with
  // the generated `get` and let the dialect's generated printer format them.
  toy::ArrayType arrayTy = toy::ArrayType::get(&context, 3, builder.getF64Type());
  toy::ShapeAttr shape = toy::ShapeAttr::get(&context, 3, 4);
  llvm::outs() << "=== custom type & attribute ===\n";
  llvm::outs() << "type : " << arrayTy << "\n";   // !toy.array<3 x f64>
  llvm::outs() << "attr : " << shape << "\n\n";   // #toy.shape<3 x 4>

  // The interfaces (see ../include/Toy/ToyInterfaces.td). Neither loop names
  // AddOp/MulOp/SubOp or ArrayType: they go through the interface handles.
  llvm::outs() << "=== interfaces ===\n";
  module.walk([](toy::BinaryArithOpInterface arith) {
    llvm::outs() << arith->getName() << ": symbol '" << arith.getSymbol()
                 << "', commutative=" << (arith.isCommutative() ? "yes" : "no")
                 << ", evaluate(6, 3)=" << arith.evaluate(6.0, 3.0) << "\n";
  });
  if (auto container = llvm::dyn_cast<toy::ContainerTypeInterface>(mlir::Type(arrayTy)))
    llvm::outs() << arrayTy << ": " << container.getNumElements() << " x "
                 << container.getContainedType() << "\n";
  llvm::outs() << "\n";

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

  llvm::outs() << "=== after folding (DRR: add, PDLL: mul, C++ via interface: sub) ===\n";
  module.print(llvm::outs());
  llvm::outs() << "\n";
  return 0;
}
