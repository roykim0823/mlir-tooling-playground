#include "Hello/HelloDialect.h"
#include "Hello/HelloOps.h"

#include "Hello/HelloOpsDialect.cpp.inc"

void hello::HelloDialect::initialize() {
  addOperations<
#define GET_OP_LIST
#include "Hello/HelloOps.cpp.inc"
      >();
}

#define GET_OP_CLASSES
#include "Hello/HelloOps.cpp.inc"
