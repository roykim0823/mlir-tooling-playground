// RUN: llvm-tblgen --gen-searchable-tables -I %llvm_include %s | FileCheck %s
//
// Lesson 2 — --gen-searchable-tables
// BackEnds: "SearchableTables", "SearchableTables Reference"
//
// The one code-generating backend with no fixed schema: include
// SearchableTable.td, describe an enum or a table with records, and it emits
// C++ enums, constexpr arrays and lookup functions. ARM and AArch64 use it for
// system registers. searchable_demo.cpp includes the output and calls the
// lookups; CMakeLists.txt builds it.
//
// Every block of the output is guarded: GET_<Name>_DECL for declarations,
// GET_<Name>_IMPL for definitions. Define the macro, then #include the file.
// This is the convention of every LLVM backend's .inc file.

include "llvm/TableGen/SearchableTable.td"

// ---- GenericEnum: a C++ enum from records -----------------------------------
// One enumerator per record of FilterClass. ValueField names the field that
// holds the value; without it, values are assigned 0, 1, ... in name order.
class Unit;
def ALU : Unit;
def LSU : Unit;
def BRU : Unit;
def UnitKind : GenericEnum {
  let FilterClass = "Unit";
}
// CHECK-LABEL: #ifdef GET_UnitKind_DECL
// CHECK-NEXT:  enum UnitKind {
// CHECK-NEXT:    ALU = 0,
// CHECK-NEXT:    BRU = 1,
// CHECK-NEXT:    LSU = 2,
// CHECK-NEXT:  };

// ---- GenericTable: rows, a primary key, and a lookup ------------------------
// Every record derived from FilterClass is a row, unless FilterClassField
// names a bit that is 0. Fields picks the columns, in order. The table is
// sorted by PrimaryKey, and PrimaryKeyName is a binary-search lookup on it.
class Inst<string name, bits<8> enc, Unit unit> {
  string  Name      = name;
  bits<8> Encoding  = enc;
  Unit    Kind      = unit;
  bit     HasSideFx = 0;
  bit     Listed    = 1;
}
// Rows are usually anonymous: only their contents matter.
def : Inst<"add", 0x01, ALU>;
def : Inst<"sub", 0x02, ALU>;
def : Inst<"mul", 0x03, ALU>;
def : Inst<"ld",  0x10, LSU> { let HasSideFx = 1; }
def : Inst<"st",  0x11, LSU> { let HasSideFx = 1; }
def : Inst<"jmp", 0x20, BRU>;
def : Inst<"dbg", 0x7f, ALU> { let Listed = 0; }   // filtered out

def InstTable : GenericTable {
  let FilterClass      = "Inst";
  let FilterClassField = "Listed";
  let Fields           = ["Name", "Encoding", "Kind", "HasSideFx"];
  // bit, bits<n>, string, Intrinsic and Instruction fields are recognized.
  // Others need their C++ type: Kind is a UnitKind enumerator.
  string TypeOf_Kind   = "UnitKind";
  let PrimaryKey       = ["Encoding"];
  let PrimaryKeyName   = "lookupInstByEncoding";
  // Reject keys outside [first, last] before searching.
  let PrimaryKeyEarlyOut = 1;
}
// CHECK-LABEL: #ifdef GET_InstTable_DECL
// CHECK-NEXT:  const Inst *lookupInstByEncoding(uint8_t Encoding);
// CHECK-NEXT:  const Inst *lookupInstByName(StringRef Name);
// CHECK-LABEL: #ifdef GET_InstTable_IMPL
// CHECK-NEXT:  constexpr Inst InstTable[] = {
// CHECK-NEXT:    { "add", 0x1, ALU, false }, // 0
// CHECK-NEXT:    { "sub", 0x2, ALU, false }, // 1
// CHECK-NEXT:    { "mul", 0x3, ALU, false }, // 2
// CHECK-NEXT:    { "ld", 0x10, LSU, true }, // 3
// CHECK-NEXT:    { "st", 0x11, LSU, true }, // 4
// CHECK-NEXT:    { "jmp", 0x20, BRU, false }, // 5
// CHECK-NEXT:   };
// CHECK:       const Inst *lookupInstByEncoding(uint8_t Encoding) {
// CHECK-NEXT:    if ((uint8_t)Encoding != std::clamp((uint8_t)Encoding, (uint8_t)0x1, (uint8_t)0x20))
// CHECK-NEXT:      return nullptr;

// ---- SearchIndex: a second lookup on another key ----------------------------
// It sorts an index array by Key and binary-searches it. String keys compare
// case-insensitively: the stored names are upper-cased.
def lookupInstByName : SearchIndex {
  let Table = InstTable;
  let Key   = ["Name"];
}
// CHECK:       const Inst *lookupInstByName(StringRef Name) {
// CHECK:         static const struct IndexType Index[] = {
// CHECK-NEXT:      { "ADD", 0 },
// CHECK:         KeyType Key = {Name.upper()};

// The file ends by #undef-ing every GET_ macro, so a consumer can include it
// once per block it wants.
// CHECK:      #undef GET_InstTable_DECL
// CHECK-NEXT: #undef GET_InstTable_IMPL
// CHECK-NEXT: #undef GET_UnitKind_DECL
