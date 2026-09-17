// The dialect's custom type and attribute (AttrDef/TypeDef in ToyOps.td)
// survive a parse -> print round trip through toy-opt with no passes.
//
// RUN: toy-opt %s | FileCheck %s

// CHECK-LABEL: func.func @uses_array_type
// CHECK-SAME:  (%{{.*}}: !toy.array<3 x f64>) -> !toy.array<3 x f64>
func.func @uses_array_type(%arg: !toy.array<3 x f64>) -> !toy.array<3 x f64> {
  return %arg : !toy.array<3 x f64>
}

// CHECK-LABEL: func.func @uses_shape_attr
// CHECK-SAME:  attributes {toy.shape = #toy.shape<3 x 4>}
func.func @uses_shape_attr() attributes {toy.shape = #toy.shape<3 x 4>} {
  return
}

// The ops' assemblyFormat round-trips too: a generic-form input is printed
// back in custom form.
// CHECK-LABEL: func.func @generic_to_custom
func.func @generic_to_custom() -> f64 {
  // CHECK-NEXT: %[[A:.*]] = toy.constant 1.000000e+00
  // CHECK-NEXT: %[[B:.*]] = toy.constant 2.000000e+00
  // CHECK-NEXT: %[[M:.*]] = toy.mul %[[A]], %[[B]]
  // CHECK-NEXT: %[[S:.*]] = toy.sub %[[M]], %[[A]]
  %0 = "toy.constant"() {value = 1.0 : f64} : () -> f64
  %1 = "toy.constant"() {value = 2.0 : f64} : () -> f64
  %2 = "toy.mul"(%0, %1) : (f64, f64) -> f64
  %3 = "toy.sub"(%2, %0) : (f64, f64) -> f64
  return %3 : f64
}
