// RUN: %writing_bin/03-init-types %s | FileCheck %s
// REQUIRES: writing-build
//
// Input for the Init-hierarchy backend: one record with a value of every kind.
class Color;
def Red : Color;

def reg;   // a stub operator for the dag below

def Showcase {
  bit        Flag    = 1;
  int        N       = 42;
  bits<8>    Opcode  = 0b10110010;
  string     S       = "hi";
  list<int>  Xs      = [1, 2, 3];
  Color      Ref     = Red;
  dag        Pattern = (reg 1, 2);
  string     Missing = ?;          // unset
}

// CHECK:      // Flag : bit 1
// CHECK-NEXT: // N : int 42
// CHECK-NEXT: // Opcode : bits<8> = { 1, 0, 1, 1, 0, 0, 1, 0 }
// CHECK-NEXT: // S : string "hi"
// CHECK-NEXT: // Xs : list of 3 element(s)
// CHECK-NEXT: // Ref : ref -> def Red
// CHECK-NEXT: // Pattern : dag: operator reg, 2 arg(s)
// CHECK-NEXT: // Missing : ? (unset)
