//===- 06_hierarchy.cpp - Classes, superclasses and lists of records ------===//
//
// BackGuide: "Getting Classes", "Getting Record Superclasses", "Getting
// Record Names and Fields".
//
// Lessons 2-3 read scalar fields of concrete records. Real backends also look
// at the class hierarchy and at fields that hold other records:
//
//   records.getClasses()                 - every class, a name-sorted map
//   Class->getTemplateArgs()             - a class's template arguments
//   R->getSuperClasses()                 - all superclasses, in the order
//                                          their fields were copied in
//   R->getDirectSuperClasses(Vec)        - only the ones named after `:`
//                                          (LLVM 20 appends them last first)
//   R->getValueAsListOfDefs("F")         - a list<SomeClass> field
//   R->getValueAsOptionalDef("F")        - a record field, or null if `?`
//   records.getAllDerivedDefinitions({"A", "B"}) - derived from A *and* B
//
//   ./06-hierarchy 6-classes-and-lists/06_hierarchy.td
//
//===----------------------------------------------------------------------===//

#include "llvm/ADT/SmallVector.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/TableGen/Main.h"
#include "llvm/TableGen/Record.h"
#include "llvm/TableGen/TableGenBackend.h"

using namespace llvm;

static bool emitHierarchy(raw_ostream &OS, const RecordKeeper &records) {
  emitSourceFileHeader("Class hierarchy report", OS, records);

  // Classes are kept apart from defs, in their own name-sorted map.
  OS << "// " << records.getClasses().size() << " classes:\n";
  for (const auto &[name, cls] : records.getClasses())
    OS << "//   " << name << " <" << cls->getTemplateArgs().size()
       << " template arg(s)>\n";

  for (const Record *R : records.getAllDerivedDefinitions("Inst")) {
    OS << "\n// " << R->getName() << "\n";

    // Each entry pairs the class with the source range that named it.
    OS << "//   all superclasses:   ";
    for (const auto &[super, range] : R->getSuperClasses())
      OS << " " << super->getName();

    SmallVector<const Record *, 4> direct;
    R->getDirectSuperClasses(direct);
    OS << "\n//   direct superclasses:";
    for (const Record *super : direct)
      OS << " " << super->getName();

    // A list<Predicate> field comes back as the records themselves.
    OS << "\n//   predicates:         ";
    std::vector<const Record *> preds = R->getValueAsListOfDefs("Predicates");
    if (preds.empty())
      OS << " (none)";
    for (const Record *P : preds)
      OS << " " << P->getValueAsString("Name");

    // getValueAsDef would abort on `?`; the Optional variant returns null.
    OS << "\n//   alias:              ";
    if (const Record *alias = R->getValueAsOptionalDef("Alias"))
      OS << " " << alias->getName();
    else
      OS << " (unset)";
    OS << "\n";
  }

  OS << "\n// derived from Inst *and* Terminator:";
  for (const Record *R : records.getAllDerivedDefinitions({"Inst", "Terminator"}))
    OS << " " << R->getName();
  OS << "\n";
  return false;
}

int main(int argc, char **argv) {
  cl::ParseCommandLineOptions(argc, argv);
  return TableGenMain(argv[0], &emitHierarchy);
}
