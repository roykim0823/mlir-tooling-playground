//===- 07_debugging.cpp - Printing records, field diagnostics, timers -----===//
//
// BackGuide: "Printing Error Messages", "Debugging Tools", "Timing TableGen
// Phases".
//
// Three habits that make a backend easier to debug:
//
//   OS << *R                         - print a record exactly as
//                                      --print-records does
//   PrintWarning(RV->getLoc(), msg)  - point a diagnostic at one *field*
//   PrintNote(R->getLoc(), msg)        (RV = R->getValue("F")), then add a
//                                      note pointing at the record
//   records.getTimer().startTimer()  - name a phase of the backend, so
//                                      --time-phases reports it separately
//
//   ./07-debugging 7-debugging/07_debugging.td
//   ./07-debugging --time-phases 7-debugging/07_debugging.td
//
//===----------------------------------------------------------------------===//

#include "llvm/Support/CommandLine.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/TableGen/Error.h"
#include "llvm/TableGen/Main.h"
#include "llvm/TableGen/Record.h"
#include "llvm/TableGen/TGTimer.h"
#include "llvm/TableGen/TableGenBackend.h"

using namespace llvm;

static bool emitLatencies(raw_ostream &OS, const RecordKeeper &records) {
  TGTimer &timer = records.getTimer();

  timer.startTimer("Collect and check latencies");
  ArrayRef<const Record *> ops = records.getAllDerivedDefinitions("Op");
  for (const Record *R : ops) {
    if (R->getValueAsInt("Latency") != 0)
      continue;
    // A RecordVal is one field. Its location is the line that last set it,
    // so the warning lands on `let Latency = 0`, not on the def.
    const RecordVal *field = R->getValue("Latency");
    PrintWarning(field->getLoc(), "latency 0 is treated as 1");
    PrintNote(R->getLoc(), "in this record");
  }

  timer.startTimer("Emit table");      // starting a timer stops the previous one
  emitSourceFileHeader("Latency table", OS, records);
  for (const Record *R : ops)
    OS << "// " << R->getName() << " = "
       << std::max<int64_t>(1, R->getValueAsInt("Latency")) << "\n";

  // The record as --print-records would show it: handy in a debugger, or
  // behind a flag of your own.
  if (const Record *R = records.getDef("DIV"))
    OS << "\n/* DIV as parsed:\n" << *R << "*/\n";
  timer.stopTimer();
  return false;
}

int main(int argc, char **argv) {
  cl::ParseCommandLineOptions(argc, argv);
  return TableGenMain(argv[0], &emitLatencies);
}
