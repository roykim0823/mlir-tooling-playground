#!/usr/bin/env bash
# Generate everything for both pattern languages:
#   drr/**/*.td    -> generated/drr/<lesson>.rewriters.inc      (mlir-tblgen --gen-rewriters)
#   pdll/**/*.pdll -> pdll/generated/<lesson>.pdl.mlir + .cpp.inc (mlir-pdll; see pdll/gen-all.sh)
set -euo pipefail
cd "$(dirname "$0")"

LLVM_PREFIX=/opt/homebrew/opt/llvm@20
TBLGEN="$LLVM_PREFIX/bin/mlir-tblgen"
MLIR_INC="$LLVM_PREFIX/include"

count=0
for td in $(find drr -name '*.td' | sort); do
  count=$((count + 1))
  dest="generated/${td%.td}.rewriters.inc"
  mkdir -p "$(dirname "$dest")"
  "$TBLGEN" --gen-rewriters -I "$MLIR_INC" "$td" -o "$dest"
  echo "  $td  --gen-rewriters"
done
echo "Generated C++ for $count DRR lesson(s) into generated/"
pdll/gen-all.sh
