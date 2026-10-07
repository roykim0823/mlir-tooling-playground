// RUN: llvm-tblgen %s | FileCheck %s
//
// Lesson 6 — Classes and records
// ProgRef: "class", "def", "Examples: classes and records"
//
// A class is an abstract record: fields with defaults that other classes and
// records inherit. `def D : C` makes a concrete record D with C's fields.

class Fruit {
  string Color  = "unknown";
  bit    Edible = 1;
}

def Apple : Fruit { let Color = "red"; }     // `let` overrides an inherited field
def Lemon : Fruit { let Color = "yellow"; }
def Acorn : Fruit { let Edible = 0; }        // keeps Color = "unknown"

// A record can add fields of its own next to the inherited ones.
def Cherry : Fruit {
  let Color = "dark red";
  int Pits  = 1;
}

// Multiple inheritance: fields are merged left to right, so when two parents
// define the same field the last parent's value wins.
class A { int V = 1; }
class B { int V = 2; }
def AB : A, B;      // V = 2
def BA : B, A;      // V = 1

// A class can inherit from classes; the printed comment after each def lists
// every class it inherits from, indirect ones first.
class Tropical : Fruit { bit Imported = 1; }
def Mango : Tropical { let Color = "orange"; }

// One class can reshape another's data. ModRefBits splits ModRefVal's 2-bit
// Value into two named bits (the ProgRef example).
class ModRefVal<bits<2> val> { bits<2> Value = val; }
def None   : ModRefVal<0>;
def Mod    : ModRefVal<1>;
def Ref    : ModRefVal<2>;
def ModRef : ModRefVal<3>;

class ModRefBits<ModRefVal mrv> {
  bit isMod = mrv.Value{0};
  bit isRef = mrv.Value{1};
}
def foo   : ModRefBits<Mod>;
def bar   : ModRefBits<Ref>;
def snork : ModRefBits<ModRef>;

// ---- Try it yourself: answers -----------------------------------------------
// A Vehicle class, and Bicycle/Truck/Skateboard records that override it.
class Vehicle {
  int Wheels    = 4;
  bit Motorized = 1;
}
def Bicycle    : Vehicle { let Wheels = 2; let Motorized = 0; }
def Truck      : Vehicle { let Wheels = 6; }
def Skateboard : Vehicle { let Motorized = 0; }

// ---- Expected output --------------------------------------------------------
// CHECK-LABEL: def AB { // A B
// CHECK-NEXT:  int V = 2;
// CHECK-NEXT:  }
// CHECK-LABEL: def Acorn { // Fruit
// CHECK-NEXT:  string Color = "unknown";
// CHECK-NEXT:  bit Edible = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def Apple { // Fruit
// CHECK-NEXT:  string Color = "red";
// CHECK-NEXT:  bit Edible = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def BA { // B A
// CHECK-NEXT:  int V = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def Bicycle { // Vehicle
// CHECK-NEXT:  int Wheels = 2;
// CHECK-NEXT:  bit Motorized = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def Cherry { // Fruit
// CHECK-NEXT:  string Color = "dark red";
// CHECK-NEXT:  bit Edible = 1;
// CHECK-NEXT:  int Pits = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def Lemon { // Fruit
// CHECK-NEXT:  string Color = "yellow";
// CHECK-NEXT:  bit Edible = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def Mango { // Fruit Tropical
// CHECK-NEXT:  string Color = "orange";
// CHECK-NEXT:  bit Edible = 1;
// CHECK-NEXT:  bit Imported = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def Mod { // ModRefVal
// CHECK-NEXT:  bits<2> Value = { 0, 1 };
// CHECK-NEXT:  }
// CHECK-LABEL: def ModRef { // ModRefVal
// CHECK-NEXT:  bits<2> Value = { 1, 1 };
// CHECK-NEXT:  }
// CHECK-LABEL: def None { // ModRefVal
// CHECK-NEXT:  bits<2> Value = { 0, 0 };
// CHECK-NEXT:  }
// CHECK-LABEL: def Ref { // ModRefVal
// CHECK-NEXT:  bits<2> Value = { 1, 0 };
// CHECK-NEXT:  }
// CHECK-LABEL: def Skateboard { // Vehicle
// CHECK-NEXT:  int Wheels = 4;
// CHECK-NEXT:  bit Motorized = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def Truck { // Vehicle
// CHECK-NEXT:  int Wheels = 6;
// CHECK-NEXT:  bit Motorized = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def bar { // ModRefBits
// CHECK-NEXT:  bit isMod = 0;
// CHECK-NEXT:  bit isRef = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def foo { // ModRefBits
// CHECK-NEXT:  bit isMod = 1;
// CHECK-NEXT:  bit isRef = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def snork { // ModRefBits
// CHECK-NEXT:  bit isMod = 1;
// CHECK-NEXT:  bit isRef = 1;
// CHECK-NEXT:  }
