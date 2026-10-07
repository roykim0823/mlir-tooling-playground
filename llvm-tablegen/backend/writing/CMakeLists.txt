# =============================================================================
# Builds the seven tutorial TableGen backends, each a standalone executable that
# links the LLVM TableGen + Support libraries.
#
#   cmake -S . -B build -DLLVM_DIR=/opt/homebrew/opt/llvm@20/lib/cmake/llvm
#   cmake --build build
#   ./build/01-skeleton 1-entry-point/01_skeleton.td
#
# Each lesson's .td has RUN: lines that run its backend; ../../check.sh builds
# this and runs them all with lit.
# =============================================================================
cmake_minimum_required(VERSION 3.20)
project(llvm_tablegen_backend C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(LLVM REQUIRED CONFIG)
message(STATUS "Using LLVM ${LLVM_PACKAGE_VERSION} (LLVM_DIR=${LLVM_DIR})")

list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")
include(AddLLVM)
include(HandleLLVMOptions)   # sets -fno-rtti etc. to match how LLVM was built

# macOS: LLVM's exported zlib/libedit targets carry the SDK's usr/include. When
# the compiler spells its sysroot differently (Homebrew clang: MacOSX26.sdk,
# CMake: MacOSX.sdk), CMake does not recognize that directory as implicit and
# passes it as -isystem ahead of libc++, which breaks every C++ header. Marking
# it implicit makes CMake drop the flag. Apple clang is unaffected either way.
if(APPLE)
  execute_process(COMMAND xcrun --show-sdk-path OUTPUT_VARIABLE sdk
                  OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
  if(sdk)
    list(APPEND CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES "${sdk}/usr/include")
  endif()
endif()

include_directories(${LLVM_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})

# Map the components we use to concrete library names (static .a or the dylib).
llvm_map_components_to_libnames(LLVM_BACKEND_LIBS TableGen Support)

function(add_backend name src)
  add_llvm_executable(${name} ${src})
  llvm_update_compile_flags(${name})
  target_link_libraries(${name} PRIVATE ${LLVM_BACKEND_LIBS})
endfunction()

add_backend(01-skeleton        1-entry-point/01_skeleton.cpp)
add_backend(02-walk-records    2-records-and-values/02_walk_records.cpp)
add_backend(03-init-types      3-init-values/03_init_types.cpp)
add_backend(04-enum-emitter    4-emitting-and-errors/04_enum_emitter.cpp)
add_backend(05-registered-tool 5-registration/05_registered_tool.cpp)
add_backend(06-hierarchy       6-classes-and-lists/06_hierarchy.cpp)
add_backend(07-debugging       7-debugging/07_debugging.cpp)
