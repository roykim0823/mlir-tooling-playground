//===- 01_op_interface.td - Lesson 1: defining an OpInterface ---*- tablegen -*-===//
//
// Traits and interfaces you *use* were covered in ../../ods/ (Lesson 8) and
// ../../attrs-and-types/ (Lesson 9). This track is about DEFINING your own.
//
// An interface is a virtual API that ops from any dialect can implement, so a
// pass can be written once against the interface instead of once per op.
// TableGen generates the C++ interface class, the per-op glue ("Model"), and
// the method declarations inside each implementing op's class.
//
//   mlir-tblgen --gen-op-interface-decls -I $MLIR/include 01_op_interface.td
//   mlir-tblgen --gen-op-interface-defs  -I $MLIR/include 01_op_interface.td
//   mlir-tblgen --gen-op-decls           -I $MLIR/include 01_op_interface.td   # see the ops' side
//
//===----------------------------------------------------------------------------===//

include "mlir/IR/OpBase.td"
include "mlir/IR/Interfaces.td"                     // OpInterface, InterfaceMethod, ...
include "mlir/Interfaces/SideEffectInterfaces.td"   // Pure

def Toy_Dialect : Dialect { let name = "toy"; let cppNamespace = "::toy"; }
class Toy_Op<string m, list<Trait> t = []> : Op<Toy_Dialect, m, t>;

//===----------------------------------------------------------------------------===//
// The interface
//===----------------------------------------------------------------------------===//

// OpInterface<"C++ class name">. The record name is only used in TableGen; the
// string is the C++ class (`::toy::BinaryArithOpInterface`).
def BinaryArithOpInterface : OpInterface<"BinaryArithOpInterface"> {
  let description = [{
    A binary f64 arithmetic op that can be evaluated on constant operands.
  }];
  // Where to put the generated class. Match the dialect's namespace.
  let cppNamespace = "::toy";

  let methods = [
    // InterfaceMethod<description, return type, name, (ins args...)>
    // With no body and no default, every implementing op MUST define
    //   double evaluate(double lhs, double rhs);
    // in C++ — and TableGen declares it inside the op class for you.
    InterfaceMethod<"Evaluate the op on two constant operands.",
                    "double", "evaluate", (ins "double":$lhs, "double":$rhs)>,

    InterfaceMethod<"The operator symbol, for diagnostics.",
                    "::llvm::StringRef", "getSymbol", (ins)>,
  ];
}

//===----------------------------------------------------------------------------===//
// Ops implementing it
//===----------------------------------------------------------------------------===//

// `DeclareOpInterfaceMethods<I>` in the trait list does two things:
//   1. attaches `::toy::BinaryArithOpInterface::Trait` to the op (so
//      isa/dyn_cast<BinaryArithOpInterface>(op) succeed), and
//   2. DECLARES the interface methods in the op class, for you to define.
// Using the bare interface (`[BinaryArithOpInterface]`) does only (1): use it
// when every method has a default (Lesson 2) or the op provides the methods
// some other way (extraClassDeclaration).
def AddOp : Toy_Op<"add", [Pure, DeclareOpInterfaceMethods<BinaryArithOpInterface>]> {
  let arguments = (ins F64:$lhs, F64:$rhs);
  let results = (outs F64:$res);
}

def MulOp : Toy_Op<"mul", [Pure, DeclareOpInterfaceMethods<BinaryArithOpInterface>]> {
  let arguments = (ins F64:$lhs, F64:$rhs);
  let results = (outs F64:$res);
}

// Not every op implements it — this one is deliberately left out so the C++
// below has something for dyn_cast to reject.
def NegOp : Toy_Op<"neg", [Pure]> {
  let arguments = (ins F64:$operand);
  let results = (outs F64:$res);
}

// The C++ side (not generated — you write this, e.g. in ToyOps.cpp):
//
//   double toy::AddOp::evaluate(double l, double r) { return l + r; }
//   llvm::StringRef toy::AddOp::getSymbol() { return "+"; }
//   double toy::MulOp::evaluate(double l, double r) { return l * r; }
//   llvm::StringRef toy::MulOp::getSymbol() { return "*"; }
//
// And a consumer that never names AddOp or MulOp:
//
//   if (auto arith = llvm::dyn_cast<toy::BinaryArithOpInterface>(op))
//     llvm::outs() << arith.getSymbol() << " -> " << arith.evaluate(2.0, 3.0);
