// RUN: %writing_bin/04-enum-emitter %s | FileCheck %s
// RUN: not %writing_bin/04-enum-emitter -DDUP %s 2>&1 | FileCheck --check-prefix=DUP %s
// REQUIRES: writing-build
//
// Input for the enum-emitting backend. Each EnumCase carries an int value.
// -DDUP adds a duplicate value, and the backend's PrintFatalError points at it.
// Records come back sorted by name, so the error blames the later name.
class EnumCase<int v> {
  int Value = v;
}

def Red   : EnumCase<0>;
def Green : EnumCase<1>;
def Blue  : EnumCase<2>;

#ifdef DUP
def Teal : EnumCase<1>;   // sorts after Green, so it is the one reported
#endif

// CHECK:      #ifdef GET_COLOR_ENUM
// CHECK-NEXT: enum class Color {
// CHECK-NEXT:   Blue = 2,
// CHECK-NEXT:   Green = 1,
// CHECK-NEXT:   Red = 0,
// CHECK-NEXT: };
// CHECK-NEXT: #endif // GET_COLOR_ENUM

// DUP:      04_enum_emitter.td:{{[0-9]+}}:5: error: duplicate enum value 1
// DUP-NEXT: def Teal : EnumCase<1>;
