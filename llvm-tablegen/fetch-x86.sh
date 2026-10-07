#!/usr/bin/env bash
# Download the X86 target's .td files into x86/ (git-ignored), pinned to the
# release tag that matches the local llvm-tblgen.
#
# Homebrew's LLVM ships the target-independent .td libraries under
# include/llvm/ (Target/Target.td, IR/Intrinsics.td, TableGen/SearchableTable.td)
# but not the per-target sources in llvm/lib/Target/<T>/. A .td file only parses
# with the tblgen it was written for, so the tag is taken from
# `llvm-tblgen --version` instead of being hard-coded.
#
# Files are discovered by following `include "X86*.td"` from X86.td, so the
# download is exactly the closure llvm-tblgen needs and nothing more.
#
#   ./fetch-x86.sh                 # LLVM_BIN defaults to Homebrew's llvm@20
#   LLVM_BIN=/path/to/bin ./fetch-x86.sh
set -euo pipefail
cd "$(dirname "$0")"

LLVM_BIN=${LLVM_BIN:-/opt/homebrew/opt/llvm@20/bin}
VERSION=$("$LLVM_BIN/llvm-tblgen" --version | sed -n 's/.*LLVM version \([0-9][0-9.]*\).*/\1/p')
[[ -n "$VERSION" ]] || { echo "cannot read a version from $LLVM_BIN/llvm-tblgen" >&2; exit 1; }
TAG=llvmorg-$VERSION
BASE=https://raw.githubusercontent.com/llvm/llvm-project/$TAG/llvm/lib/Target/X86

OUT=x86
mkdir -p "$OUT"
if [[ -f $OUT/.tag && $(cat $OUT/.tag) == "$TAG" && -f $OUT/X86.td ]]; then
  echo "x86/ already holds $TAG ($(ls $OUT/*.td | wc -l | tr -d ' ') files)"
  exit 0
fi
rm -f "$OUT"/*.td

queue=(X86.td)
while ((${#queue[@]})); do
  f=${queue[0]}; queue=("${queue[@]:1}")
  [[ -f $OUT/$f ]] && continue
  curl -fsSL "$BASE/$f" -o "$OUT/$f"
  # Target-local includes only; "llvm/..." ones resolve against -I $LLVM/include.
  while IFS= read -r inc; do
    [[ -f $OUT/$inc ]] || queue+=("$inc")
  done < <(sed -n 's/^include "\([^/"]*\.td\)".*/\1/p' "$OUT/$f")
done

echo "$TAG" > "$OUT/.tag"
echo "fetched $(ls $OUT/*.td | wc -l | tr -d ' ') X86 .td files at $TAG into $OUT/"
