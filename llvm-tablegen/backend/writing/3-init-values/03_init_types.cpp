//===- 03_init_types.cpp - The Init value hierarchy -----------------------===//
//
// Every field value is an `Init`. The typed accessors (getValueAsInt, ...) are
// convenience wrappers; underneath, you can inspect a value generically by
// `dyn_cast`-ing its Init to the concrete kind:
//
//   BitInit    - a single 0/1            IntInit    - a 64-bit integer
//   BitsInit   - a fixed bit vector      StringInit - a string
//   ListInit   - a homogeneous list      DefInit    - a reference to a record
//   DagInit    - a (op arg, ...) node    UnsetInit  - the `?` value
//
// This backend walks every field of one record and reports each value's kind —
// the technique you use for fields whose type you don't know in advance.
//
//   ./03-init-types 3-init-values/03_init_types.td
//
//===----------------------------------------------------------------------------===//

#include "llvm/Support/CommandLine.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/TableGen/Main.h"
#include "llvm/TableGen/Record.h"
#include "llvm/TableGen/TableGenBackend.h"

using namespace llvm;

static void describe(raw_ostream &OS, const Init *V) {
  if (isa<UnsetInit>(V))
    OS << "? (unset)";
  else if (const auto *I = dyn_cast<IntInit>(V))
    OS << "int " << I->getValue();
  else if (const auto *B = dyn_cast<BitInit>(V))
    OS << "bit " << (B->getValue() ? 1 : 0);
  else if (const auto *Bits = dyn_cast<BitsInit>(V))
    OS << "bits<" << Bits->getNumBits() << "> = " << Bits->getAsString();
  else if (const auto *S = dyn_cast<StringInit>(V))
    OS << "string \"" << S->getValue() << '"';
  else if (const auto *L = dyn_cast<ListInit>(V))
    OS << "list of " << L->size() << " element(s)";
  else if (const auto *D = dyn_cast<DefInit>(V))
    OS << "ref -> def " << D->getDef()->getName();
  else if (const auto *Dag = dyn_cast<DagInit>(V))
    OS << "dag: operator " << Dag->getOperator()->getAsString() << ", "
       << Dag->getNumArgs() << " arg(s)";
  else
    OS << "(other: " << V->getAsString() << ")";
}

static bool emitFieldKinds(raw_ostream &OS, const RecordKeeper &records) {
  emitSourceFileHeader("Per-field Init kinds for record 'Showcase'", OS, records);

  const Record *R = records.getDef("Showcase");
  if (!R) {
    OS << "// no record named 'Showcase'\n";
    return false;
  }

  for (const RecordVal &RV : R->getValues()) {
    if (RV.getName() == "NAME") // the implicit name field
      continue;
    OS << "// " << RV.getName() << " : ";
    describe(OS, RV.getValue());
    OS << "\n";
  }
  return false;
}

int main(int argc, char **argv) {
  cl::ParseCommandLineOptions(argc, argv);
  return TableGenMain(argv[0], &emitFieldKinds);
}
