// RUN: llvm-tblgen -I %S/Inputs %s | FileCheck %s
// RUN: llvm-tblgen -I %S/Inputs -DHAS_VECTOR %s | FileCheck --check-prefix=VEC %s
//
// Lesson 15 — Preprocessing and include
// ProgRef: "Include files", "Preprocessing Facilities"
//
// The preprocessor only does conditional compilation. A macro has no value;
// it is defined or not, by #define or by -D on the command line. The
// directives are #define, #ifdef, #ifndef, #else and #endif.

#define HAS_FP

// `include` pastes a file in place; the -I directories are searched. The
// macros defined so far apply inside it.
include "15_registers.td"

def Common { int X = 1; }

#ifdef HAS_FP
def FloatUnit { string Name = "fpu"; }
#else
def NoFPU;
#endif

// Regions nest.
#ifndef HAS_VECTOR
def Scalar;
#else
def Vector;
#ifdef HAS_FP
def VectorFP;
#endif
#endif

// ---- Try it yourself: answers -----------------------------------------------
// Make a record appear only when building with -DDEBUG_INFO.
#ifdef DEBUG_INFO
def DebugInfo;
#endif

// ---- Expected output --------------------------------------------------------
// CHECK-NOT:   def DebugInfo
// CHECK-LABEL: def F0 {
// CHECK-LABEL: def FloatUnit {
// CHECK-NOT:   def NoFPU
// CHECK-LABEL: def R0 {
// CHECK-LABEL: def Scalar {
// CHECK-NOT:   def Vector

// VEC-NOT:   def Scalar
// VEC-LABEL: def Vector {
// VEC-LABEL: def VectorFP {
