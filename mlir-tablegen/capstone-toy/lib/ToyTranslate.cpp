//===- ToyTranslate.cpp - Toy <-> "toytext" translations ------------------===//
//
// Two translations for mlir-translate-style tools (see tools/toy-translate.cpp):
//
//   --mlir-to-toytext   EXPORT: a module of Toy ops  ->  the line-based toytext format
//   --toytext-to-mlir   IMPORT: toytext              ->  a module of Toy ops
//
// toytext is deliberately tiny — one op per line, names instead of SSA values:
//
//   # comment
//   c1 = const 1.0
//   c2 = const 2.0
//   s = add c1 c2          # add | mul | sub
//   print s
//
// It exists to show the two registration structs, how an exporter walks IR
// through an interface, and how an importer turns external source positions
// into MLIR locations so diagnostics and --mlir-print-debuginfo point back at
// the original text.
//
//===----------------------------------------------------------------------------===//

#include "Toy/ToyDialect.h"
#include "Toy/ToyInterfaces.h"
#include "Toy/ToyOps.h"

#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/Verifier.h"
#include "mlir/Tools/mlir-translate/Translation.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/Support/Format.h"
#include "llvm/Support/SourceMgr.h"

using namespace mlir;

//===----------------------------------------------------------------------------===//
// Export: Toy IR -> toytext
//===----------------------------------------------------------------------------===//

// Values get names v0, v1, ... in definition order.
static LogicalResult exportToyText(ModuleOp module, raw_ostream &os) {
  llvm::DenseMap<Value, std::string> names;
  auto nameOf = [&](Value v) -> StringRef {
    auto it = names.find(v);
    if (it != names.end())
      return it->second;
    return names.insert({v, "v" + std::to_string(names.size())}).first->second;
  };

  os << "# toytext exported by toy-translate --mlir-to-toytext\n";
  for (Operation &op : module.getBody()->getOperations()) {
    if (auto cst = dyn_cast<toy::ConstantOp>(op)) {
      // %g: "1" rather than raw_ostream's "1.000000e+00"; round-trips through
      // StringRef::getAsDouble on import.
      os << nameOf(cst.getResult()) << " = const "
         << llvm::format("%g", cst.getValue().convertToDouble()) << "\n";
    } else if (auto arith = dyn_cast<toy::BinaryArithOpInterface>(op)) {
      // The interface gives operands generically; the op name gives the mnemonic
      // ("toy.add" -> "add"). No per-op code.
      os << nameOf(arith->getResult(0)) << " = "
         << arith->getName().stripDialect() << " "
         << nameOf(arith.getLhsValue()) << " " << nameOf(arith.getRhsValue())
         << "\n";
    } else if (auto print = dyn_cast<toy::PrintOp>(op)) {
      os << "print " << nameOf(print.getInput()) << "\n";
    } else {
      // Diagnostics from a translation work like everywhere else: attach them
      // to the op and return failure; the driver reports and exits 1.
      return op.emitOpError("cannot be exported to toytext (only toy.constant, "
                            "BinaryArithOpInterface ops and toy.print at module level)");
    }
  }
  return success();
}

//===----------------------------------------------------------------------------===//
// Import: toytext -> Toy IR
//===----------------------------------------------------------------------------===//

static OwningOpRef<Operation *> importToyText(llvm::SourceMgr &sourceMgr,
                                              MLIRContext *context) {
  // The context only knows the dialects the registration below asked for; a
  // translation must load what it is going to create.
  context->loadDialect<toy::ToyDialect>();

  const llvm::MemoryBuffer *buffer =
      sourceMgr.getMemoryBuffer(sourceMgr.getMainFileID());
  StringRef filename = buffer->getBufferIdentifier();

  OpBuilder builder(context);
  OwningOpRef<ModuleOp> module =
      ModuleOp::create(FileLineColLoc::get(context, filename, 0, 0));
  builder.setInsertionPointToEnd(module->getBody());

  llvm::StringMap<Value> values;
  unsigned lineNo = 0;
  StringRef rest = buffer->getBuffer();
  while (!rest.empty()) {
    StringRef line;
    std::tie(line, rest) = rest.split('\n');
    ++lineNo;
    line = line.split('#').first.trim();          // strip comments + whitespace
    if (line.empty())
      continue;

    // Every op built from this line carries the toytext position, so that
    // --mlir-print-debuginfo and any later diagnostic point back here.
    Location loc = FileLineColLoc::get(context, filename, lineNo, 1);
    auto error = [&](const Twine &msg) -> OwningOpRef<Operation *> {
      emitError(loc) << msg;
      return nullptr;
    };
    auto lookup = [&](StringRef name) -> Value {
      auto it = values.find(name);
      if (it == values.end()) {
        emitError(loc) << "unknown value '" << name << "'";
        return nullptr;
      }
      return it->second;
    };

    SmallVector<StringRef> words;
    line.split(words, ' ', /*MaxSplit=*/-1, /*KeepEmpty=*/false);

    // print <name>
    if (words[0] == "print") {
      if (words.size() != 2)
        return error("expected: print <name>");
      Value v = lookup(words[1]);
      if (!v)
        return nullptr;
      builder.create<toy::PrintOp>(loc, v);
      continue;
    }

    // <name> = const <f64>   |   <name> = add|mul|sub <name> <name>
    if (words.size() < 3 || words[1] != "=")
      return error("expected: <name> = const <number> | <name> = add|mul|sub <a> <b> | print <name>");
    StringRef name = words[0], opName = words[2];
    if (values.count(name))
      return error("redefinition of '" + name + "'");

    Value result;
    if (opName == "const") {
      double value;
      if (words.size() != 4 || words[3].getAsDouble(value))
        return error("expected: <name> = const <number>");
      result = builder.create<toy::ConstantOp>(loc, value);   // ODS custom builder
    } else if (opName == "add" || opName == "mul" || opName == "sub") {
      if (words.size() != 5)
        return error("expected two operands after '" + opName + "'");
      Value lhs = lookup(words[3]), rhs = lookup(words[4]);
      if (!lhs || !rhs)
        return nullptr;
      Type f64 = builder.getF64Type();
      if (opName == "add")
        result = builder.create<toy::AddOp>(loc, f64, lhs, rhs);
      else if (opName == "mul")
        result = builder.create<toy::MulOp>(loc, f64, lhs, rhs);
      else
        result = builder.create<toy::SubOp>(loc, f64, lhs, rhs);
    } else {
      return error("unknown operation '" + opName + "'");
    }
    values[name] = result;
  }

  if (failed(verify(*module)))
    return nullptr;
  return module;
}

//===----------------------------------------------------------------------------===//
// Registration
//===----------------------------------------------------------------------------===//

namespace toy {
void registerToyTranslations() {
  // The registration objects register themselves in their constructor, so they
  // are function-local statics: constructed exactly once, when the tool asks.
  static TranslateFromMLIRRegistration exportReg(
      "mlir-to-toytext", "Export a module of Toy ops to the toytext format",
      exportToyText,
      // Dialects the INPUT .mlir may use — this is what the driver registers
      // in the context it parses the input with.
      [](DialectRegistry &registry) {
        registry.insert<toy::ToyDialect, func::FuncDialect>();
      });

  static TranslateToMLIRRegistration importReg(
      "toytext-to-mlir", "Import the toytext format as a module of Toy ops",
      importToyText,
      // Dialects the OUTPUT module will contain.
      [](DialectRegistry &registry) { registry.insert<toy::ToyDialect>(); });
}
} // namespace toy
