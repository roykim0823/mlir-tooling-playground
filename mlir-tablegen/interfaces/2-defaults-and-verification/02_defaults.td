//===- 02_defaults.td - Lesson 2: default/shared methods, statics, verify -*- tablegen -*-===//
//
//   mlir-tblgen --gen-op-interface-decls -I $MLIR/include 02_defaults.td
//   mlir-tblgen --gen-op-interface-docs  -I $MLIR/include 02_defaults.td
//
//===----------------------------------------------------------------------------===//

include "mlir/IR/OpBase.td"
include "mlir/IR/Interfaces.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def Toy_Dialect : Dialect { let name = "toy"; let cppNamespace = "::toy"; }
class Toy_Op<string m, list<Trait> t = []> : Op<Toy_Dialect, m, t>;

def BinaryArithOpInterface : OpInterface<"BinaryArithOpInterface"> {
  let description = [{ A binary f64 op that can be evaluated on constants. }];
  let cppNamespace = "::toy";

  let methods = [
    // (a) MUST be implemented by each op (no body, no default) — Lesson 1.
    InterfaceMethod<"Evaluate on two doubles.", "double", "evaluate",
                    (ins "double":$lhs, "double":$rhs)>,

    // (b) DEFAULT implementation (6th argument). Ops get it for free and MAY
    //     override it by listing the method name in DeclareOpInterfaceMethods.
    //     `$_op` is the concrete op instance.
    InterfaceMethod<"Whether lhs and rhs may be swapped.", "bool", "isCommutative",
                    (ins), /*methodBody=*/"", /*defaultImplementation=*/[{
      return false;
    }]>,

    // (c) SHARED body (5th argument). Generated once into the interface's
    //     Model, identical for every op, and CANNOT be overridden. Good for
    //     helpers expressed purely in terms of the generic Operation API.
    InterfaceMethod<"The left operand.", "::mlir::Value", "getLhsValue", (ins), [{
      return $_op->getOperand(0);
    }]>,
    InterfaceMethod<"The right operand.", "::mlir::Value", "getRhsValue", (ins), [{
      return $_op->getOperand(1);
    }]>,

    // (d) STATIC method: no op instance, called as
    //     `BinaryArithOpInterface::Trait<AddOp>::getArity()` or via the
    //     interface object. Here with a shared body.
    StaticInterfaceMethod<"Number of operands every implementer has.",
                          "unsigned", "getArity", (ins), [{ return 2; }]>,
  ];

  // Code pasted into BOTH the interface class and each op's Trait, so it is
  // callable on the interface handle and on the concrete op. `$_op` works.
  let extraSharedClassDeclaration = [{
    /// Evaluate when both operands are the given constants and return the
    /// result as an attribute.
    ::mlir::FloatAttr evaluateAttr(::mlir::FloatAttr lhs, ::mlir::FloatAttr rhs) {
      double r = $_op.evaluate(lhs.getValueAsDouble(), rhs.getValueAsDouble());
      return ::mlir::FloatAttr::get(lhs.getType(), r);
    }
  }];

  // Code pasted ONLY into the interface class (not the op).
  let extraClassDeclaration = [{
    static constexpr ::llvm::StringLiteral getInterfaceDocName() { return "binary-arith"; }
  }];

  // VERIFICATION: runs as part of every implementing op's verifier (like a
  // trait verifier). Return failure() with a diagnostic to reject the op.
  let verify = [{
    if ($_op->getNumOperands() != 2)
      return $_op->emitOpError("BinaryArithOpInterface requires exactly two operands");
    return ::mlir::success();
  }];
}

// AddOp overrides the default `isCommutative` -> the method name goes in the
// second template argument so TableGen DECLARES it in the op class again.
def AddOp : Toy_Op<"add", [Pure, DeclareOpInterfaceMethods<BinaryArithOpInterface, ["isCommutative"]>]> {
  let arguments = (ins F64:$lhs, F64:$rhs);
  let results = (outs F64:$res);
}

// SubOp keeps the default (`false`) — only `evaluate` is declared for it.
def SubOp : Toy_Op<"sub", [Pure, DeclareOpInterfaceMethods<BinaryArithOpInterface>]> {
  let arguments = (ins F64:$lhs, F64:$rhs);
  let results = (outs F64:$res);
}

// C++ you write:
//   double toy::AddOp::evaluate(double l, double r) { return l + r; }
//   bool   toy::AddOp::isCommutative() { return true; }
//   double toy::SubOp::evaluate(double l, double r) { return l - r; }
