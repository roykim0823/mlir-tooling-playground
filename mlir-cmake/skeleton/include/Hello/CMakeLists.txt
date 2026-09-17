# add_mlir_dialect(<td name without .td>, <dialect namespace>) expands to six
# mlir_tablegen() calls (-gen-op-decls/-defs, -gen-typedef-decls/-defs,
# -gen-dialect-decls/-defs, all with -dialect=hello) and one
# add_public_tablegen_target(MLIRHelloOpsIncGen). Outputs, in the build tree:
#   HelloOps.h.inc  HelloOps.cpp.inc  HelloOpsTypes.h.inc  HelloOpsTypes.cpp.inc
#   HelloOpsDialect.h.inc  HelloOpsDialect.cpp.inc
# Note the fixed naming: the dialect files are <td>Dialect.*, not <Dialect>.*.
add_mlir_dialect(HelloOps hello)

# Reference docs, built by `cmake --build build --target mlir-doc` (not by default).
add_mlir_doc(HelloOps HelloDialect Hello/ -gen-dialect-doc -dialect=hello)
