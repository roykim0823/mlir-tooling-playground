//===- HelloOps.td - the smallest dialect ---------------------*- tablegen -*-===//
include "mlir/IR/OpBase.td"

def Hello_Dialect : Dialect {
  let name = "hello";
  let summary = "A one-op dialect that exists to show the CMake wiring.";
  let cppNamespace = "::hello";
}

// hello.world : prints nothing, takes nothing — the point is the build.
def WorldOp : Op<Hello_Dialect, "world"> {
  let summary = "does nothing, memorably";
  let assemblyFormat = "attr-dict";
}
