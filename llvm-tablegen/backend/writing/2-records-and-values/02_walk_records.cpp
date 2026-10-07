//===- 02_walk_records.cpp - Finding records and reading typed fields -----===//
//
// The bread-and-butter of a backend: select the records you care about and
// read their fields with the typed accessors.
//
//   records.getAllDerivedDefinitions("C")  -> every def that inherits class C
//   R->getName()                            -> the record's name
//   R->getValueAsString("F")  / getValueAsInt / getValueAsBit / ...
//
// Here we turn every `Instruction` record into a row of a C++ table — a tiny
// version of what --gen-instr-info does for a real target.
//
//   ./02-walk-records 2-records-and-values/02_walk_records.td
//
//===----------------------------------------------------------------------------===//

#include "llvm/Support/CommandLine.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/TableGen/Main.h"
#include "llvm/TableGen/Record.h"
#include "llvm/TableGen/TableGenBackend.h"

using namespace llvm;

static bool emitInstrTable(raw_ostream &OS, const RecordKeeper &records) {
  emitSourceFileHeader("Instruction table", OS, records);

  OS << "struct InstInfo { const char *mnemonic; int opcode; bool isTerm; };\n\n";
  OS << "static const InstInfo Insts[] = {\n";

  for (const Record *R : records.getAllDerivedDefinitions("Instruction")) {
    OS << "  { "
       << '"' << R->getValueAsString("Mnemonic") << "\", "
       << R->getValueAsInt("Opcode") << ", "
       << (R->getValueAsBit("IsTerminator") ? "true" : "false")
       << " }, // " << R->getName() << "\n";
  }

  OS << "};\n";
  return false;
}

int main(int argc, char **argv) {
  cl::ParseCommandLineOptions(argc, argv);
  return TableGenMain(argv[0], &emitInstrTable);
}
