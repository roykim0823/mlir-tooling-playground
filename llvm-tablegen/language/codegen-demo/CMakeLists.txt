# =============================================================================
# Builds the C++ examples for the "backends" lessons in one shot:
#
#   miniisa_demo    (Lesson 14)  consumes 14_miniisa.gen.h     (td2cpp.py)
#   encoding_demo   (Lesson 15)  consumes 15_encoding.gen.h    (td2cpp.py)
#   searchable_demo (Lesson 16)  consumes 16_searchable_table.inc
#                                 (real `llvm-tblgen --gen-searchable-tables`)
#
# Usage (from this directory):
#   cmake -S . -B build
#   cmake --build build
#   ./build/miniisa_demo ; ./build/encoding_demo ; ./build/searchable_demo
#
# Requires an LLVM install with development files (e.g. `brew install llvm@20`).
# Point CMake at it if it is not auto-detected:
#   cmake -S . -B build -DLLVM_DIR=/opt/homebrew/opt/llvm@20/lib/cmake/llvm
# =============================================================================
cmake_minimum_required(VERSION 3.20)
project(tablegen_backend_examples C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# --- Locate LLVM and its tools ----------------------------------------------
find_package(LLVM REQUIRED CONFIG)
message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION} (LLVM_DIR=${LLVM_DIR})")

find_program(LLVM_TBLGEN llvm-tblgen HINTS "${LLVM_TOOLS_BINARY_DIR}")
if(NOT LLVM_TBLGEN)
  message(FATAL_ERROR "llvm-tblgen not found near ${LLVM_TOOLS_BINARY_DIR}")
endif()

find_package(Python3 REQUIRED COMPONENTS Interpreter)

# Lesson .td files live one level up in solution/; this directory holds only the
# C++ demo drivers + this build file.
set(TD_DIR  "${CMAKE_CURRENT_SOURCE_DIR}/../solution")
set(GEN_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
set(TD2CPP  "${CMAKE_CURRENT_SOURCE_DIR}/../td2cpp.py")
file(MAKE_DIRECTORY "${GEN_DIR}")

# --- Helper: generate a generic C++ header via td2cpp.py (--dump-json) -------
function(add_td2cpp_header td_name out_header)
  add_custom_command(
    OUTPUT  "${GEN_DIR}/${out_header}"
    COMMAND ${Python3_EXECUTABLE} "${TD2CPP}"
            --out-dir "${GEN_DIR}" "${TD_DIR}/${td_name}"
    DEPENDS "${TD_DIR}/${td_name}" "${TD2CPP}"
    COMMENT "td2cpp.py: ${td_name} -> ${out_header}"
    VERBATIM)
endfunction()

# --- Lesson 14: MiniISA capstone --------------------------------------------
add_td2cpp_header(14_miniisa.td  14_miniisa.gen.h)
add_executable(miniisa_demo miniisa_demo.cpp "${GEN_DIR}/14_miniisa.gen.h")
target_include_directories(miniisa_demo PRIVATE "${GEN_DIR}")

# --- Lesson 15: instruction encoding ----------------------------------------
add_td2cpp_header(15_encoding.td 15_encoding.gen.h)
add_executable(encoding_demo encoding_demo.cpp "${GEN_DIR}/15_encoding.gen.h")
target_include_directories(encoding_demo PRIVATE "${GEN_DIR}")

# --- Lesson 16: a real LLVM backend (--gen-searchable-tables) ----------------
add_custom_command(
  OUTPUT  "${GEN_DIR}/16_searchable_table.inc"
  COMMAND ${LLVM_TBLGEN} --gen-searchable-tables
          -I "${LLVM_INCLUDE_DIRS}"
          "${TD_DIR}/16_searchable_table.td"
          -o "${GEN_DIR}/16_searchable_table.inc"
  DEPENDS "${TD_DIR}/16_searchable_table.td"
  COMMENT "llvm-tblgen --gen-searchable-tables: 16_searchable_table.td -> .inc"
  VERBATIM)

add_executable(searchable_demo searchable_demo.cpp
               "${GEN_DIR}/16_searchable_table.inc")
target_include_directories(searchable_demo PRIVATE "${GEN_DIR}" ${LLVM_INCLUDE_DIRS})
target_compile_definitions(searchable_demo PRIVATE ${LLVM_DEFINITIONS})

# The generated lookups use LLVM's StringRef/ArrayRef -> link libLLVMSupport.
# Prefer the static component lib; fall back to the shared libLLVM if that is
# all the install provides (e.g. some Homebrew builds).
if(TARGET LLVMSupport)
  target_link_libraries(searchable_demo PRIVATE LLVMSupport)
elseif(TARGET LLVM)
  target_link_libraries(searchable_demo PRIVATE LLVM)
else()
  llvm_map_components_to_libnames(_llvm_support_lib support)
  target_link_libraries(searchable_demo PRIVATE ${_llvm_support_lib})
endif()
