// RUN: %writing_bin/01-skeleton %s | FileCheck %s
// REQUIRES: writing-build
//
// Input for the skeleton backend — a couple of trivial records.
class Greeting {
  string Message;
}

def Hello : Greeting { let Message = "hello"; }
def Bye   : Greeting { let Message = "bye"; }
def Nop;

// emitSourceFileHeader writes the standard banner; the rest is ours.
// CHECK:      Skeleton backend — record summary
// CHECK:      From: {{.*}}01_skeleton.td
// CHECK:      // classes parsed: 1
// CHECK-NEXT: // records parsed: 3
// CHECK-NEXT: //   def Bye
// CHECK-NEXT: //   def Hello
// CHECK-NEXT: //   def Nop
