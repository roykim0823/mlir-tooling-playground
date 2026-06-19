# Standalone, CMake-based lit + FileCheck example.
#
# It depends only on a prebuilt LLVM/MLIR (it does NOT build LLVM). Point CMake
# at one with -DMLIR_DIR=/path/to/llvm-build/lib/cmake/mlir (run.sh does this
# for you). The "tool under test" here is the prebuilt `mlir-opt`; see README.md
# for how you would swap in your own `my-opt` in a real project.

cmake_minimum_required(VERSION 3.20)
# C/CXX are enabled (not NONE) because AddLLVM/AddMLIR run compiler/linker
# feature checks at include() time; with no language enabled those checks error.
project(lit_filecheck_example C CXX)

# 1. Find the packages first. find_package(MLIR) transitively pulls in LLVM and
#    sets MLIR_CMAKE_DIR / LLVM_CMAKE_DIR; we also find LLVM explicitly so this
#    works against an *installed* LLVM/MLIR (e.g. Homebrew's llvm@20), not just a
#    from-source build tree.
find_package(MLIR REQUIRED CONFIG)
find_package(LLVM REQUIRED CONFIG)

# 2. Put the MLIR/LLVM CMake module dirs on the search path so include() below
#    can find AddLLVM/AddMLIR/TableGen.
list(APPEND CMAKE_MODULE_PATH "${MLIR_CMAKE_DIR}")
list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")

# 3. Bring in the LLVM/MLIR CMake helpers. AddLLVM provides configure_lit_site_cfg()
#    and add_lit_testsuite() (all this example needs). AddMLIR/TableGen are included
#    too so this file is a drop-in template for a project that also runs
#    mlir_tablegen() on its own .td files.
include(AddLLVM)
include(AddMLIR)
include(TableGen)

# --- This is the standard two-file lit wiring -----------------------------
# 1. The generated site config (build dir) bakes in absolute paths, then
#    load_config()s the hand-written main config (lit.cfg.py) in the source dir.
configure_lit_site_cfg(
  ${CMAKE_CURRENT_SOURCE_DIR}/test/lit.site.cfg.py.in   # template (in source)
  ${CMAKE_CURRENT_BINARY_DIR}/test/lit.site.cfg.py      # generated (in build)
  MAIN_CONFIG
  ${CMAKE_CURRENT_SOURCE_DIR}/test/lit.cfg.py           # the real config
)

# 2. Create a `check` target that runs llvm-lit over the generated site config.
#    No DEPENDS on mlir-opt/FileCheck because they are already built in the
#    prebuilt LLVM we point at. In a project that builds its own tool you would
#    write:  add_lit_testsuite(check "..." ${...}/test DEPENDS my-opt FileCheck)
add_lit_testsuite(check "Running the lit/FileCheck example tests"
  ${CMAKE_CURRENT_BINARY_DIR}/test
)
