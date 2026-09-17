#!/usr/bin/env bash
# Runnable transcript for the LSP tutorial: drives each server over JSON-RPC
# from a file, no editor needed.
#
#   ./try.sh          # all sections
#   ./try.sh 3        # one section (1..5, numbered like README.md)
#
# Needs mlir-lsp-server / tblgen-lsp-server / mlir-pdll-lsp-server (prebuilt
# LLVM/MLIR). Sections 3-5 need the capstone built (its compilation databases
# and toy-lsp-server) and are skipped with a hint otherwise.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE"
if [[ -z "${LLVM_BIN:-}" ]] && command -v llvm-config >/dev/null 2>&1; then LLVM_BIN="$(llvm-config --bindir)"; fi
if [[ -z "${LLVM_BIN:-}" || ! -x "$LLVM_BIN/mlir-lsp-server" ]]; then
  echo "ERROR: mlir-lsp-server not found${LLVM_BIN:+ in: $LLVM_BIN}. Set LLVM_BIN=/path/to/llvm/bin" >&2; exit 1
fi
export PATH="$LLVM_BIN:$PATH"
CAPSTONE="../../mlir-capstone"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

section() { printf '\n\033[1m==== Section %s — %s ====\033[0m\n' "$1" "$2"; }
run()     { printf '\n\033[36m$ %s\033[0m\n' "$*"; eval "$@"; }
need_capstone() { [[ -f "$CAPSTONE/build/$1" ]] || { printf '\n\033[33m(skipped: build the capstone first — see %s/README.md; missing build/%s)\033[0m\n' "$CAPSTONE" "$1"; return 1; }; }

s1() { section 1 "mlir-lsp-server by hand: diagnostics"
  run "grep -v '^//' sessions/mlir-diagnostics.session | head -3"
  run "mlir-lsp-server --lit-test < sessions/mlir-diagnostics.session 2>/dev/null | ./summarize.py"
  run "mlir-lsp-server --lit-test < sessions/mlir-diagnostics.session 2>/dev/null | grep -B1 -A3 '\"message\": \"use of value'"
}
s2() { section 2 "Navigation: hover, definition, references, symbols"
  run "mlir-lsp-server --lit-test < sessions/mlir-navigation.session 2>/dev/null | ./summarize.py"
}
s3() { section 3 "tblgen-lsp-server + the compilation database"
  need_capstone tablegen_compile_commands.yml || return 0
  run "head -3 $CAPSTONE/build/tablegen_compile_commands.yml | cut -c1-160"
  run "./make-session.py $CAPSTONE/include/Toy/ToyOps.td --hover 84:7 --definition 84:14 --references 84:14 > $TMP/td.session && grep -c . $TMP/td.session"
  run "tblgen-lsp-server --lit-test --tablegen-compilation-database=$CAPSTONE/build/tablegen_compile_commands.yml < $TMP/td.session 2>/dev/null | ./summarize.py"
  run "tblgen-lsp-server --lit-test < $TMP/td.session 2>/dev/null | ./summarize.py | head -4     # WITHOUT the database"
}
s4() { section 4 "mlir-pdll-lsp-server"
  need_capstone pdll_compile_commands.yml || return 0
  run "./make-session.py $CAPSTONE/include/Toy/ToyPatterns.pdll --hover 27:18 --hover 31:27 --definition 31:50 > $TMP/pdll.session"
  run "mlir-pdll-lsp-server --lit-test --pdll-compilation-database=$CAPSTONE/build/pdll_compile_commands.yml < $TMP/pdll.session 2>/dev/null | ./summarize.py"
}
s5() { section 5 "Your own dialect: toy-lsp-server vs the stock server"
  run "mlir-lsp-server --lit-test < sessions/toy.session 2>/dev/null | ./summarize.py | grep -A2 'diagnostics for test:///good'"
  need_capstone toy-lsp-server || return 0
  run "$CAPSTONE/build/toy-lsp-server --lit-test < sessions/toy.session 2>/dev/null | ./summarize.py"
}
which=${1:-all}
case "$which" in
  all) for i in 1 2 3 4 5; do s$i; done ;;
  [1-5]) s"$which" ;;
  *) echo "usage: $0 [all|1..5]" >&2; exit 2 ;;
esac
