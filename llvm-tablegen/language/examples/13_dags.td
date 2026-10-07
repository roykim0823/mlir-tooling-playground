// RUN: llvm-tblgen %s | FileCheck %s
//
// Lesson 13 — DAGs
// ProgRef: "Directed acyclic graphs (DAGs)", DAG operators in Appendix A
//
// A dag value is a node: (operator arg, arg, ...). The operator must be a
// record; each argument is a value, a value:$name, or a bare $name whose value
// is `?`. Arguments can be dags, so a dag is a tree. LLVM uses dags for
// operand lists and instruction-selection patterns.

class Node;
def set : Node;
def add : Node;
def mul : Node;
class Reg;
def EAX : Reg;
def EBX : Reg;

def Pattern {
  dag P = (set EAX:$dst, (add EBX:$src1, 5));
  dag N = (add $lhs, $rhs);                     // printed as ?:$lhs, ?:$rhs
}

// ---- Taking a dag apart -----------------------------------------------------
def Get {
  dag     D     = (add 1:$a, "two":$b);
  Node    Op    = !getdagop<Node>(D);           // the operator, cast to a class
  int     Arg0  = !getdagarg<int>(D, 0);        // by index...
  string  ArgB  = !getdagarg<string>(D, "b");   // ...or by name
  string  Name1 = !getdagname(D, 1);
  int     Size  = !size(D);                     // arguments only
  bit     Empty = !empty((add));
}

// ---- Building and changing dags ---------------------------------------------
def Build {
  dag D1   = (add 1:$a, 2:$b);
  dag Con  = !con(D1, (add 3:$c));                  // operators must match
  dag Made = !dag(mul, [1, 2], ["x", "y"]);         // operator, args, names
  dag Op   = !setdagop(D1, mul);
  dag Arg  = !setdagarg(D1, "b", 20);
  dag Nm   = !setdagname(D1, 0, "first");
  dag Ops  = (add EAX:$a, EBX:$b);
  dag Map  = !foreach(x, Ops, !subst(EBX, EAX, x)); // map over the arguments
  dag Same = !dag(!getdagop(D1), [7], ["z"]);       // reuse an operator, no cast
}

// ---- Try it yourself: answers -----------------------------------------------
// 1. The tree (add r1, (mul r2, r3)).
// 2. Read its second argument back as a dag, and that dag's operator.
def r1; def r2; def r3;
def Tree {
  dag Expr  = (add r1, (mul r2, r3));
  int Args  = !size(Expr);
  dag Inner = !getdagarg<dag>(Expr, 1);
  string InnerOp = !cast<string>(!getdagop(!getdagarg<dag>(Expr, 1)));
}

// ---- Expected output --------------------------------------------------------
// CHECK-LABEL: def Build {
// CHECK-NEXT:  dag D1 = (add 1:$a, 2:$b);
// CHECK-NEXT:  dag Con = (add 1:$a, 2:$b, 3:$c);
// CHECK-NEXT:  dag Made = (mul 1:$x, 2:$y);
// CHECK-NEXT:  dag Op = (mul 1:$a, 2:$b);
// CHECK-NEXT:  dag Arg = (add 1:$a, 20:$b);
// CHECK-NEXT:  dag Nm = (add 1:$first, 2:$b);
// CHECK-NEXT:  dag Ops = (add EAX:$a, EBX:$b);
// CHECK-NEXT:  dag Map = (add EAX:$a, EAX:$b);
// CHECK-NEXT:  dag Same = (add 7:$z);
// CHECK-NEXT:  }
// CHECK-LABEL: def Get {
// CHECK-NEXT:  dag D = (add 1:$a, "two":$b);
// CHECK-NEXT:  Node Op = add;
// CHECK-NEXT:  int Arg0 = 1;
// CHECK-NEXT:  string ArgB = "two";
// CHECK-NEXT:  string Name1 = "b";
// CHECK-NEXT:  int Size = 2;
// CHECK-NEXT:  bit Empty = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def Pattern {
// CHECK-NEXT:  dag P = (set EAX:$dst, (add EBX:$src1, 5));
// CHECK-NEXT:  dag N = (add ?:$lhs, ?:$rhs);
// CHECK-NEXT:  }
// CHECK-LABEL: def Tree {
// CHECK-NEXT:  dag Expr = (add r1, (mul r2, r3));
// CHECK-NEXT:  int Args = 2;
// CHECK-NEXT:  dag Inner = (mul r2, r3);
// CHECK-NEXT:  string InnerOp = "mul";
// CHECK-NEXT:  }
