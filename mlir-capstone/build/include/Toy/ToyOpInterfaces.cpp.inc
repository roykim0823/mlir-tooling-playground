/*===- TableGen'erated file -------------------------------------*- C++ -*-===*\
|*                                                                            *|
|* Interface Definitions                                                      *|
|*                                                                            *|
|* Automatically generated file, do not edit!                                 *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

/// Evaluate the op on two constant operands.
double toy::BinaryArithOpInterface::evaluate(double lhs, double rhs) {
      return getImpl()->evaluate(getImpl(), getOperation(), lhs, rhs);
  }
/// The operator symbol, for diagnostics.
::llvm::StringRef toy::BinaryArithOpInterface::getSymbol() {
      return getImpl()->getSymbol(getImpl(), getOperation());
  }
/// Whether the operands may be swapped.
bool toy::BinaryArithOpInterface::isCommutative() {
      return getImpl()->isCommutative(getImpl(), getOperation());
  }
/// The left operand.
::mlir::Value toy::BinaryArithOpInterface::getLhsValue() {
      return getImpl()->getLhsValue(getImpl(), getOperation());
  }
/// The right operand.
::mlir::Value toy::BinaryArithOpInterface::getRhsValue() {
      return getImpl()->getRhsValue(getImpl(), getOperation());
  }
