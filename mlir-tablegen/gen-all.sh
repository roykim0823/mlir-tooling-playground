#!/usr/bin/env bash
# Run mlir-tblgen over every lesson .td and emit the generated C++ into
# generated/, mirroring the source tree. Output files are named by backend, so a
# file that defines several kinds (e.g. an attr *and* a type) produces several:
#
#   <name>.op-decls.inc / .op-defs.inc            (ops)            ods/
#   <name>.attrdef-decls.inc / .attrdef-defs.inc  (AttrDef/EnumAttr) attrs-and-types/, ods/6-enums/
#   <name>.typedef-decls.inc / .typedef-defs.inc  (TypeDef)        attrs-and-types/
#   <name>.enum-decls.inc / .enum-defs.inc        (I32EnumAttr)    ods/6-enums/
#   <name>.rewriters.inc                          (Pat/Pattern)    drr/
#   <name>.dialect-decls.inc / .dialect-defs.inc  (Dialect)        each tutorial's intro lesson
#   <name>.op-doc.md                              (--gen-op-doc)   ods/ metadata lesson
#
# Unlike the llvm-tablegen searchable-table demo, the emitted MLIR C++ is meant
# to be #included into a dialect library and compiled against libMLIR — see
# capstone-toy/ for a complete, buildable example, and the README for the
# mlir_tablegen() CMake integration.
set -euo pipefail

cd "$(dirname "$0")"

LLVM_PREFIX=/opt/homebrew/opt/llvm@20
TBLGEN="$LLVM_PREFIX/bin/mlir-tblgen"
MLIR_INC="$LLVM_PREFIX/include"
OUT=generated

emit() {  # <td> <suffix> <backend>
  local td="$1" suffix="$2" backend="$3" ext="${4:-inc}"   # ext: inc (C++) or md (docs)
  local dest="$OUT/${td%.td}.$suffix.$ext"
  mkdir -p "$(dirname "$dest")"
  "$TBLGEN" "$backend" -I "$MLIR_INC" "$td" -o "$dest"
  echo "  $td  --$backend"
}

count=0
for td in $(find ods drr attrs-and-types -name '*.td' | sort); do
  count=$((count + 1))
  if [[ "$td" == drr/* ]]; then
    emit "$td" rewriters --gen-rewriters
    continue
  fi
  matched=0
  # Each tutorial's intro lesson introduces the dialect, so also emit the dialect
  # class there. (Every lesson redefines Toy_Dialect for standalone-ness; emitting
  # this for all would just produce identical copies, so it's scoped to the intros.)
  case "$td" in
    */1-dialect-and-ops/01_dialect.td|*/1-basics/01_attrdef.td)
      emit "$td" dialect-decls --gen-dialect-decls
      emit "$td" dialect-defs  --gen-dialect-defs ;;
  esac
  # The metadata lesson is about op documentation, so also emit the Markdown doc.
  if [[ "$td" == */1-dialect-and-ops/02_op_metadata.td ]]; then emit "$td" op-doc --gen-op-doc md; fi
  if grep -q 'AttrDef<'    "$td"; then emit "$td" attrdef-decls --gen-attrdef-decls; emit "$td" attrdef-defs --gen-attrdef-defs; matched=1; fi
  if grep -q 'TypeDef<'    "$td"; then emit "$td" typedef-decls --gen-typedef-decls; emit "$td" typedef-defs --gen-typedef-defs; matched=1; fi
  if grep -q 'I32EnumAttr<' "$td"; then emit "$td" enum-decls --gen-enum-decls;       emit "$td" enum-defs --gen-enum-defs;       matched=1; fi
  # An `EnumAttr<...>` wrapper (distinct from `I32EnumAttr<...>`, note the leading
  # space) defines a dialect attribute, so it has attrdef output too.
  if grep -qE ' EnumAttr<'  "$td"; then emit "$td" attrdef-decls --gen-attrdef-decls; emit "$td" attrdef-defs --gen-attrdef-defs; matched=1; fi
  if grep -q ': Toy_Op<'   "$td"; then emit "$td" op-decls --gen-op-decls;            emit "$td" op-defs --gen-op-defs;            matched=1; fi
  [ "$matched" -eq 0 ] && emit "$td" op-decls --gen-op-decls && emit "$td" op-defs --gen-op-defs
done
echo "Generated C++ for $count .td file(s) into $OUT/"
