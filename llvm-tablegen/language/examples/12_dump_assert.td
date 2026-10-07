// RUN: llvm-tblgen %s 2>&1 | FileCheck %s
// RUN: not llvm-tblgen -DBAD %s 2>&1 | FileCheck --check-prefix=BAD %s
//
// Lesson 12 — `dump` and `assert`
// ProgRef: "dump", "assert"
//
// Both print diagnostics on stderr, which is why the RUN lines above merge
// stderr into the checked output with 2>&1.

// ---- dump: print a message --------------------------------------------------
// At top level it prints immediately; inside a class or multiclass it prints
// each time a record or defm instantiates it. Pair it with !repr to see a
// value you are debugging.
dump "top level: " # !repr([1, 2]);
// CHECK: note: top level: [1, 2]

def op;
multiclass MC<dag d> {
  dump "MC got " # !repr(d);
  def _x;
}
defm A : MC<(op 1, 2)>;
defm B : MC<(op 3)>;
// CHECK: note: MC got (op 1, 2)
// CHECK: note: MC got (op 3)

// ---- assert: check a condition ----------------------------------------------
// A false assertion is an error (the run continues, then llvm-tblgen exits
// with failure). Where it is checked depends on where it is written:
//   top level   - immediately
//   record      - after the record is fully built
//   class       - inherited, checked on every record built from it
//   multiclass  - on every defm
assert !eq(!size("abc"), 3), "size is broken";

class PersonName<string name> {
  assert !le(!size(name), 32), "person name is too long: " # name;
  string Name = name;
}
class Person<string name, int age> : PersonName<name> {
  assert !and(!ge(age, 1), !le(age, 120)), "person age is invalid: " # age;
  int Age = age;
}
def Knuth : Person<"Donald Knuth", 86>;

#ifdef BAD
def Methuselah : Person<"Methuselah", 969>;
#endif
// BAD: error: assertion failed: person age is invalid: 969
// BAD: error: assertion failed in this record
// BAD-NEXT: def Methuselah

// ---- Try it yourself: answers -----------------------------------------------
// A register class that rejects names longer than 4 characters.
class ShortReg<string n> {
  assert !le(!size(n), 4), "register name too long: " # n;
  string AsmName = n;
}
def RSP : ShortReg<"rsp">;
#ifdef BAD
def RTOOLONG : ShortReg<"rtoolong">;
#endif
// BAD: error: assertion failed: register name too long: rtoolong

// ---- Expected output --------------------------------------------------------
// CHECK-LABEL: def Knuth { // PersonName Person
// CHECK-NEXT:  string Name = "Donald Knuth";
// CHECK-NEXT:  int Age = 86;
// CHECK-NEXT:  }
// CHECK-LABEL: def RSP { // ShortReg
// CHECK-NEXT:  string AsmName = "rsp";
// CHECK-NEXT:  }
