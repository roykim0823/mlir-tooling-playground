# =============================================================================
# Builds the C++ examples for the codegen lessons in one shot:
#
#   miniisa_demo    (Lesson 14)  consumes 14_miniisa.gen.h     (td2cpp.py)
#   encoding_demo   (Lesson 15)  consumes 15_encoding.gen.h    (td2cpp.py)
#
# Both use td2cpp.py (--dump-json), so this build needs only Python 3 plus the
# llvm-tblgen that td2cpp.py invokes. For a *real* LLVM backend pipeline (a .td
# consumed by a genuine --gen-* backend), see ../../backend Lesson 6.
#
# Usage (from this directory):
#   cmake -S . -B build
#   cmake --build build
#   ./build/miniisa_demo ; ./build/encoding_demo
# =============================================================================
cmake_minimum_required(VERSION 3.20)
project(tablegen_codegen_examples C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

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
