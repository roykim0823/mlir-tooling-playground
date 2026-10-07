# Builds the C++ consumer of lesson 2's --gen-searchable-tables output.
#
#   cmake -S . -B build -DLLVM_DIR=/opt/homebrew/opt/llvm@20/lib/cmake/llvm
#   cmake --build build
#   ./build/searchable-demo
#
# The backend here is llvm-tblgen's own; this file runs it and links the
# consumer against libLLVMSupport (../../check.sh does all of this).
cmake_minimum_required(VERSION 3.20)
project(llvm_tablegen_stock C CXX)   # LLVM's CMake probes C too

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(LLVM REQUIRED CONFIG)
message(STATUS "Using LLVM ${LLVM_PACKAGE_VERSION} (LLVM_DIR=${LLVM_DIR})")
list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")
include(AddLLVM)
include(HandleLLVMOptions)   # -fno-rtti etc., to match how LLVM was built

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

find_program(LLVM_TBLGEN llvm-tblgen HINTS "${LLVM_TOOLS_BINARY_DIR}" REQUIRED)

set(TD  "${CMAKE_CURRENT_SOURCE_DIR}/02_searchable_tables.td")
set(INC "${CMAKE_CURRENT_BINARY_DIR}/searchable_tables.inc")
add_custom_command(
  OUTPUT  "${INC}"
  COMMAND ${LLVM_TBLGEN} --gen-searchable-tables -I "${LLVM_INCLUDE_DIRS}" "${TD}" -o "${INC}"
  DEPENDS "${TD}"
  COMMENT "llvm-tblgen --gen-searchable-tables 02_searchable_tables.td"
  VERBATIM)

llvm_map_components_to_libnames(SUPPORT_LIBS Support)
add_executable(searchable-demo searchable_demo.cpp "${INC}")
llvm_update_compile_flags(searchable-demo)
target_include_directories(searchable-demo PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(searchable-demo PRIVATE ${SUPPORT_LIBS})
