// Export with toy-translate --mlir-to-toytext (lib/ToyTranslate.cpp), and a
// round trip back through --toytext-to-mlir.
//
// RUN: toy-translate --mlir-to-toytext %s | FileCheck %s --check-prefix=TEXT
// RUN: toy-translate --mlir-to-toytext %s | toy-translate --toytext-to-mlir | FileCheck %s
//
// A func.func at module level is not exportable: the translation emits an
// error on the op and the tool exits 1.
// RUN: not toy-translate --mlir-to-toytext %S/Inputs/unexportable.mlir 2>&1 | FileCheck %s --check-prefix=ERR

// TEXT: # toytext exported by toy-translate --mlir-to-toytext
// TEXT-NEXT: v0 = const 1
// TEXT-NEXT: v1 = const 2
// TEXT-NEXT: v2 = add v0 v1
// TEXT-NEXT: v3 = mul v2 v0
// TEXT-NEXT: v4 = sub v3 v1
// TEXT-NEXT: print v4

// CHECK: module {
// CHECK-NEXT: %[[C1:.*]] = toy.constant 1.000000e+00
// CHECK-NEXT: %[[C2:.*]] = toy.constant 2.000000e+00
// CHECK-NEXT: %[[A:.*]] = toy.add %[[C1]], %[[C2]]
// CHECK-NEXT: %[[M:.*]] = toy.mul %[[A]], %[[C1]]
// CHECK-NEXT: %[[S:.*]] = toy.sub %[[M]], %[[C2]]
// CHECK-NEXT: toy.print %[[S]]
%0 = toy.constant 1.0
%1 = toy.constant 2.0
%2 = toy.add %0, %1
%3 = toy.mul %2, %0
%4 = toy.sub %3, %1
toy.print %4

// ERR: error: 'func.func' op cannot be exported to toytext
