// RUN: %writing_bin/07-debugging %s 2>&1 | FileCheck %s
// RUN: %writing_bin/07-debugging --time-phases %s 2>&1 | FileCheck --check-prefix=TIME %s
// REQUIRES: writing-build
//
// Input for the debugging backend: an operation table where one latency is
// suspicious.

class Op<int lat = 1> { int Latency = lat; }
def ADD : Op;
def DIV : Op<20>;
def NOP : Op {
  let Latency = 0;
}

// The warning points at the field's `let`, the note at the def.
// CHECK:      07_debugging.td:12:7: warning: latency 0 is treated as 1
// CHECK-NEXT:   let Latency = 0;
// CHECK:      07_debugging.td:11:5: note: in this record
// CHECK-NEXT: def NOP : Op {

// CHECK:      // ADD = 1
// CHECK-NEXT: // DIV = 20
// CHECK-NEXT: // NOP = 1

// CHECK:      /* DIV as parsed:
// CHECK-NEXT: DIV {      // Op
// CHECK-NEXT:   int Latency = 20;
// CHECK-NEXT: }
// CHECK-NEXT: */

// The backend's own phases appear next to TableGen's.
// TIME: TableGen Phase Timing
// TIME-DAG: Collect and check latencies
// TIME-DAG: Emit table
// TIME-DAG: Parse, build records
