# =============================================================================
# Runs td2cpp.py, the Python backend, as a build step, and compiles two C++
# programs against the headers it generates:
#
#   miniisa_demo   consumes 16_miniisa.gen.h   (language lesson 16)
#   encoding_demo  consumes 17_encoding.gen.h  (language lesson 17)
#
# Only Python 3 and llvm-tblgen are needed; nothing links LLVM.
#
#   cmake -S . -B build
#   cmake --build build
#   ./build/miniisa_demo ; ./build/encoding_demo
# =============================================================================
cmake_minimum_required(VERSION 3.20)
project(tablegen_codegen_examples C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Python3 REQUIRED COMPONENTS Interpreter)

# The inputs are the language track's capstone lessons.
set(TD_DIR  "${CMAKE_CURRENT_SOURCE_DIR}/../../language/examples")
set(GEN_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
set(TD2CPP  "${CMAKE_CURRENT_SOURCE_DIR}/td2cpp.py")
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

# --- Language lesson 16: MiniISA --------------------------------------------
add_td2cpp_header(16_miniisa.td  16_miniisa.gen.h)
add_executable(miniisa_demo miniisa_demo.cpp "${GEN_DIR}/16_miniisa.gen.h")
target_include_directories(miniisa_demo PRIVATE "${GEN_DIR}")

# --- Language lesson 17: instruction encoding -------------------------------
add_td2cpp_header(17_encoding.td 17_encoding.gen.h)
add_executable(encoding_demo encoding_demo.cpp "${GEN_DIR}/17_encoding.gen.h")
target_include_directories(encoding_demo PRIVATE "${GEN_DIR}")
