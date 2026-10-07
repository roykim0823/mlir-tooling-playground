// RUN: llvm-tblgen %s | FileCheck %s
//
// Lesson 3 — Values and suffixes
// ProgRef: "Values and Expressions", "Suffixed values"
//
// A value can be followed by suffixes that select part of it: {bits} on an
// integer or bits value, [elements] on a list, .field on a record.

def BitSuffixes {
  bits<8> Op  = 0b10110010;
  bit     B0  = Op{0};          // bit 0 is the least significant
  bit     B7  = Op{7};
  bits<4> Hi  = Op{7...4};      // bits 7 down to 4
  bits<4> Rev = Op{4...7};      // the same bits, reversed
  bits<3> Mix = Op{7, 0, 1};    // any list of bit positions
  bit     I5  = 0x20{5};        // works on an int too
}

def ListSuffixes {
  list<string> L = ["a", "b", "c", "d", "e"];
  string       One   = L[1];            // one index: an element
  list<string> Slice = L[1,];           // a trailing comma: a one-element list
  list<string> Many  = L[3...4, 0, 0];  // ranges and repeats, in any order
  list<string> Expr  = L[!range(2)];    // indices may be expressions
}

def Other { int X = 5; }

// An identifier names a field of this record, a record, a template argument,
// a defvar, or a foreach variable. `.field` reads a field of a record value.
def Lookups {
  int    Y = Other.X;
  int    Z = !add(Y, 1);       // Y is this record's own field
  string N = !cast<string>(Other);
}

// ---- Try it yourself: answers -----------------------------------------------
// 1. Take the low and high bytes of a bits<16>.
// 2. Take every other element of a list with a slice.
def Answers {
  bits<16>  W     = 0xBEEF;
  bits<8>   Low   = W{7...0};
  bits<8>   High  = W{15...8};
  list<int> Evens = [10, 11, 12, 13, 14, 15][0, 2, 4];
}

// ---- Expected output --------------------------------------------------------
// CHECK-LABEL: def Answers {
// CHECK-NEXT:  bits<16> W = { 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1 };
// CHECK-NEXT:  bits<8> Low = { 1, 1, 1, 0, 1, 1, 1, 1 };
// CHECK-NEXT:  bits<8> High = { 1, 0, 1, 1, 1, 1, 1, 0 };
// CHECK-NEXT:  list<int> Evens = [10, 12, 14];
// CHECK-NEXT:  }
// CHECK-LABEL: def BitSuffixes {
// CHECK-NEXT:  bits<8> Op = { 1, 0, 1, 1, 0, 0, 1, 0 };
// CHECK-NEXT:  bit B0 = 0;
// CHECK-NEXT:  bit B7 = 1;
// CHECK-NEXT:  bits<4> Hi = { 1, 0, 1, 1 };
// CHECK-NEXT:  bits<4> Rev = { 1, 1, 0, 1 };
// CHECK-NEXT:  bits<3> Mix = { 1, 0, 1 };
// CHECK-NEXT:  bit I5 = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def ListSuffixes {
// CHECK-NEXT:  list<string> L = ["a", "b", "c", "d", "e"];
// CHECK-NEXT:  string One = "b";
// CHECK-NEXT:  list<string> Slice = ["b"];
// CHECK-NEXT:  list<string> Many = ["d", "e", "a", "a"];
// CHECK-NEXT:  list<string> Expr = ["a", "b"];
// CHECK-NEXT:  }
// CHECK-LABEL: def Lookups {
// CHECK-NEXT:  int Y = 5;
// CHECK-NEXT:  int Z = 6;
// CHECK-NEXT:  string N = "Other";
// CHECK-NEXT:  }
// CHECK-LABEL: def Other {
// CHECK-NEXT:  int X = 5;
// CHECK-NEXT:  }
