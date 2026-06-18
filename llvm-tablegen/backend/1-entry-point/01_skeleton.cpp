//===- 01_skeleton.cpp - The smallest possible TableGen backend -----------===//
//
// A TableGen *backend* is a C++ program that links the LLVM TableGen library,
// parses a .td file into a RecordKeeper, and emits text. The whole contract is:
//
//     bool backend(raw_ostream &OS, const RecordKeeper &records);
//
// Return *false* for success (true tells TableGenMain an error occurred).
// `TableGenMain` does the parsing + command-line handling; you just walk the
// records and write output.
//
// Build/run (see ../README.md, ../CMakeLists.txt):
//     ./01-skeleton 1-entry-point/01_skeleton.td
//
//===----------------------------------------------------------------------------===//

#include "llvm/Support/CommandLine.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/TableGen/Main.h"
#include "llvm/TableGen/Record.h"
#include "llvm/TableGen/TableGenBackend.h"

using namespace llvm;

static bool emitSkeleton(raw_ostream &OS, const RecordKeeper &records) {
  // Standard auto-generated-file banner ("DO NOT EDIT", source file, etc.).
  emitSourceFileHeader("Skeleton backend — record summary", OS, records);

  OS << "// classes parsed: " << records.getClasses().size() << "\n";
  OS << "// records parsed: " << records.getDefs().size() << "\n";

  // getDefs() is a name-sorted map of every concrete `def`.
  for (const auto &entry : records.getDefs())
    OS << "//   def " << entry.first << "\n";

  return false; // success
}

int main(int argc, char **argv) {
  // TableGen's input filename / -I / -o are global cl::opt's; parse them first.
  cl::ParseCommandLineOptions(argc, argv);
  // Parse the .td named on argv, then hand the RecordKeeper to our function.
  return TableGenMain(argv[0], &emitSkeleton);
}
