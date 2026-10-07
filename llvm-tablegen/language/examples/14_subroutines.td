// RUN: llvm-tblgen %s | FileCheck %s
//
// Lesson 14 — Classes as subroutines
// ProgRef: "Using Classes as Subroutines", SimpleValue `ClassID<...>`
//
// `ClassName<args>` used as a value creates an anonymous record that inherits
// the class. Reading a field of it, as in `IsPow2<8>.ret`, makes the class a
// function: the template arguments are the parameters, the fields the results.

class IsPow2<int n> {
  bit ret = !and(!ne(n, 0), !eq(!and(n, !sub(n, 1)), 0));
}

class isValidSize<int size> {
  bit ret = !cond(!eq(size,  1): 1,
                  !eq(size,  2): 1,
                  !eq(size,  4): 1,
                  !eq(size,  8): 1,
                  !eq(size, 16): 1,
                  true: 0);
}

def Data1 {
  int Size      = 8;
  bit IsPow2    = IsPow2<Size>.ret;
  bit ValidSize = isValidSize<Size>.ret;
}

// Several fields return several values.
class DivMod<int a, int b> {
  int q = !div(a, b);
  int r = !sub(a, !mul(q, b));
}
def QR {
  int Q = DivMod<23, 5>.q;
  int R = DivMod<23, 5>.r;
}

// A subroutine can call itself; this is how a loop with an unknown trip count
// is written. (lesson 4 used the same trick to sum a list.)
class Gcd<int a, int b> {
  int ret = !if(!eq(b, 0), a, Gcd<b, !sub(a, !mul(!div(a, b), b))>.ret);
}
def G { int Gcd = Gcd<84, 36>.ret; }

// ---- Try it yourself: answers -----------------------------------------------
// 1. Clamp<v, lo, hi>.ret: v limited to [lo, hi].
// 2. ClampPow2<v>: clamp to [1, 16], then test for a power of two.
class Clamp<int v, int lo, int hi> {
  int ret = !cond(!lt(v, lo): lo, !gt(v, hi): hi, true: v);
}
class ClampPow2<int v> {
  int clamped = Clamp<v, 1, 16>.ret;
  bit isPow2  = IsPow2<clamped>.ret;
}
def C1 { int Out = ClampPow2<6>.clamped;   bit P = ClampPow2<6>.isPow2; }
def C2 { int Out = ClampPow2<100>.clamped; bit P = ClampPow2<100>.isPow2; }

// ---- Expected output --------------------------------------------------------
// CHECK-LABEL: def C1 {
// CHECK-NEXT:  int Out = 6;
// CHECK-NEXT:  bit P = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def C2 {
// CHECK-NEXT:  int Out = 16;
// CHECK-NEXT:  bit P = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def Data1 {
// CHECK-NEXT:  int Size = 8;
// CHECK-NEXT:  bit IsPow2 = 1;
// CHECK-NEXT:  bit ValidSize = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def G {
// CHECK-NEXT:  int Gcd = 12;
// CHECK-NEXT:  }
// CHECK-LABEL: def QR {
// CHECK-NEXT:  int Q = 4;
// CHECK-NEXT:  int R = 3;
// CHECK-NEXT:  }
