// =============================================================================
// ODS Lesson 11 — Custom builders
//
//   ODS auto-generates `build()` methods, but you often want convenience
//   overloads (e.g. infer the result type, accept a raw C++ value). Declare
//   them in `builders = [ OpBuilder<(ins ...), [{ C++ body }]> ]`.
//
//   `skipDefaultBuilders = 1` suppresses the auto-generated ones if you want
//   full control. Omitting the body just declares the builder (define in C++).
// =============================================================================

include "mlir/IR/OpBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
}

class Toy_Op<string mnemonic, list<Trait> traits = []>
    : Op<Toy_Dialect, mnemonic, traits>;

def ConstantOp : Toy_Op<"constant"> {
  let summary = "constant with a convenience builder";
  let arguments = (ins F64Attr:$value);
  let results = (outs F64:$result);

  let builders = [
    // Build from a raw double: wrap it in an attribute and set the f64 result.
    OpBuilder<(ins "double":$value), [{
      build($_builder, $_state, $_builder.getF64Type(),
            $_builder.getF64FloatAttr(value));
    }]>
  ];
}

def AddOp : Toy_Op<"add"> {
  let summary = "add with a result-type-inferring builder";
  let arguments = (ins F64:$lhs, F64:$rhs);
  let results = (outs F64:$result);

  let builders = [
    // Infer the result type from the lhs operand.
    OpBuilder<(ins "::mlir::Value":$lhs, "::mlir::Value":$rhs), [{
      build($_builder, $_state, lhs.getType(), lhs, rhs);
    }]>
  ];
}
