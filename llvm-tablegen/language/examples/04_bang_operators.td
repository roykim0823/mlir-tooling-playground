// RUN: llvm-tblgen %s | FileCheck %s
//
// Lesson 4 — Bang operators
// ProgRef: "Bang operators", "Appendix A: Bang Operators"
//
// A bang operator is a built-in function whose name starts with `!`. LLVM 20
// has 51 of them plus `!cond`; this file uses every one except the DAG
// operators, which lesson 13 covers. Booleans are ints: 0 is false, anything
// else is true, and boolean results are 1 or 0.

// ---- Arithmetic, bitwise, shifts --------------------------------------------
def Arith {
  int Sum  = !add(1, 2, 3, 4);     // 10, variadic
  int Diff = !sub(10, 3);          // 7
  int Prod = !mul(2, 3, 4);        // 24, variadic
  int Quot = !div(-7, 2);          // -3, signed, rounds toward zero
  int And  = !and(0b1100, 0b1010); // 8, bitwise
  int Or   = !or(0b1100, 0b1010);  // 14
  int Xor  = !xor(0b1100, 0b1010); // 6
  int Shl  = !shl(1, 4);           // 16
  int Srl  = !srl(-16, 60);        // 15, logical: zeros shifted in
  int Sra  = !sra(-16, 2);         // -4, arithmetic: sign kept
  int Lg2  = !logtwo(17);          // 4, floor(log2)
}

// ---- Comparison and logic ---------------------------------------------------
def Compare {
  bit Eq  = !eq(3, 3);             // ints, bits, strings and records
  bit Ne  = !ne("a", "b");
  bit Lt  = !lt(2, 5);
  bit Le  = !le(5, 5);
  bit Gt  = !gt("b", "a");         // strings compare lexicographically
  bit Ge  = !ge(4, 5);
  bit Not = !not(0);
  bit All = !and(1, 1, 0);         // 0: logical when every operand is 0 or 1
}

// ---- Strings ----------------------------------------------------------------
def Strings {
  string Cat   = !strconcat("Hel", "lo");          // "Hello"
  int    Len   = !size("Hello");                   // 5
  int    Find  = !find("abcabc", "c");             // 2
  int    From  = !find("abcabc", "c", 3);          // 5, search from index 3
  int    Miss  = !find("abc", "z");                // -1
  string Sub   = !substr("Hello world", 6);        // "world", to the end
  string Sub2  = !substr("Hello world", 0, 4);     // "Hell"
  string Subst = !subst("o", "0", "foo boo");      // "f00 b00"
  string Up    = !toupper("abc");
  string Down  = !tolower("ABC");
  string Join  = !interleave([1, 2, 3], ", ");     // "1, 2, 3"
  bit    Empty = !empty("");
}

// ---- Lists ------------------------------------------------------------------
def Lists {
  list<int> Cat    = !listconcat([1, 2], [3], [4]);    // variadic
  list<int> Flat   = !listflatten([[1, 2], [3, 4]]);
  list<int> Remove = !listremove([1, 2, 3, 2], [2]);   // every 2 removed
  list<int> Splat  = !listsplat(7, 3);
  list<int> R1     = !range(4);                        // [0, 1, 2, 3]
  list<int> R2     = !range(1, 4);                     // half-open
  list<int> R3     = !range(10, 0, -3);
  list<int> R4     = !range(["a", "b", "c"]);          // indices of a list
  int       Size   = !size([10, 20, 30]);
  int       Head   = !head([10, 20, 30]);
  list<int> Tail   = !tail([10, 20, 30]);
  bit       Empty  = !empty([]<int>);
}

// !tail exists for recursion over a list: handle !head now, recurse on !tail,
// stop at !empty. A class can name itself, so this computes a sum.
class Sum<list<int> xs> {
  int ret = !if(!empty(xs), 0, !add(!head(xs), Sum<!tail(xs)>.ret));
}
def SumDemo { int Total = Sum<[1, 2, 3, 4]>.ret; }

// ---- Conditionals -----------------------------------------------------------
class Sign<int n> {
  string S1 = !if(!lt(n, 0), "neg", "non-neg");
  // !cond takes condition:value pairs, tried in order; one must be true.
  string S2 = !cond(!lt(n, 0) : "negative",
                    !eq(n, 0) : "zero",
                    true      : "positive");
}
def SignNeg  : Sign<-5>;
def SignZero : Sign<0>;
def SignPos  : Sign<7>;

// ---- Iteration: map, filter, fold -------------------------------------------
def Iterate {
  list<int> Doubled = !foreach(x, [1, 2, 3, 4], !mul(x, 2));
  list<int> Evens   = !filter(x, [1, 2, 3, 4, 5, 6], !eq(!and(x, 1), 0));
  int       Total   = !foldl(0, [1, 2, 3, 4, 5], acc, x, !add(acc, x));
}

// ---- Records, casts and type tests ------------------------------------------
class Animal;
def Dog : Animal;

def Records {
  string    Name   = !cast<string>(Dog);       // a record cast to string: its name
  Animal    ByName = !cast<Animal>("Dog");     // a string cast to a record: lookup
  int       FromB  = !cast<int>(0b1010);
  bit       IsA    = !isa<Animal>(Dog);
  bit       Exists = !exists<Animal>("Cat");   // 0: no such record
  bit       Init   = !initialized(?);          // 0
  string    Repr   = !repr([1, 2]);            // debugging only; format may change
}

// ---- Try it yourself: answers -----------------------------------------------
// 1. The maximum of a list with !foldl.
// 2. The odd numbers in !range(10) with !filter.
// 3. Weekday names for 0-6 with !cond.
class Weekday<int d> {
  string ret = !cond(!eq(d, 0) : "Sun", !eq(d, 1) : "Mon", !eq(d, 2) : "Tue",
                     !eq(d, 3) : "Wed", !eq(d, 4) : "Thu", !eq(d, 5) : "Fri",
                     !eq(d, 6) : "Sat");
}
def Answers {
  int          Max  = !foldl(0, [3, 9, 2, 7], m, x, !if(!gt(x, m), x, m));
  list<int>    Odds = !filter(x, !range(10), !and(x, 1));
  list<string> Days = !foreach(d, !range(7), Weekday<d>.ret);
}

// ---- Expected output --------------------------------------------------------
// CHECK-LABEL: def Answers {
// CHECK-NEXT:  int Max = 9;
// CHECK-NEXT:  list<int> Odds = [1, 3, 5, 7, 9];
// CHECK-NEXT:  list<string> Days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
// CHECK-NEXT:  }
// CHECK-LABEL: def Arith {
// CHECK-NEXT:  int Sum = 10;
// CHECK-NEXT:  int Diff = 7;
// CHECK-NEXT:  int Prod = 24;
// CHECK-NEXT:  int Quot = -3;
// CHECK-NEXT:  int And = 8;
// CHECK-NEXT:  int Or = 14;
// CHECK-NEXT:  int Xor = 6;
// CHECK-NEXT:  int Shl = 16;
// CHECK-NEXT:  int Srl = 15;
// CHECK-NEXT:  int Sra = -4;
// CHECK-NEXT:  int Lg2 = 4;
// CHECK-NEXT:  }
// CHECK-LABEL: def Compare {
// CHECK-NEXT:  bit Eq = 1;
// CHECK-NEXT:  bit Ne = 1;
// CHECK-NEXT:  bit Lt = 1;
// CHECK-NEXT:  bit Le = 1;
// CHECK-NEXT:  bit Gt = 1;
// CHECK-NEXT:  bit Ge = 0;
// CHECK-NEXT:  bit Not = 1;
// CHECK-NEXT:  bit All = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def Iterate {
// CHECK-NEXT:  list<int> Doubled = [2, 4, 6, 8];
// CHECK-NEXT:  list<int> Evens = [2, 4, 6];
// CHECK-NEXT:  int Total = 15;
// CHECK-NEXT:  }
// CHECK-LABEL: def Lists {
// CHECK-NEXT:  list<int> Cat = [1, 2, 3, 4];
// CHECK-NEXT:  list<int> Flat = [1, 2, 3, 4];
// CHECK-NEXT:  list<int> Remove = [1, 3];
// CHECK-NEXT:  list<int> Splat = [7, 7, 7];
// CHECK-NEXT:  list<int> R1 = [0, 1, 2, 3];
// CHECK-NEXT:  list<int> R2 = [1, 2, 3];
// CHECK-NEXT:  list<int> R3 = [10, 7, 4, 1];
// CHECK-NEXT:  list<int> R4 = [0, 1, 2];
// CHECK-NEXT:  int Size = 3;
// CHECK-NEXT:  int Head = 10;
// CHECK-NEXT:  list<int> Tail = [20, 30];
// CHECK-NEXT:  bit Empty = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def Records {
// CHECK-NEXT:  string Name = "Dog";
// CHECK-NEXT:  Animal ByName = Dog;
// CHECK-NEXT:  int FromB = 10;
// CHECK-NEXT:  bit IsA = 1;
// CHECK-NEXT:  bit Exists = 0;
// CHECK-NEXT:  bit Init = 0;
// CHECK-NEXT:  string Repr = "[1, 2]";
// CHECK-NEXT:  }
// CHECK-LABEL: def SignNeg { // Sign
// CHECK-NEXT:  string S1 = "neg";
// CHECK-NEXT:  string S2 = "negative";
// CHECK-NEXT:  }
// CHECK-LABEL: def SignPos { // Sign
// CHECK-NEXT:  string S1 = "non-neg";
// CHECK-NEXT:  string S2 = "positive";
// CHECK-NEXT:  }
// CHECK-LABEL: def SignZero { // Sign
// CHECK-NEXT:  string S1 = "non-neg";
// CHECK-NEXT:  string S2 = "zero";
// CHECK-NEXT:  }
// CHECK-LABEL: def Strings {
// CHECK-NEXT:  string Cat = "Hello";
// CHECK-NEXT:  int Len = 5;
// CHECK-NEXT:  int Find = 2;
// CHECK-NEXT:  int From = 5;
// CHECK-NEXT:  int Miss = -1;
// CHECK-NEXT:  string Sub = "world";
// CHECK-NEXT:  string Sub2 = "Hell";
// CHECK-NEXT:  string Subst = "f00 b00";
// CHECK-NEXT:  string Up = "ABC";
// CHECK-NEXT:  string Down = "abc";
// CHECK-NEXT:  string Join = "1, 2, 3";
// CHECK-NEXT:  bit Empty = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def SumDemo {
// CHECK-NEXT:  int Total = 10;
// CHECK-NEXT:  }
