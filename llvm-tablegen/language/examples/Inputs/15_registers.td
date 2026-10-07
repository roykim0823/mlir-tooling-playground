// Included by 15_preprocessor.td. Lit skips this directory (see lit.cfg.py);
// it is only ever read through `include`.

class Reg<string n> { string AsmName = n; }
def R0 : Reg<"r0">;
def R1 : Reg<"r1">;

// The macro defined in the including file is visible here.
#ifdef HAS_FP
def F0 : Reg<"f0">;
#endif
