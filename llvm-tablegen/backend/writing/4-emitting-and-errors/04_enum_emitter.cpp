//===- 04_enum_emitter.cpp - Emitting output & reporting errors -----------===//
//
// A realistic small backend: emit a C++ `enum class` from records, guarded the
// LLVM way (GET_* macros), and *validate* the input. When a record is wrong,
// report it with the TableGen error helpers so the message points at the
// offending `def` in the .td source:
//
//   PrintError(rec, msg)       - error, keep going
//   PrintFatalError(rec, msg)  - error, abort immediately
//   PrintWarning / PrintNote   - the non-fatal variants
//
//   ./04-enum-emitter 4-emitting-and-errors/04_enum_emitter.td
//
//===----------------------------------------------------------------------------===//

#include "llvm/ADT/DenseSet.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/TableGen/Error.h"
#include "llvm/TableGen/Main.h"
#include "llvm/TableGen/Record.h"
#include "llvm/TableGen/TableGenBackend.h"

using namespace llvm;

static bool emitEnum(raw_ostream &OS, const RecordKeeper &records) {
  emitSourceFileHeader("Color enum", OS, records);

  ArrayRef<const Record *> cases =
      records.getAllDerivedDefinitions("EnumCase");

  // Validate before emitting: reject negative or duplicate values, blaming the
  // exact record so TableGen prints its source location.
  DenseSet<int64_t> seen;
  for (const Record *R : cases) {
    int64_t v = R->getValueAsInt("Value");
    if (v < 0)
      PrintFatalError(R, "enum value must be non-negative, got " + Twine(v));
    if (!seen.insert(v).second)
      PrintFatalError(R, "duplicate enum value " + Twine(v));
  }

  OS << "#ifdef GET_COLOR_ENUM\n";
  OS << "enum class Color {\n";
  for (const Record *R : cases)
    OS << "  " << R->getName() << " = " << R->getValueAsInt("Value") << ",\n";
  OS << "};\n";
  OS << "#endif // GET_COLOR_ENUM\n";
  return false;
}

int main(int argc, char **argv) {
  cl::ParseCommandLineOptions(argc, argv);
  return TableGenMain(argv[0], &emitEnum);
}
