#!/usr/bin/env bash
# One-command build + test for the standalone lit/FileCheck example.
#
#   ./run.sh           configure (if needed), build the `check` target, run tests
#   ./run.sh clean      remove the build directory
#
# Requires a prebuilt LLVM/MLIR. By default it auto-detects the one shipped in
# this repo; override with:  MLIR_DIR=/path/to/llvm-build/lib/cmake/mlir ./run.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$HERE/build"

if [[ "${1:-}" == "clean" ]]; then
  rm -rf "$BUILD"
  echo "removed $BUILD"
  exit 0
fi

# Default MLIR_DIR: the LLVM build bundled in this tutorial repo (4 levels up:
# example/ -> lit-and-filecheck/ -> tutorials/ -> mlir-tutorial/).
DEFAULT_MLIR_DIR="$HERE/../../../externals/llvm-project/build/lib/cmake/mlir"
MLIR_DIR="${MLIR_DIR:-$DEFAULT_MLIR_DIR}"

if [[ ! -d "$MLIR_DIR" ]]; then
  echo "ERROR: MLIR_DIR not found: $MLIR_DIR" >&2
  echo "Point it at your LLVM build:  MLIR_DIR=/path/to/llvm-build/lib/cmake/mlir ./run.sh" >&2
  exit 1
fi

GENERATOR="Unix Makefiles"
command -v ninja >/dev/null 2>&1 && GENERATOR="Ninja"

echo ">> Configuring (MLIR_DIR=$MLIR_DIR, generator=$GENERATOR)"
cmake -G "$GENERATOR" -S "$HERE" -B "$BUILD" -DMLIR_DIR="$MLIR_DIR"

echo ">> Building + running the 'check' target (this invokes llvm-lit)"
cmake --build "$BUILD" --target check
