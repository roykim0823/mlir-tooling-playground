// =============================================================================
// Lesson 13 — Preprocessing (`#define`, `#ifdef`, `#ifndef`, `#else`, `#endif`)
//
//   Run with a command-line macro to flip the branches, e.g.:
//     llvm-tblgen --print-records 13_preproc.td -D HAS_VECTOR
// =============================================================================

#define HAS_FP

def Common { int X = 1; }

#ifdef HAS_FP
  def FloatUnit { string Name = "fpu"; }
#else
  def NoFPU { string Note = "no FPU"; }
#endif

#ifndef HAS_VECTOR
  def Scalar;
#endif
