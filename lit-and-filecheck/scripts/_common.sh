# Shared helpers for the per-chapter "Try it" scripts. Source this; don't run it.
#
# Locates the LLVM/MLIR tools, ensures the example project is built, and provides
# small helpers that echo each command before running it (so the terminal output
# doubles as a transcript of the tutorial).
#
# Override the tool location with:  LLVM_BIN=/path/to/llvm-build/bin ./try-0X.sh
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
EXAMPLE="$TUT_DIR/example"

# Default: the LLVM build bundled in this repo (tutorials/lit-and-filecheck -> .. -> .. -> externals).
DEFAULT_BIN="$TUT_DIR/../../externals/llvm-project/build/bin"
LLVM_BIN="${LLVM_BIN:-$DEFAULT_BIN}"

if [[ ! -x "$LLVM_BIN/mlir-opt" || ! -x "$LLVM_BIN/FileCheck" || ! -x "$LLVM_BIN/llvm-lit" ]]; then
  echo "ERROR: mlir-opt/FileCheck/llvm-lit not found in: $LLVM_BIN" >&2
  echo "Point LLVM_BIN at your LLVM build's bin dir:  LLVM_BIN=/path/to/llvm-build/bin $0" >&2
  exit 1
fi
export PATH="$LLVM_BIN:$PATH"

# Print a banner for a tutorial section.
section() {
  echo
  echo "==================================================================="
  echo "==  $*"
  echo "==================================================================="
}

# Echo a command, then run it (via the shell so pipes/redirs/subs work).
run() { echo; echo "\$ $1"; eval "$1"; }

# Like run(), but the command is EXPECTED to fail (e.g. demonstrating a
# FileCheck mismatch). Non-zero exit is reported as success.
run_expect_fail() {
  echo; echo "\$ $1   # (expected to fail — this is the lesson)"
  if eval "$1"; then echo "!! UNEXPECTEDLY SUCCEEDED"; return 1; else echo "(failed as expected ✓)"; fi
}

# Build the example project once if its generated lit config isn't present.
# Derives MLIR_DIR from LLVM_BIN so a custom LLVM_BIN stays consistent.
ensure_built() {
  if [[ ! -f "$EXAMPLE/build/test/lit.site.cfg.py" ]]; then
    echo ">> Example not built yet; running example/run.sh (one-time)…"
    local mlir_dir="$(cd "$LLVM_BIN/.." && pwd)/lib/cmake/mlir"
    ( cd "$EXAMPLE" && MLIR_DIR="$mlir_dir" ./run.sh >/dev/null 2>&1 )
    echo ">> Built."
  fi
}
