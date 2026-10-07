// RUN: llvm-tblgen %s | FileCheck %s
//
// Lesson 1 — Records, fields and literals
// ProgRef: "Lexical Analysis", "def"
//
// A record is a named bag of typed fields, defined with `def`. Every field
// states its type: TableGen never infers a field's type from its value.

def Apple {
  string Color  = "red";
  int    Weight = 150;        // grams
  bit    Edible = 1;
  string Origin = ?;          // `?` is the uninitialized value
}

// Integer literals are decimal (the sign is part of the token), hex or binary.
// `true` and `false` are spellings of 1 and 0.
def Literals {
  int    Dec  = -42;
  int    Hex  = 0xff;
  int    Bin  = 0b1010;
  bit    Yes  = true;
  bit    No   = false;
  string Joined  = "abc" "def";      // adjacent strings concatenate, as in C
  string Escaped = "a\tb\"c";        // escapes: \\ \' \" \t \n
  string Code = [{x + 1}];           // a code literal is a string...
}
// ...that the printer still remembers as `code`. Strings are printed raw, not
// re-escaped: the tab and the quote in Escaped come out literally.

/* C-style comments /* nest */, unlike in C or C++. */

// An identifier may start with digits, as long as it is not a number.
def 3DNow { bit Deprecated = true; }

// ---- Try it yourself: answers -----------------------------------------------
// 1. A list<int> field SeedCounts initialized to [2, 3, 5].
// 2. A bits<4> field RipenessScale set to 0b1010.
def AppleWithSeeds {
  list<int> SeedCounts    = [2, 3, 5];
  bits<4>   RipenessScale = 0b1010;
}

// ---- Expected output: defs are printed sorted by name -----------------------
// CHECK-LABEL: def 3DNow {
// CHECK-NEXT:  bit Deprecated = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def Apple {
// CHECK-NEXT:  string Color = "red";
// CHECK-NEXT:  int Weight = 150;
// CHECK-NEXT:  bit Edible = 1;
// CHECK-NEXT:  string Origin = ?;
// CHECK-NEXT:  }
// CHECK-LABEL: def AppleWithSeeds {
// CHECK-NEXT:  list<int> SeedCounts = [2, 3, 5];
// CHECK-NEXT:  bits<4> RipenessScale = { 1, 0, 1, 0 };
// CHECK-NEXT:  }
// CHECK-LABEL: def Literals {
// CHECK-NEXT:  int Dec = -42;
// CHECK-NEXT:  int Hex = 255;
// CHECK-NEXT:  int Bin = 10;
// CHECK-NEXT:  bit Yes = 1;
// CHECK-NEXT:  bit No = 0;
// CHECK-NEXT:  string Joined = "abcdef";
// CHECK-NEXT:  string Escaped = "a b"c";
// CHECK-NEXT:  code Code = [{x + 1}];
// CHECK-NEXT:  }
