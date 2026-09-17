//===- ToyInterfaces.h - Toy interface declarations -----------------------===//
//
// Includes the generated interface classes. This header must be included
// BEFORE the generated op/type classes (ToyOps.h does so), because those name
// `::toy::BinaryArithOpInterface::Trait` / `::toy::ContainerTypeInterface::Trait`
// in their base-class lists.
//
//===----------------------------------------------------------------------------===//
#ifndef TOY_TOYINTERFACES_H
#define TOY_TOYINTERFACES_H

#include "mlir/IR/OpDefinition.h"
#include "mlir/IR/Types.h"

// --gen-op-interface-decls: class BinaryArithOpInterface + detail::...Traits
#include "Toy/ToyOpInterfaces.h.inc"
// --gen-type-interface-decls: class ContainerTypeInterface
#include "Toy/ToyTypeInterfaces.h.inc"

#endif // TOY_TOYINTERFACES_H
