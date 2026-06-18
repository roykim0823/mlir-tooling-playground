// =============================================================================
// Lesson 10 — Control Flow: `foreach`, `if`, `assert`, `dump`
// =============================================================================

class Reg<int n> {
  int Num   = n;
  bit IsLow = !lt(n, 16);
  bit IsArg = 0;
}

// -----------------------------------------------------------------------------
// `foreach` over a range and over a list.
// -----------------------------------------------------------------------------
foreach i = 0...7 in
  def R#i : Reg<i>;          // R0 .. R7

foreach name = ["sp", "lr", "pc"] in
  def !toupper(name) : Reg<0>;   // SP, LR, PC

// Nested foreach.
foreach b = 0...1 in
  foreach n = 0...3 in
    def B#b#_R#n : Reg<n>;   // B0_R0 .. B1_R3

// -----------------------------------------------------------------------------
// `if ... then ... else` at top level.
//
//   "Try it yourself" — 32 registers, first 8 flagged as argument registers.
// -----------------------------------------------------------------------------
foreach i = 0...31 in {
  if !lt(i, 8) then
    def A#i : Reg<i> { let IsArg = 1; }
  else
    def A#i : Reg<i> { let IsArg = 0; }
}

// -----------------------------------------------------------------------------
// `assert` — checks an invariant. In a class it is checked on each record.
// -----------------------------------------------------------------------------
class Person<string name, int age> {
  assert !le(!size(name), 32), "name too long: " # name;
  assert !and(!ge(age, 0), !le(age, 130)), "bad age: " # age;
  string Name = name;
  int    Age  = age;
}

def Knuth : Person<"Donald Knuth", 86>;     // OK
// def Bad : Person<"X", 999>;              // would print a note

// A short-name register class with its own length assertion.
class ShortReg<string n> {
  assert !le(!size(n), 4), "register name too long: " # n;
  string AsmName = n;
}

def RSP : ShortReg<"rsp">;     // OK
