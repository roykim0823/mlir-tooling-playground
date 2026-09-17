# A minimal out-of-tree MLIR project in the layout of upstream's
# mlir/examples/standalone: one CMakeLists.txt per directory, MLIR's own
# helpers for everything. Contrast with ../../mlir-tablegen/capstone-toy, which
# keeps the whole build in one file and spells the tablegen calls out.
#
#   cmake -G Ninja -S . -B build -DMLIR_DIR=$(brew --prefix llvm@20)/lib/cmake/mlir
#   cmake --build build --target check-hello
cmake_minimum_required(VERSION 3.20)
project(hello-dialect LANGUAGES CXX C)
set(CMAKE_CXX_STANDARD 17 CACHE STRING "C++ standard to conform to")

# 1. Find MLIR (which finds LLVM) and bring in the CMake helper modules.
find_package(MLIR REQUIRED CONFIG)
message(STATUS "Using MLIRConfig.cmake in: ${MLIR_DIR}")
list(APPEND CMAKE_MODULE_PATH "${MLIR_CMAKE_DIR}" "${LLVM_CMAKE_DIR}")
include(TableGen)          # tablegen(), add_public_tablegen_target()
include(AddLLVM)           # add_llvm_executable(), add_llvm_library(), add_lit_testsuite()
include(AddMLIR)           # add_mlir_dialect(), add_mlir_dialect_library(), add_mlir_doc(), ...
include(HandleLLVMOptions) # compiler flags matching the LLVM build (RTTI, warnings, ...)

# 2. The in-tree build sets these; an installed MLIRConfig.cmake does not.
set(MLIR_BINARY_DIR ${CMAKE_BINARY_DIR})                # add_mlir_doc() copies docs under it
set(LLVM_RUNTIME_OUTPUT_INTDIR ${CMAKE_BINARY_DIR}/bin) # tools land in build/bin like upstream
set(LLVM_LIBRARY_OUTPUT_INTDIR ${CMAKE_BINARY_DIR}/lib) # libraries in build/lib

# 3. Include paths: MLIR/LLVM headers, our headers, and the GENERATED headers
#    (mlir_tablegen writes next to the .td, but under the build tree).
include_directories(${LLVM_INCLUDE_DIRS} ${MLIR_INCLUDE_DIRS})
include_directories(${PROJECT_SOURCE_DIR}/include)
include_directories(${PROJECT_BINARY_DIR}/include)
add_definitions(${LLVM_DEFINITIONS})

# 4. One directory per concern.
add_subdirectory(include)     # .td -> .inc (code generation only)
add_subdirectory(lib)         # the dialect library
add_subdirectory(hello-opt)   # the tool
add_subdirectory(test)        # lit
