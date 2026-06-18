// =============================================================================
// Lesson 16 — Running a *real* backend: `--gen-searchable-tables`
//
//   Everything up to here used only the generic `--print-records` / `--dump-json`
//   output. But the whole point of `llvm-tblgen` is its *backends*, which walk
//   the records and emit C++. Most backends need a full target's schema, but
//   `--gen-searchable-tables` is general purpose: include one support file and
//   describe a table, and it emits a `constexpr` array plus binary-search
//   lookup functions.
//
//   Generate the C++ with (see gen-all.sh, which does this for you):
//
//     llvm-tblgen --gen-searchable-tables \
//       -I <llvm-include-dir> 16_searchable_table.td -o 16_searchable_table.inc
//
//   The emitted .inc is guarded by GET_<Table>_DECL / GET_<Table>_IMPL macros:
//   #define GET_InstTable_DECL before including it to pull in the declarations,
//   GET_InstTable_IMPL (in exactly one .cpp) to pull in the definitions.
// =============================================================================

include "llvm/TableGen/SearchableTable.td"

// The "row" class. Every record that derives from Inst becomes a table row.
class Inst<string name, bits<8> enc> {
  string  Name      = name;
  bits<8> Encoding  = enc;
  bit     HasSideFx = 0;
}

// Rows can be anonymous (`def :`) — they only need to exist to populate tables.
def : Inst<"add", 0x01>;
def : Inst<"sub", 0x02>;
def : Inst<"mul", 0x03>;
def : Inst<"ld",  0x10> { let HasSideFx = 1; }
def : Inst<"st",  0x11> { let HasSideFx = 1; }

// 1) GenericTable -> a `constexpr Inst InstTable[]` plus a primary-key lookup.
def InstTable : GenericTable {
  let FilterClass     = "Inst";          // which records become rows
  let Fields          = ["Name", "Encoding", "HasSideFx"];
  let PrimaryKey      = ["Encoding"];     // sorted column -> binary search
  let PrimaryKeyName  = "lookupInstByEncoding";
}

// 2) A secondary index -> a second binary-search lookup, by a different key.
def lookupInstByName : SearchIndex {
  let Table = InstTable;
  let Key   = ["Name"];
}
