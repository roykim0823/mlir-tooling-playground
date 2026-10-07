// RUN: llvm-tblgen %s | FileCheck %s
//
// Lesson 5 — The paste operator `#`
// ProgRef: "The paste operator", "Appendix B: Paste Operator Examples"
//
// `#` is the only infix operator. It concatenates strings or lists, with one
// odd rule: an undefined name, or the name of a *global* defvar/defset, is
// taken as verbatim text instead of being evaluated.

defvar suffix    = "_suffstring";
defvar some_ints = [0, 1, 2, 3];

// Rule 1 — in a def/defm name, a global name is verbatim text.
def name # suffix;               // -> "namesuffix", not "name_suffstring"

// ...but a foreach variable is not global, so its value is used.
foreach i = [1, 2] in
  def rec # i;                   // -> rec1, rec2

// Rule 2 — in other expressions the left operand is evaluated and the right
// one, if it is a global name, is verbatim.
def PasteValues {
  string Strings  = suffix # suffix;               // "_suffstringsuffix"
  string Forced   = "x" # !cast<string>(suffix);   // a bang operator forces evaluation
  list<int> Ints  = some_ints # [4, 5, 6];         // lists paste too
}

// Rule 3 — a trailing `#` pastes onto the empty string, turning a value into a
// string.
defvar n = 42;
def Trailing { string S = n #; }

// Template arguments and fields are not global, so they are evaluated.
class Reg<int num> { string AsmName = "x" # num; }
def X5 : Reg<5>;

// ---- Try it yourself: answers -----------------------------------------------
// 1. A class GPR<int n> whose AsmName is "x" # n.
// 2. X0..X7 generated inside a foreach.
class GPR<int n> {
  int    Number  = n;
  string AsmName = "x" # n;
}
foreach i = 0...7 in
  def GPR # i : GPR<i>;

// ---- Expected output --------------------------------------------------------
// CHECK-LABEL: def GPR0 { // GPR
// CHECK-NEXT:  int Number = 0;
// CHECK-NEXT:  string AsmName = "x0";
// CHECK-NEXT:  }
// CHECK-LABEL: def GPR7 { // GPR
// CHECK-NEXT:  int Number = 7;
// CHECK-NEXT:  string AsmName = "x7";
// CHECK-NEXT:  }
// CHECK-LABEL: def PasteValues {
// CHECK-NEXT:  string Strings = "_suffstringsuffix";
// CHECK-NEXT:  string Forced = "x_suffstring";
// CHECK-NEXT:  list<int> Ints = [0, 1, 2, 3, 4, 5, 6];
// CHECK-NEXT:  }
// CHECK-LABEL: def Trailing {
// CHECK-NEXT:  string S = "42";
// CHECK-NEXT:  }
// CHECK-LABEL: def X5 { // Reg
// CHECK-NEXT:  string AsmName = "x5";
// CHECK-NEXT:  }
// CHECK-LABEL: def namesuffix {
// CHECK-NEXT:  }
// CHECK-LABEL: def rec1 {
// CHECK-NEXT:  }
// CHECK-LABEL: def rec2 {
// CHECK-NEXT:  }
