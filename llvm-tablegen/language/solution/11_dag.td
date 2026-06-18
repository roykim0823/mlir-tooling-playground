// =============================================================================
// Lesson 11 — DAGs (Directed Acyclic Graphs)
//
//   A `dag` value is a tree node with an operator and zero or more arguments,
//   each of which can itself be a `dag`. The operator must be a record.
// =============================================================================

def set;
def add;
def GR32;

class Reg;
def EAX : Reg;
def EBX : Reg;

def Pattern {
  // (set EAX:$dst, (add EBX:$src1, 5))
  dag P = (set EAX:$dst, (add EBX:$src1, 5));
}

// -----------------------------------------------------------------------------
// DAG-manipulating bang operators.
// -----------------------------------------------------------------------------
def op;

def Demo {
  dag D1 = (op 1:$a, 2:$b);
  dag D2 = (op 3:$c);
  dag D3 = !con(D1, D2);        // (op 1:$a, 2:$b, 3:$c)
  int N  = !size(D3);           // 3

  // Operator and argument access.
  int     Arg0 = !getdagarg<int>(D1, 0);    // 1
  string  Nm0  = !getdagname(D1, 0);        // "a"
}

// -----------------------------------------------------------------------------
// "Try it yourself" — (add r1, (mul r2, r3)) and extract an argument.
// -----------------------------------------------------------------------------
def mul;
def r1;
def r2;
def r3;

def Tree {
  dag Expr = (add r1, (mul r2, r3));
  int NumArgs = !size(Expr);    // 2
}
