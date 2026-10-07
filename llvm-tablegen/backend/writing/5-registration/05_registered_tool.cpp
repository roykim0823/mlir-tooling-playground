//===- 05_registered_tool.cpp - The real llvm-tblgen dispatch pattern -----===//
//
// Lessons 1-4 hard-wired a single backend into TableGenMain. Real tools (like
// llvm-tblgen itself) bundle *many* backends and pick one with a --gen-* flag.
//
// You register each backend with `TableGen::Emitter::OptClass<E>`, where E is a
// class with a `(const RecordKeeper &)` constructor and a `run(raw_ostream &)`
// method. Then `main` just calls `TableGenMain(argv[0])` with no explicit
// function — the selected option's emitter runs.
//
//   ./05-registered-tool --gen-names 5-registration/05_registered_tool.td
//   ./05-registered-tool --gen-count 5-registration/05_registered_tool.td
//
//===----------------------------------------------------------------------------===//

#include "llvm/Support/CommandLine.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/TableGen/Main.h"
#include "llvm/TableGen/Record.h"
#include "llvm/TableGen/TableGenBackend.h"

using namespace llvm;

namespace {

// Backend A: list the names of every Animal record.
class NamesEmitter {
  const RecordKeeper &records;
public:
  explicit NamesEmitter(const RecordKeeper &rk) : records(rk) {}
  void run(raw_ostream &OS) {
    emitSourceFileHeader("Animal names", OS, records);
    for (const Record *R : records.getAllDerivedDefinitions("Animal"))
      OS << "// " << R->getName() << " says \""
         << R->getValueAsString("Sound") << "\"\n";
  }
};

// Backend B: just count them.
class CountEmitter {
  const RecordKeeper &records;
public:
  explicit CountEmitter(const RecordKeeper &rk) : records(rk) {}
  void run(raw_ostream &OS) {
    emitSourceFileHeader("Animal count", OS, records);
    OS << "// " << records.getAllDerivedDefinitions("Animal").size()
       << " animal(s)\n";
  }
};

} // namespace

// Registering an OptClass adds a --<name> command-line option to this tool.
static TableGen::Emitter::OptClass<NamesEmitter>
    X("gen-names", "Emit each animal's name and sound");
static TableGen::Emitter::OptClass<CountEmitter>
    Y("gen-count", "Emit the number of animals");

int main(int argc, char **argv) {
  cl::ParseCommandLineOptions(argc, argv);
  // No explicit backend: TableGenMain runs whichever --gen-* was selected.
  return TableGenMain(argv[0]);
}
