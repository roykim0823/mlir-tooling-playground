# =============================================================================
# Capstone: a complete, buildable out-of-tree MLIR dialect.
#
#   cmake -S . -B build -DMLIR_DIR=/opt/homebrew/opt/llvm@20/lib/cmake/mlir
#   cmake --build build
#   ./build/toy-capstone                      # standalone driver
#   ./build/toy-opt test/fold.mlir -toy-fold  # our own mlir-opt (DRR + PDLL patterns)
#   cmake --build build --target check-toy    # the lit test suite in test/
#
# This is the "real" version of what gen-all.sh does ad hoc: it uses MLIR's own
# `mlir_tablegen()` macro to run the backends and wire the generated C++ into a
# dialect library, a driver executable, an opt tool, and a lit test suite.
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

# --- Run mlir-tblgen over the interfaces --------------------------------------
# Separate .td (included by ToyOps.td) so the interface backends have one input.
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include/Toy)
set(LLVM_TARGET_DEFINITIONS include/Toy/ToyInterfaces.td)
mlir_tablegen(include/Toy/ToyOpInterfaces.h.inc     -gen-op-interface-decls)
mlir_tablegen(include/Toy/ToyOpInterfaces.cpp.inc   -gen-op-interface-defs)
mlir_tablegen(include/Toy/ToyTypeInterfaces.h.inc   -gen-type-interface-decls)
mlir_tablegen(include/Toy/ToyTypeInterfaces.cpp.inc -gen-type-interface-defs)
add_public_tablegen_target(ToyInterfacesIncGen)

# --- ...and over the dialect's main source of truth -------------------------
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

# --- ...and over the pass definitions ----------------------------------------
# A second LLVM_TARGET_DEFINITIONS: passes live in their own .td because they
# include mlir/Pass/PassBase.td rather than OpBase.td. `-name Toy` names the
# pass *group*, which becomes the generated `registerToyPasses()`.
set(LLVM_TARGET_DEFINITIONS include/Toy/ToyPasses.td)
mlir_tablegen(include/Toy/ToyPasses.h.inc   -gen-pass-decls -name Toy)
add_public_tablegen_target(ToyPassIncGen)

# --- ...and compile the PDLL patterns --------------------------------------
# Not TableGen: `mlir-pdll -x=cpp` compiles ToyPatterns.pdll into C++ that
# embeds the PDL IR. add_mlir_pdll_library passes this directory's include
# paths as -I, so the `#include "Toy/ToyOps.td"` in the .pdll resolves.
add_mlir_pdll_library(ToyPdllIncGen
  include/Toy/ToyPatterns.pdll
  include/Toy/ToyPdllPatterns.h.inc
  )

# --- The dialect library -----------------------------------------------------
add_mlir_dialect_library(MLIRToy
  lib/ToyDialect.cpp
  lib/ToyInterfaces.cpp
  lib/ToyPatterns.cpp
  lib/ToyPasses.cpp
  lib/ToyTranslate.cpp

  DEPENDS
  ToyInterfacesIncGen
  ToyIncGen
  ToyPassIncGen
  ToyPdllIncGen

  LINK_LIBS PUBLIC
  MLIRIR
  MLIRParser            # the generated PDLL C++ parses its embedded PDL IR
  MLIRPass
  MLIRPDLDialect        # pdl.* ops (the pattern IR)
  MLIRPDLInterpDialect  # pdl_interp.* ops (what PDL is lowered to at freeze time)
  MLIRRewrite           # FrozenRewritePatternSet + the PDL bytecode interpreter
  MLIRSupport
  MLIRTransformUtils
  MLIRTranslateLib      # TranslateFromMLIRRegistration / TranslateToMLIRRegistration (ToyTranslate.cpp)
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
  MLIRTranslateLib      # TranslateFromMLIRRegistration / TranslateToMLIRRegistration (ToyTranslate.cpp)
  )

# --- The opt tool ------------------------------------------------------------
# MLIROptLib is mlir-opt minus main(): file parsing, -pass-pipeline, printing,
# -verify-diagnostics, -split-input-file. toy-opt.cpp adds our dialect + passes.
add_llvm_executable(toy-opt tools/toy-opt.cpp)
llvm_update_compile_flags(toy-opt)
target_link_libraries(toy-opt
  PRIVATE
  MLIRToy
  MLIROptLib
  MLIRFuncDialect      # so tests can wrap toy ops in func.func
  MLIRTransforms       # registerTransformsPasses(): -canonicalize, -cse, ...
  )

# --- The reducer -------------------------------------------------------------
# mlir-reduce minus main(): MlirReduceMain drives the reduction passes over a
# context that knows our dialect. See ../mlir-tools/reduce/ for the tutorial.
add_llvm_executable(toy-reduce tools/toy-reduce.cpp)
llvm_update_compile_flags(toy-reduce)
target_link_libraries(toy-reduce
  PRIVATE
  MLIRToy
  MLIRReduceLib
  MLIRFuncDialect
  MLIRTransforms
  )

# --- The translation tool ------------------------------------------------------
# mlir-translate minus main(): the two registrations in lib/ToyTranslate.cpp
# (in the dialect library) + mlirTranslateMain. See ../mlir-tools/translate/.
add_llvm_executable(toy-translate tools/toy-translate.cpp)
llvm_update_compile_flags(toy-translate)
target_link_libraries(toy-translate
  PRIVATE
  MLIRToy
  MLIRTranslateLib
  MLIRFuncDialect
  )

# --- The language server -----------------------------------------------------
# mlir-lsp-server minus main(): diagnostics, hover, go-to-definition, ... for
# .mlir files that use our dialect. See ../mlir-tools/lsp/ for the tutorial.
add_llvm_executable(toy-lsp-server tools/toy-lsp-server.cpp)
llvm_update_compile_flags(toy-lsp-server)
target_link_libraries(toy-lsp-server
  PRIVATE
  MLIRToy
  MLIRLspServerLib
  MLIRFuncDialect
  )

# --- The plugin: Toy inside the STOCK mlir-opt -------------------------------
# A MODULE library exporting mlirGetDialectPluginInfo / mlirGetPassPluginInfo
# (lib/ToyPlugin.cpp). It must share the host's MLIR, so it links ONLY the
# `MLIR` shared library (libMLIR.dylib / .so) that mlir-opt itself links —
# NOT MLIRToy, whose PUBLIC deps would drag in static copies of MLIRIR & co.
# The Toy code is reused through the object library add_mlir_library creates.
# Plugins are only possible when the install ships that dylib.
if(TARGET MLIR)
  add_llvm_library(ToyPlugin MODULE
    lib/ToyPlugin.cpp
    $<TARGET_OBJECTS:obj.MLIRToy>

    DEPENDS
    ToyInterfacesIncGen
    ToyIncGen
    ToyPassIncGen
    ToyPdllIncGen

    LINK_LIBS
    MLIR
    )
  set(TOY_PLUGIN_AVAILABLE 1)
  message(STATUS "ToyPlugin: enabled (libMLIR found) -> ${CMAKE_CURRENT_BINARY_DIR}/ToyPlugin${LLVM_PLUGIN_EXT} (LLVM MODULE libraries get no lib prefix)")
else()
  set(TOY_PLUGIN_AVAILABLE 0)
  message(STATUS "ToyPlugin: skipped (this LLVM install has no libMLIR shared library)")
endif()

# --- Documentation ----------------------------------------------------------------
# The doc backends render the summary/description fields of the same .td files
# as Markdown. add_mlir_doc(<td without .td> <output name> <subdir> <backend...>)
# is MLIR's helper; out of tree it needs MLIR_BINARY_DIR, which the in-tree
# build provides and MLIRConfig.cmake does not: the helper copies each result
# to ${MLIR_BINARY_DIR}/docs/<subdir>, so point it at our build directory. It
# hangs every per-file *DocGen target on an `mlir-doc` target, which
# MLIRConfig.cmake creates during find_package(MLIR) (guarded anyway).
# Result: `cmake --build build --target mlir-doc` writes build/docs/Toy/*.md.
set(MLIR_BINARY_DIR ${CMAKE_BINARY_DIR})
if(NOT TARGET mlir-doc)
  add_custom_target(mlir-doc)
endif()
add_mlir_doc(include/Toy/ToyOps        ToyDialect        Toy/ -gen-dialect-doc -dialect=toy)
add_mlir_doc(include/Toy/ToyPasses     ToyPasses         Toy/ -gen-pass-doc)
add_mlir_doc(include/Toy/ToyInterfaces ToyOpInterfaces   Toy/ -gen-op-interface-docs)
add_mlir_doc(include/Toy/ToyInterfaces ToyTypeInterfaces Toy/ -gen-type-interface-docs)

# --- The lit test suite ------------------------------------------------------
# Same wiring as ../../lit-and-filecheck/example, now with DEPENDS on our tool
# so `cmake --build build --target check-toy` rebuilds toy-opt first.
#
# An installed LLVM (Homebrew included) ships no llvm-lit, so accept any `lit`
# on PATH (e.g. `pip install lit`) unless -DLLVM_EXTERNAL_LIT was given.
if(NOT LLVM_EXTERNAL_LIT)
  find_program(LLVM_EXTERNAL_LIT NAMES llvm-lit lit)
endif()
if(LLVM_EXTERNAL_LIT)
  configure_lit_site_cfg(
    ${CMAKE_CURRENT_SOURCE_DIR}/test/lit.site.cfg.py.in
    ${CMAKE_CURRENT_BINARY_DIR}/test/lit.site.cfg.py
    MAIN_CONFIG
    ${CMAKE_CURRENT_SOURCE_DIR}/test/lit.cfg.py
    )
  set(TOY_TEST_DEPENDS toy-opt toy-reduce toy-lsp-server toy-translate)
  if(TOY_PLUGIN_AVAILABLE)
    list(APPEND TOY_TEST_DEPENDS ToyPlugin)
  endif()
  add_lit_testsuite(check-toy "Running the Toy capstone lit tests"
    ${CMAKE_CURRENT_BINARY_DIR}/test
    DEPENDS ${TOY_TEST_DEPENDS}
    )
else()
  message(WARNING "No lit runner found; the check-toy target is disabled. "
                  "Install one (pip install lit) or pass -DLLVM_EXTERNAL_LIT=/path/to/lit.")
endif()
