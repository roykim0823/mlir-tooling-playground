#!/usr/bin/env bash
# Run mlir-pdll over every lesson .pdll and write both output forms into
# generated/, mirroring the source tree:
#
#   <name>.pdl.mlir   (-x=mlir)  the PDL dialect IR the pattern compiles to
#   <name>.cpp.inc    (-x=cpp)   C++ that embeds that IR + the native bodies
#
# Lessons 2-5 `#include "ToyOps.td"` (shared, in this directory), so the lesson
# root is passed as an include path alongside the MLIR headers. See
# ../../mlir-capstone for the CMake equivalent (add_mlir_pdll_library).
set -euo pipefail

cd "$(dirname "$0")"

LLVM_PREFIX=/opt/homebrew/opt/llvm@20
PDLL="$LLVM_PREFIX/bin/mlir-pdll"
MLIR_INC="$LLVM_PREFIX/include"
OUT=generated

count=0
for src in $(find . -name '*.pdll' -not -path "./$OUT/*" | sed 's|^\./||' | sort); do
  count=$((count + 1))
  base="$OUT/${src%.pdll}"
  mkdir -p "$(dirname "$base")"
  "$PDLL" -x=mlir -I "$MLIR_INC" -I . "$src" -o "$base.pdl.mlir"
  "$PDLL" -x=cpp  -I "$MLIR_INC" -I . "$src" -o "$base.cpp.inc"
  echo "  $src  -> $base.pdl.mlir, $base.cpp.inc"
done
echo "Compiled $count .pdll file(s) into $OUT/"
