#include "Hello/HelloDialect.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Tools/mlir-opt/MlirOptMain.h"

int main(int argc, char **argv) {
  mlir::DialectRegistry registry;
  registry.insert<hello::HelloDialect, mlir::func::FuncDialect>();
  return mlir::asMainReturnCode(mlir::MlirOptMain(argc, argv, "hello-opt\n", registry));
}
