// Demonstrates consuming a real `--gen-searchable-tables` backend output.
//
// Unlike miniisa_demo.cpp (which uses the schema-agnostic td2cpp.py header),
// this consumes the genuine LLVM backend output 16_searchable_table.inc. That
// generated code uses LLVM's StringRef/ArrayRef, so it must link against
// libLLVMSupport — exactly how real LLVM tools consume these tables.
//
// Built by 4-codegen/CMakeLists.txt. Manual build (gen-all.sh emits the .inc):
//   LLVM=/opt/homebrew/opt/llvm@20
//   clang++ -std=c++17 $($LLVM/bin/llvm-config --cxxflags) -I ../generated \
//     4-codegen/searchable_demo.cpp \
//     $($LLVM/bin/llvm-config --ldflags --libs support) -o searchable_demo
#include <cstdint>
#include <cstdio>
#include <string>
#include <algorithm>
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/StringRef.h"

using namespace llvm;

// The "row" struct the generated table expects: one member per `Fields` entry
// in 16_searchable_table.td, in the same order.
struct Inst {
  const char *Name;
  uint8_t     Encoding;
  bool        HasSideFx;
};

// Pull in the generated declarations, then (in this one .cpp) the definitions.
#define GET_InstTable_DECL
#include "16_searchable_table.inc"
#define GET_InstTable_IMPL
#include "16_searchable_table.inc"

int main() {
  if (const Inst *i = lookupInstByEncoding(0x10))   // primary-key binary search
    std::printf("encoding 0x10 -> %-3s (hasSideFx=%d)\n", i->Name, i->HasSideFx);

  if (const Inst *i = lookupInstByName("mul"))       // secondary index search
    std::printf("name \"mul\"   -> encoding 0x%02x\n", i->Encoding);

  if (lookupInstByEncoding(0x99) == nullptr)
    std::printf("encoding 0x99 -> not found (as expected)\n");

  return 0;
}
