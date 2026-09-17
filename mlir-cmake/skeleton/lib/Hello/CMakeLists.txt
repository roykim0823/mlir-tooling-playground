# add_mlir_dialect_library -> add_mlir_library -> llvm_add_library:
#   DEPENDS    makes the .inc files exist before this compiles
#   LINK_LIBS  PUBLIC so users of MLIRHello get MLIRIR transitively
# It also records MLIRHello in the global MLIR_DIALECT_LIBS property (used by
# hello-opt/CMakeLists.txt) and creates an obj.MLIRHello object library.
add_mlir_dialect_library(MLIRHello
  HelloDialect.cpp

  DEPENDS
  MLIRHelloOpsIncGen

  LINK_LIBS PUBLIC
  MLIRIR
  )
