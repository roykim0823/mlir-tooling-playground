// =============================================================================
// Lesson 9 — `defvar`, `defset`, `deftype`
// =============================================================================

// -----------------------------------------------------------------------------
// `defvar` — a named, immutable variable.
// -----------------------------------------------------------------------------
defvar BaseOpc = 0x20;
defvar Names   = ["add", "sub", "mul"];

class Op<int idx> {
  int    Opc = !add(BaseOpc, idx);
  string Asm = Names[idx];
}

def OP0 : Op<0>;        // Opc = 0x20, Asm = "add"
def OP1 : Op<1>;        // Opc = 0x21, Asm = "sub"
def OP2 : Op<2>;        // Opc = 0x22, Asm = "mul"

// -----------------------------------------------------------------------------
// `defset` — collect records into a global list.
//
//   Records inside the braces are still defined globally, and are *also*
//   appended to the named list.
// -----------------------------------------------------------------------------
class Reg<int n> { int Num = n; }

defset list<Reg> AllRegs = {
  def R0 : Reg<0>;
  def R1 : Reg<1>;
  def R2 : Reg<2>;
}

def Counter {
  int NumRegs = !size(AllRegs);     // 3
}

// "Try it yourself" — callee/caller saved sets plus a summary.
defset list<Reg> Callee = {
  def S0 : Reg<8>;
  def S1 : Reg<9>;
}

defset list<Reg> Caller = {
  def T0 : Reg<10>;
  def T1 : Reg<11>;
  def T2 : Reg<12>;
}

def RegSummary {
  list<Reg> Saved   = !listconcat(Callee, Caller);
  int       NumAll  = !size(!listconcat(Callee, Caller));   // 5
  int       NumCallee = !size(Callee);                      // 2
  int       NumCaller = !size(Caller);                      // 3
}

// -----------------------------------------------------------------------------
// `deftype` — alias for a type (top level, primitive types / aliases only).
// -----------------------------------------------------------------------------
deftype byte     = bits<8>;
deftype halfword = bits<16>;

def Insn {
  byte     Opcode = 0xAB;
  halfword Imm    = 0xBEEF;
}
