//===- ToyDialect.h - Toy dialect declaration -----------------------------===//
#ifndef TOY_TOYDIALECT_H
#define TOY_TOYDIALECT_H

#include "mlir/IR/Dialect.h"

// The generated `class ToyDialect : public ::mlir::Dialect` (from
// --gen-dialect-decls). Its `initialize()` is implemented in ToyDialect.cpp.
#include "Toy/ToyDialect.h.inc"

#endif // TOY_TOYDIALECT_H
