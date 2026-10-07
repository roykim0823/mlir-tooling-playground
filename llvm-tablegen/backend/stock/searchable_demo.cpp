// Consumer for lesson 2: includes the .inc that --gen-searchable-tables made
// from 02_searchable_tables.td and calls its lookups.
//
// The generated code uses StringRef and ArrayRef, so this links
// libLLVMSupport, as every LLVM tool that includes such a table does.
// CMakeLists.txt runs llvm-tblgen and builds this; searchable_demo.test runs it.
// <algorithm> and <string> are for the generated code (std::lower_bound,
// std::clamp, the std::string key of the by-name index).
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <string>

#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/StringRef.h"

using namespace llvm;

// The enum first: the table's Kind column is a UnitKind.
#define GET_UnitKind_DECL
#include "searchable_tables.inc"

// One member per entry of the table's Fields, in the same order.
struct Inst {
  const char *Name;
  uint8_t Encoding;
  UnitKind Kind;
  bool HasSideFx;
};

// Declarations, then (in exactly one .cpp) definitions.
#define GET_InstTable_DECL
#include "searchable_tables.inc"
#define GET_InstTable_IMPL
#include "searchable_tables.inc"

static const char *unitName(UnitKind K) {
  switch (K) {
  case ALU: return "ALU";
  case BRU: return "BRU";
  case LSU: return "LSU";
  }
  return "?";
}

int main() {
  if (const Inst *I = lookupInstByEncoding(0x10))      // primary key
    std::printf("encoding 0x10 -> %s (%s, hasSideFx=%d)\n", I->Name,
                unitName(I->Kind), I->HasSideFx);

  if (const Inst *I = lookupInstByName("Mul"))          // secondary index
    std::printf("name \"Mul\"    -> encoding 0x%02x\n", I->Encoding);

  if (!lookupInstByEncoding(0x7f))                      // filtered row
    std::printf("encoding 0x7f -> not found (dbg is not Listed)\n");

  if (!lookupInstByEncoding(0x99))                      // early out
    std::printf("encoding 0x99 -> not found (above the last key)\n");
  return 0;
}
