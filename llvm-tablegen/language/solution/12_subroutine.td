// =============================================================================
// Lesson 12 — Classes as Subroutines
//
//   `ClassName<args>` builds an anonymous record whose fields you can read
//   immediately, so classes act as ad-hoc functions returning multiple values.
// =============================================================================

class IsPow2<int n> {
  bit ret = !and(!ne(n, 0), !eq(!and(n, !sub(n, 1)), 0));
}

class IsValidSize<int sz> {
  bit ret = !cond(!eq(sz,  1): 1,
                  !eq(sz,  2): 1,
                  !eq(sz,  4): 1,
                  !eq(sz,  8): 1,
                  !eq(sz, 16): 1,
                  true        : 0);
}

def Data1 {
  int Size      = 8;
  bit IsPow2    = IsPow2<Size>.ret;       // 1
  bit IsValidSz = IsValidSize<Size>.ret;  // 1
}

// -----------------------------------------------------------------------------
// Returning multiple values via multiple named fields.
// -----------------------------------------------------------------------------
class DivMod<int a, int b> {
  int q = !div(a, b);
  int r = !sub(a, !mul(!div(a, b), b));
}

def QR {
  int Q = DivMod<23, 5>.q;    // 4
  int R = DivMod<23, 5>.r;    // 3
}

// -----------------------------------------------------------------------------
// "Try it yourself" — Clamp, and ClampPow2 that composes Clamp with IsPow2.
// -----------------------------------------------------------------------------
class Clamp<int v, int lo, int hi> {
  int out = !cond(!lt(v, lo): lo,
                  !gt(v, hi): hi,
                  true       : v);
}

class ClampPow2<int v> {
  int clamped = Clamp<v, 1, 16>.out;
  bit isPow2  = IsPow2<Clamp<v, 1, 16>.out>.ret;
}

def C1 {
  int Out    = ClampPow2<8>.clamped;    // 8
  bit IsP2   = ClampPow2<8>.isPow2;     // 1
}

def C2 {
  int Out    = ClampPow2<100>.clamped;  // 16
  bit IsP2   = ClampPow2<100>.isPow2;   // 1
}
