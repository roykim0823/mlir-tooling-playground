// =============================================================================
// ODS Lesson 1 — A Dialect and your first Operation
//
//   ODS (Operation Definition Specification) describes MLIR operations in
//   TableGen. mlir-tblgen reads these records and emits the C++ op classes.
//
//   Everything starts with a `Dialect` (the namespace your ops live in) and a
//   small base `Op` class so every op inherits the dialect + common settings.
//
//   Generate C++ with (see ../../gen-all.sh):
//     mlir-tblgen --gen-dialect-decls -I <mlir-include> 01_dialect.td
//     mlir-tblgen --gen-dialect-defs  -I <mlir-include> 01_dialect.td
//     mlir-tblgen --gen-op-decls      -I <mlir-include> 01_dialect.td
//     mlir-tblgen --gen-op-defs       -I <mlir-include> 01_dialect.td
// =============================================================================

include "mlir/IR/OpBase.td"

// The dialect: a C++ class `ToyDialect` in namespace `::toy`, IR prefix "toy".
def Toy_Dialect : Dialect {
  let name = "toy";
  let summary = "A tiny dialect used by the ODS tutorial.";
  let cppNamespace = "::toy";
}

// Base class every Toy op inherits: binds the dialect and forwards traits.
class Toy_Op<string mnemonic, list<Trait> traits = []>
    : Op<Toy_Dialect, mnemonic, traits>;

// The simplest possible op: no operands, no results, no attributes.
// In IR this prints as `toy.nop`.
def NopOp : Toy_Op<"nop"> {
  let summary = "does nothing";
}
