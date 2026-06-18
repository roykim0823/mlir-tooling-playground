// =============================================================================
// Lesson 7 — The Paste Operator `#`
//
//   `#` is the only infix operator in TableGen. It glues things together:
//   strings, lists, or identifier-like name fragments.
// =============================================================================

// -----------------------------------------------------------------------------
// Rule 1 — In a `def`/`defm` *name*, `#` builds a string.
// -----------------------------------------------------------------------------
class Reg<int n> {
  int Num = n;
}

foreach i = 0...3 in
  def R#i : Reg<i>;          // produces R0, R1, R2, R3

// -----------------------------------------------------------------------------
// Rule 2 — In other expressions: LHS evaluated, RHS may be taken verbatim.
//
//   If the RHS of `#` is an undefined identifier or a *global* name, it is used
//   as a literal string. To force evaluation, wrap it in a bang operator.
// -----------------------------------------------------------------------------
defvar suffix = "_TAIL";

def PasteDemo {
  // suffix is global -> taken VERBATIM as the string "suffix" on the RHS.
  string A = "x" # suffix;                  // "xsuffix"   (surprising!)

  // Force normal evaluation to get the VALUE of suffix:
  string B = "x" # !cast<string>(suffix);   // "x_TAIL"
}

// -----------------------------------------------------------------------------
// Rule 3 — Trailing `#` means "concat to empty string".
// -----------------------------------------------------------------------------
defvar n = 42;
def TrailingPaste {
  string S = n#;             // "42"
}

// -----------------------------------------------------------------------------
// Pasting lists.
// -----------------------------------------------------------------------------
def ListPaste {
  list<int> X = [1, 2, 3] # [4, 5];   // [1, 2, 3, 4, 5]
}

// -----------------------------------------------------------------------------
// "Try it yourself" — a register class whose AsmName is computed with `#`.
// -----------------------------------------------------------------------------
class GPR<int num> {
  int    Number  = num;
  string AsmName = "x" # num;          // "x0", "x1", ...
}

foreach i = 0...7 in
  def X#i : GPR<i>;          // X0 .. X7
