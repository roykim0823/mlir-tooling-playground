// Lesson 6 — consuming a *stock* `--gen-searchable-tables` backend's output.
//
// Lessons 1–5 wrote backends in C++; here `llvm-tblgen`'s own
// `--gen-searchable-tables` emits 06_searchable_table.inc and this file is just
// the *consumer*. The generated code uses LLVM's StringRef/ArrayRef, so it must
// link against libLLVMSupport — exactly how real LLVM tools consume these tables.
//
// Built by ../CMakeLists.txt (run-all.sh builds + runs it). Manual build:
//   LLVM=/opt/homebrew/opt/llvm@20
//   $LLVM/bin/llvm-tblgen --gen-searchable-tables -I "$LLVM/include" \
//     06_searchable_table.td -o 06_searchable_table.inc
//   clang++ -std=c++17 $($LLVM/bin/llvm-config --cxxflags) -I . \
//     06_searchable_demo.cpp \
//     $($LLVM/bin/llvm-config --ldflags --libs support) -o searchable_demo
#include <cstdint>
#include <cstdio>
#include <string>
#include <algorithm>
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/StringRef.h"

using namespace llvm;

// The "row" struct the generated table expects: one member per `Fields` entry
// in 06_searchable_table.td, in the same order.
struct Inst {
  const char *Name;
  uint8_t     Encoding;
  bool        HasSideFx;
};

// Pull in the generated declarations, then (in this one .cpp) the definitions.
#define GET_InstTable_DECL
#include "06_searchable_table.inc"
#define GET_InstTable_IMPL
#include "06_searchable_table.inc"

int main() {
  if (const Inst *i = lookupInstByEncoding(0x10))   // primary-key binary search
    std::printf("encoding 0x10 -> %-3s (hasSideFx=%d)\n", i->Name, i->HasSideFx);

  if (const Inst *i = lookupInstByName("mul"))       // secondary index search
    std::printf("name \"mul\"   -> encoding 0x%02x\n", i->Encoding);

  if (lookupInstByEncoding(0x99) == nullptr)
    std::printf("encoding 0x99 -> not found (as expected)\n");

  return 0;
}
