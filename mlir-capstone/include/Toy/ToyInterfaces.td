//===- ToyInterfaces.td - Toy interfaces -----------------------*- tablegen -*-===//
//
// The interfaces the Toy dialect defines (see ../../../interfaces/ for the
// lessons). Kept in their own .td so ToyOps.td can include it and so the
// interface backends have a single input:
//
//   --gen-op-interface-decls / -defs     -> ToyOpInterfaces.{h,cpp}.inc
//   --gen-type-interface-decls / -defs   -> ToyTypeInterfaces.{h,cpp}.inc
//
//===----------------------------------------------------------------------------===//

#ifndef TOY_INTERFACES
#define TOY_INTERFACES

include "mlir/IR/Interfaces.td"

// Any binary f64 op that can be evaluated on constant operands. The pass and a
// C++ pattern are written against THIS, not against AddOp/MulOp/SubOp, so a
// new arithmetic op only has to implement the interface to be folded.
def BinaryArithOpInterface : OpInterface<"BinaryArithOpInterface"> {
  let description = [{
    A binary f64 arithmetic operation that can be evaluated on constant
    operands. Implemented by toy.add, toy.mul and toy.sub.
  }];
  let cppNamespace = "::toy";

  let methods = [
    // Must be implemented by every op.
    InterfaceMethod<"Evaluate the op on two constant operands.",
                    "double", "evaluate", (ins "double":$lhs, "double":$rhs)>,
    InterfaceMethod<"The operator symbol, for diagnostics.",
                    "::llvm::StringRef", "getSymbol", (ins)>,
    // Default: not commutative. toy.add / toy.mul override it.
    InterfaceMethod<"Whether the operands may be swapped.",
                    "bool", "isCommutative", (ins), "", [{ return false; }]>,
    // Shared bodies: same for every implementer, not overridable.
    InterfaceMethod<"The left operand.", "::mlir::Value", "getLhsValue", (ins),
                    [{ return $_op->getOperand(0); }]>,
    InterfaceMethod<"The right operand.", "::mlir::Value", "getRhsValue", (ins),
                    [{ return $_op->getOperand(1); }]>,
  ];
}

// Any type that is a fixed-size container of one element type. Implemented by
// !toy.array<N x T>. (Method names avoid the ODS parameter accessors
// getSize()/getElementType() that ArrayType already has.)
def ContainerTypeInterface : TypeInterface<"ContainerTypeInterface"> {
  let description = [{ A type holding a known number of elements of one type. }];
  let cppNamespace = "::toy";
  let methods = [
    InterfaceMethod<"Number of elements.", "int64_t", "getNumElements", (ins)>,
    InterfaceMethod<"The element type.", "::mlir::Type", "getContainedType", (ins)>,
  ];
}

#endif // TOY_INTERFACES
