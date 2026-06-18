# =============================================================================
# Capstone: a complete, buildable out-of-tree MLIR dialect.
#
#   cmake -S . -B build -DMLIR_DIR=/opt/homebrew/opt/llvm@20/lib/cmake/mlir
#   cmake --build build
#   ./build/toy-capstone
#
# This is the "real" version of what gen-all.sh does ad hoc: it uses MLIR's own
# `mlir_tablegen()` macro to run the backends and wire the generated C++ into a
# dialect library + a driver executable.
# =============================================================================
cmake_minimum_required(VERSION 3.20)
project(toy_capstone C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# MLIRConfig pulls in LLVM too. Point -DMLIR_DIR at <prefix>/lib/cmake/mlir.
find_package(MLIR REQUIRED CONFIG)
message(STATUS "Using MLIR ${MLIR_PACKAGE_VERSION} (MLIR_DIR=${MLIR_DIR})")

list(APPEND CMAKE_MODULE_PATH "${MLIR_CMAKE_DIR}" "${LLVM_CMAKE_DIR}")
include(TableGen)
include(AddLLVM)
include(AddMLIR)
include(HandleLLVMOptions)

include_directories(${LLVM_INCLUDE_DIRS} ${MLIR_INCLUDE_DIRS})
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/include)   # where the .inc land
add_definitions(${LLVM_DEFINITIONS})

# --- Run mlir-tblgen over the single source of truth -------------------------
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include/Toy)
set(LLVM_TARGET_DEFINITIONS include/Toy/ToyOps.td)
mlir_tablegen(include/Toy/ToyOps.h.inc      -gen-op-decls)
mlir_tablegen(include/Toy/ToyOps.cpp.inc    -gen-op-defs)
mlir_tablegen(include/Toy/ToyDialect.h.inc  -gen-dialect-decls -dialect=toy)
mlir_tablegen(include/Toy/ToyDialect.cpp.inc -gen-dialect-defs -dialect=toy)
mlir_tablegen(include/Toy/ToyTypes.h.inc    -gen-typedef-decls -typedefs-dialect=toy)
mlir_tablegen(include/Toy/ToyTypes.cpp.inc  -gen-typedef-defs  -typedefs-dialect=toy)
mlir_tablegen(include/Toy/ToyAttrs.h.inc    -gen-attrdef-decls -attrdefs-dialect=toy)
mlir_tablegen(include/Toy/ToyAttrs.cpp.inc  -gen-attrdef-defs  -attrdefs-dialect=toy)
mlir_tablegen(include/Toy/ToyPatterns.inc   -gen-rewriters)
add_public_tablegen_target(ToyIncGen)

# --- The dialect library -----------------------------------------------------
add_mlir_dialect_library(MLIRToy
  lib/ToyDialect.cpp
  lib/ToyPatterns.cpp

  DEPENDS
  ToyIncGen

  LINK_LIBS PUBLIC
  MLIRIR
  MLIRSupport
  MLIRTransformUtils
  )

# --- The driver executable ---------------------------------------------------
add_llvm_executable(toy-capstone tools/toy-capstone.cpp)
llvm_update_compile_flags(toy-capstone)
target_link_libraries(toy-capstone
  PRIVATE
  MLIRToy
  MLIRIR
  MLIRParser
  MLIRSupport
  MLIRTransformUtils
  )
