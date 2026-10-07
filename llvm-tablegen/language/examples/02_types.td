// RUN: llvm-tblgen %s | FileCheck %s
// RUN: not llvm-tblgen -DBAD_TYPE %s 2>&1 | FileCheck --check-prefix=BAD %s
//
// Lesson 2 — Types
// ProgRef: "Types", and the bits/list forms of "Simple values"
//
// TableGen is statically typed. The types are bit, int, string, bits<n>,
// list<T>, dag, and a class name, which means "a record derived from that
// class". `code` is accepted as a spelling of string.

class Anything;
def X : Anything;
def Y : Anything;
def op;                              // a dag operator must be a record

def TypeShowcase {
  bit             Flag   = 1;
  int             N      = -42;              // 64-bit signed
  string          S      = "hello";
  code            Body   = [{ return 0; }];
  bits<8>         Opcode = 0b00010110;       // 8 individually addressable bits
  list<int>       Primes = [2, 3, 5, 7];
  list<list<int>> Matrix = [[1, 2], [3, 4]];
  dag             D      = (op 1, "two");
  Anything        Ref    = X;                // any record derived from Anything
  list<Anything>  Refs   = [X, Y];
}

// Values convert implicitly where the conversion is lossless.
def Conversions {
  bits<4>   FromInt   = 7;                   // int -> bits<4>
  bits<4>   FromBits  = { 0, 1, 1, 1 };      // a bits initializer, MSB first
  int       FromBits2 = FromBits;            // bits<4> -> int
  bit       FromInt2  = 1;                   // int 0/1 -> bit
  list<int> Empty     = []<int>;             // an empty list needs its type
}

// A class name in a type position is checked: 5 is not an Anything.
#ifdef BAD_TYPE
def Bad { Anything R = 5; }
#endif
// BAD: error: Field 'R' of type 'Anything' is incompatible with value '5' of type 'int'

// ---- Try it yourself: answers -----------------------------------------------
// 1. A record with a bits<16> instruction word.
// 2. Split it into a 6-bit opcode (top) and a 10-bit immediate (bottom);
//    the {hi...lo} suffix used here is the subject of lesson 3.
def Word {
  bits<16> W   = 0b1011010000000011;
  bits<6>  Opc = W{15...10};
  bits<10> Imm = W{9...0};
}

// ---- Expected output --------------------------------------------------------
// CHECK-LABEL: def Conversions {
// CHECK-NEXT:  bits<4> FromInt = { 0, 1, 1, 1 };
// CHECK-NEXT:  bits<4> FromBits = { 0, 1, 1, 1 };
// CHECK-NEXT:  int FromBits2 = 7;
// CHECK-NEXT:  bit FromInt2 = 1;
// CHECK-NEXT:  list<int> Empty = [];
// CHECK-NEXT:  }
// CHECK-LABEL: def TypeShowcase {
// CHECK-NEXT:  bit Flag = 1;
// CHECK-NEXT:  int N = -42;
// CHECK-NEXT:  string S = "hello";
// CHECK-NEXT:  code Body = [{ return 0; }];
// CHECK-NEXT:  bits<8> Opcode = { 0, 0, 0, 1, 0, 1, 1, 0 };
// CHECK-NEXT:  list<int> Primes = [2, 3, 5, 7];
// CHECK-NEXT:  list<list<int>> Matrix = {{\[\[}}1, 2], [3, 4]];
// CHECK-NEXT:  dag D = (op 1, "two");
// CHECK-NEXT:  Anything Ref = X;
// CHECK-NEXT:  list<Anything> Refs = [X, Y];
// CHECK-NEXT:  }
// CHECK-LABEL: def Word {
// CHECK-NEXT:  bits<16> W = { 1, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1 };
// CHECK-NEXT:  bits<6> Opc = { 1, 0, 1, 1, 0, 1 };
// CHECK-NEXT:  bits<10> Imm = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1 };
// CHECK-NEXT:  }
