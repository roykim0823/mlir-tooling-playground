#!/usr/bin/env bash
# Runnable transcript for the CMake tutorial.
#   ./try.sh          # all sections
#   ./try.sh 2        # one section (1..3, numbered like README.md)
# Section 1 builds skeleton/ from scratch in a temporary directory (~1 min);
# sections 2-3 inspect the capstone's existing build and are skipped with a
# hint if it has not been built.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE"
if [[ -z "${MLIR_DIR:-}" ]] && command -v llvm-config >/dev/null 2>&1; then MLIR_DIR="$(llvm-config --prefix)/lib/cmake/mlir"; fi
if [[ -z "${MLIR_DIR:-}" || ! -d "$MLIR_DIR" ]]; then echo "ERROR: set MLIR_DIR=/path/to/lib/cmake/mlir" >&2; exit 1; fi
export PATH="$(dirname "$MLIR_DIR")/../../bin:$PATH"
CAPSTONE="../mlir-tablegen/capstone-toy"
GEN="Unix Makefiles"; command -v ninja >/dev/null 2>&1 && GEN="Ninja"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
section() { printf '\n\033[1m==== Section %s — %s ====\033[0m\n' "$1" "$2"; }
run()     { printf '\n\033[36m$ %s\033[0m\n' "$*"; eval "$@"; }

s1() { section 1 "The skeleton: configure, build, test, docs"
  run "find skeleton -type f | grep -v '/build/' | sort"
  run "cmake -G '$GEN' -S skeleton -B $TMP/build -DMLIR_DIR=$MLIR_DIR 2>&1 | grep -E 'Using MLIR|Configuring done'"
  run "cmake --build $TMP/build >/dev/null 2>&1 && echo 'built (warnings hidden)'"
  run "ls $TMP/build/bin $TMP/build/lib | grep -v CMakeFiles"
  run "ls $TMP/build/include/Hello/ | grep -v '\.d$'     # what add_mlir_dialect(HelloOps hello) generated"
  run "cmake --build $TMP/build --target check-hello 2>&1 | grep -E 'Passed|Failed'"
  run "cmake --build $TMP/build --target mlir-doc >/dev/null && find $TMP/build/docs -type f"
  if [[ "$GEN" == Ninja ]]; then
    run "ninja -C $TMP/build -t commands MLIRHelloOpsIncGen | grep -o 'mlir-tblgen .*' | sed -E 's| -I ?[^ ]*||g'     # the six generated commands, include paths elided"
    run "ninja -C $TMP/build -t targets all | cut -d: -f1 | grep -E '^(MLIRHello|obj\\.MLIRHello|hello-opt|check-hello|mlir-doc|HelloDialectDocGen)\$' | sort"
  fi
  run "grep -c 'FileInfo' $TMP/build/tablegen_compile_commands.yml     # for tblgen-lsp-server; 13 = 6 mlir_tablegen() x2 + add_mlir_doc (see README §4)"
}
s2() { section 2 "Reading the capstone's flat CMakeLists.txt"
  run "grep -nE '^# ---' $CAPSTONE/CMakeLists.txt | sed 's/-*\$//'"
  run "grep -cE '^mlir_tablegen' $CAPSTONE/CMakeLists.txt"
  run "grep -nE '^(add_mlir_|add_llvm_|add_lit_|configure_lit|add_public_tablegen)' $CAPSTONE/CMakeLists.txt | cut -c1-100"
}
s3() { section 3 "Inspecting a build"
  [[ -f $CAPSTONE/build/CMakeCache.txt ]] || { printf '\n\033[33m(skipped: build the capstone first — see %s/README.md)\033[0m\n' "$CAPSTONE"; return 0; }
  run "cmake -LA -N $CAPSTONE/build | grep -E '^(LLVM_DIR|LLVM_EXTERNAL_LIT|CMAKE_BUILD_TYPE|CMAKE_GENERATOR)'"
  run "cmake --build $CAPSTONE/build --target help 2>/dev/null | grep -E 'Toy|toy-|check-toy|mlir-doc' | sed 's/^\\.\\.\\. //' | sort | head -20"
  run "grep -c FileInfo $CAPSTONE/build/tablegen_compile_commands.yml; grep -c FileInfo $CAPSTONE/build/pdll_compile_commands.yml"
  if command -v otool >/dev/null 2>&1; then LDD="otool -L"; else LDD="ldd"; fi
  run "$LDD $CAPSTONE/build/toy-opt | grep libMLIR || echo '(no libMLIR: toy-opt links MLIR statically)'"
  run "$LDD $CAPSTONE/build/ToyPlugin.dylib 2>/dev/null | grep -E 'libMLIR|libLLVM' | awk '{print \$1}'     # the plugin links the dylib"
}
which=${1:-all}
case "$which" in all) for i in 1 2 3; do s$i; done ;; [1-3]) s"$which" ;; *) echo "usage: $0 [all|1..3]" >&2; exit 2 ;; esac
