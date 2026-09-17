# The upstream idiom: collect every dialect library registered with
# add_mlir_dialect_library through the global property, so adding a second
# dialect to lib/ needs no edit here.
get_property(dialect_libs GLOBAL PROPERTY MLIR_DIALECT_LIBS)

add_llvm_executable(hello-opt hello-opt.cpp)
llvm_update_compile_flags(hello-opt)
target_link_libraries(hello-opt PRIVATE ${dialect_libs} MLIROptLib MLIRFuncDialect)
mlir_check_all_link_libraries(hello-opt)   # fail at configure time on a typo'd MLIR* library name
