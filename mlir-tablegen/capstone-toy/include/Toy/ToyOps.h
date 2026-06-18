//===- ToyOps.h - Toy op declarations -------------------------------------===//
#ifndef TOY_TOYOPS_H
#define TOY_TOYOPS_H

#include "mlir/Bytecode/BytecodeOpInterface.h"      // required by generated op classes
#include "mlir/IR/Attributes.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Dialect.h"
#include "mlir/IR/OpDefinition.h"
#include "mlir/IR/Types.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"   // Pure -> ConditionallySpeculatable, etc.

#include "Toy/ToyDialect.h"

// The generated type classes (from --gen-typedef-decls).
#define GET_TYPEDEF_CLASSES
#include "Toy/ToyTypes.h.inc"

// The generated attribute classes (from --gen-attrdef-decls).
#define GET_ATTRDEF_CLASSES
#include "Toy/ToyAttrs.h.inc"

// The generated op classes (from --gen-op-decls).
#define GET_OP_CLASSES
#include "Toy/ToyOps.h.inc"

#endif // TOY_TOYOPS_H
