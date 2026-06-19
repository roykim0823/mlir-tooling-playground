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

# Locate MLIR's CMake package. Resolution order:
#   1. MLIR_DIR from the environment (explicit override always wins).
#   2. A from-source LLVM/MLIR build at externals/llvm-project/build.
#   3. An installed LLVM/MLIR discovered via llvm-config on PATH (e.g. Homebrew's
#      keg-only llvm@20, whose bin dir is on PATH).
DEFAULT_MLIR_DIR="$HERE/../../../externals/llvm-project/build/lib/cmake/mlir"
if [[ -z "${MLIR_DIR:-}" ]]; then
  if [[ -d "$DEFAULT_MLIR_DIR" ]]; then
    MLIR_DIR="$DEFAULT_MLIR_DIR"
  elif command -v llvm-config >/dev/null 2>&1; then
    MLIR_DIR="$(llvm-config --prefix)/lib/cmake/mlir"
  fi
fi

if [[ -z "${MLIR_DIR:-}" || ! -d "$MLIR_DIR" ]]; then
  echo "ERROR: could not locate MLIR's CMake package${MLIR_DIR:+ (tried: $MLIR_DIR)}." >&2
  echo "Point it at your LLVM build/install:  MLIR_DIR=/path/to/lib/cmake/mlir ./run.sh" >&2
  echo "  (Homebrew: MLIR_DIR=\$(brew --prefix llvm@20)/lib/cmake/mlir)" >&2
  exit 1
fi

# Find a lit runner for the `check` target. A from-source LLVM build ships
# `llvm-lit`, but an installed/Homebrew LLVM does NOT, so fall back to the `lit`
# PyPI package, bootstrapped into a private venv on first run. CMake gets this
# path via -DLLVM_EXTERNAL_LIT.
LIT="${LLVM_EXTERNAL_LIT:-}"
if [[ -z "$LIT" ]]; then
  if command -v llvm-lit >/dev/null 2>&1; then
    LIT="$(command -v llvm-lit)"
  elif command -v lit >/dev/null 2>&1; then
    LIT="$(command -v lit)"
  else
    VENV="$HERE/.lit-venv"
    if [[ ! -x "$VENV/bin/lit" ]]; then
      echo ">> Installing 'lit' into $VENV (this LLVM ships no llvm-lit)"
      python3 -m venv "$VENV"
      "$VENV/bin/pip" install --quiet --upgrade pip lit
    fi
    LIT="$VENV/bin/lit"
  fi
fi

GENERATOR="Unix Makefiles"
command -v ninja >/dev/null 2>&1 && GENERATOR="Ninja"

echo ">> Configuring (MLIR_DIR=$MLIR_DIR, lit=$LIT, generator=$GENERATOR)"
cmake -G "$GENERATOR" -S "$HERE" -B "$BUILD" \
  -DMLIR_DIR="$MLIR_DIR" \
  -DLLVM_EXTERNAL_LIT="$LIT"

echo ">> Building + running the 'check' target (this invokes llvm-lit)"
cmake --build "$BUILD" --target check
