//===- ToyDialect.cpp - Toy dialect definition ----------------------------===//
//
// Hand-written glue that ODS can't generate: the dialect's `initialize()`,
// which registers the dialect's operations. The generated `.cpp.inc` files
// supply everything else (dialect body, op definitions, type ids).
//
//===----------------------------------------------------------------------------===//

#include "Toy/ToyDialect.h"
#include "Toy/ToyOps.h"

#include "mlir/IR/Builders.h"               // complete Builder/OpBuilder for op defs
#include "mlir/IR/DialectImplementation.h"  // AsmParser/AsmPrinter for type/attr parse/print
#include "llvm/ADT/TypeSwitch.h"            // TypeSwitch used by generated parse/print dispatch

using namespace mlir;
using namespace toy;

// --gen-typedef-defs / --gen-attrdef-defs: the type & attribute definitions,
// including the generatedType/AttributeParser helpers the dialect dispatch
// below calls — so these must precede ToyDialect.cpp.inc.
#define GET_TYPEDEF_CLASSES
#include "Toy/ToyTypes.cpp.inc"
#define GET_ATTRDEF_CLASSES
#include "Toy/ToyAttrs.cpp.inc"

// --gen-dialect-defs: ToyDialect constructor, parse/print dispatch, type id.
#include "Toy/ToyDialect.cpp.inc"

void ToyDialect::initialize() {
  addOperations<
#define GET_OP_LIST
#include "Toy/ToyOps.cpp.inc"
      >();
  addTypes<
#define GET_TYPEDEF_LIST
#include "Toy/ToyTypes.cpp.inc"
      >();
  addAttributes<
#define GET_ATTRDEF_LIST
#include "Toy/ToyAttrs.cpp.inc"
      >();
}

// --gen-op-defs: the op method definitions (builders, accessors, verifiers,
// parser/printer from assemblyFormat).
#define GET_OP_CLASSES
#include "Toy/ToyOps.cpp.inc"
