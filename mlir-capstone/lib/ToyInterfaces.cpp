//===- ToyInterfaces.cpp - Toy interface definitions ----------------------===//
//
// Two things live here:
//   1. the generated interface method bodies (the `getImpl()->...` dispatch),
//   2. the hand-written implementations each op/type owes the interface —
//      TableGen DECLARED these in the op/type classes via
//      DeclareOpInterfaceMethods / DeclareTypeInterfaceMethods; we define them.
//
//===----------------------------------------------------------------------------===//

#include "Toy/ToyInterfaces.h"
#include "Toy/ToyOps.h"

using namespace mlir;
using namespace toy;

// 1. Generated dispatch: BinaryArithOpInterface::evaluate(...) { return getImpl()->evaluate(...); } etc.
#include "Toy/ToyOpInterfaces.cpp.inc"
#include "Toy/ToyTypeInterfaces.cpp.inc"

// 2a. BinaryArithOpInterface implementations. `isCommutative` has a default
//     (false); AddOp and MulOp listed it in DeclareOpInterfaceMethods<..., ["isCommutative"]>
//     to override it, SubOp did not and inherits the default.
double AddOp::evaluate(double lhs, double rhs) { return lhs + rhs; }
llvm::StringRef AddOp::getSymbol() { return "+"; }
bool AddOp::isCommutative() { return true; }

double MulOp::evaluate(double lhs, double rhs) { return lhs * rhs; }
llvm::StringRef MulOp::getSymbol() { return "*"; }
bool MulOp::isCommutative() { return true; }

double SubOp::evaluate(double lhs, double rhs) { return lhs - rhs; }
llvm::StringRef SubOp::getSymbol() { return "-"; }

// 2b. ContainerTypeInterface implementation for !toy.array<N x T>. Type
//     interface methods are const (a Type is a value handle).
int64_t ArrayType::getNumElements() const { return getSize(); }
Type ArrayType::getContainedType() const { return getElementType(); }
