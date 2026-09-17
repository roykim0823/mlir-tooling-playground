#ifndef HELLO_HELLOOPS_H
#define HELLO_HELLOOPS_H
#include "mlir/Bytecode/BytecodeOpInterface.h"
#include "mlir/IR/OpDefinition.h"
#include "Hello/HelloDialect.h"
#define GET_OP_CLASSES
#include "Hello/HelloOps.h.inc"
#endif
