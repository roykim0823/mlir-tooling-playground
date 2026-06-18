// =============================================================================
// ODS Lesson 2 — Operation metadata: summary, description, mnemonic
//
//   Every op carries documentation. `summary` is a one-liner; `description` is
//   a long-form `[{ ... }]` block (Markdown) used by `--gen-op-doc`. The
//   mnemonic passed to the base class is the IR name after the dialect prefix.
// =============================================================================

include "mlir/IR/OpBase.td"

def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::toy";
}

class Toy_Op<string mnemonic, list<Trait> traits = []>
    : Op<Toy_Dialect, mnemonic, traits>;

// mnemonic "print" -> IR op `toy.print`, C++ class `PrintOp`.
def PrintOp : Toy_Op<"print"> {
  let summary = "prints its (eventual) operand to stdout";
  let description = [{
    The `toy.print` operation is a placeholder used to demonstrate op
    documentation. The `description` field is emitted verbatim by
    `mlir-tblgen --gen-op-doc` and shown in the dialect's generated docs.

    Example:

    ```mlir
    toy.print
    ```
  }];
}
