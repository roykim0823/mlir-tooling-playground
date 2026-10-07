# The TableGen language

Seventeen lessons on the TableGen language, in the order of the
[TableGen Programmer's Reference](https://releases.llvm.org/20.1.0/docs/TableGen/ProgRef.html)
(ProgRef): lexical elements and types, then values, then statements, then
the further topics. The last two lessons put the language to work.

Each lesson is one file in [`examples/`](examples). The file contains the
code from the lesson, the answers to its exercises, and its expected output
as FileCheck lines. Lit runs it as a test:

```bash
llvm-tblgen examples/08_let.td        # read the output yourself
lit -v examples/08_let.td             # or check it against the CHECK lines
lit -sv examples                      # all seventeen
```

> **Version.** Everything here is checked against `llvm-tblgen` 20.1.8. Read
> the [LLVM 20 ProgRef](https://releases.llvm.org/20.1.0/docs/TableGen/ProgRef.html),
> not the one on llvm.org/docs, which is built from LLVM's main branch. The
> main-branch page lists bang operators that LLVM 20 rejects as
> `unknown operator`, such as `!match`, `!instances` and `!getdagopname`.

## How to read an example

```tablegen
// RUN: llvm-tblgen %s | FileCheck %s                                   (1)
// RUN: not llvm-tblgen -DBAD_LET %s 2>&1 | FileCheck --check-prefix=BAD %s
...the lesson's code...                                                 (2)
#ifdef BAD_LET                                                          (3)
let Own = 5 in
  def Bad : Inst { int Own = 3; }
#endif
// BAD: error: Value 'Own' unknown!
// ---- Try it yourself: answers ----                                    (4)
// ---- Expected output ----                                             (5)
// CHECK-LABEL: def ADD { // Inst
// CHECK-NEXT:  bit hasSideFx = 0;
```

1. `RUN:` lines are the commands. `%s` is the file itself. Lit runs them from
   [`../lit.cfg.py`](../lit.cfg.py), which puts LLVM's `bin/` on `PATH` (set
   `LLVM_BIN` if yours is not Homebrew's `llvm@20`).
2. The code is the lesson's code, unabridged.
3. A deliberate error is fenced in `#ifdef`, so it only runs when the second
   `RUN:` line passes `-D`. The `BAD:` lines check the diagnostic.
4. The exercise answers come after the lesson code. Try the exercises in the
   README before reading them.
5. The expected output. `--print-records` (the default) prints classes and
   then defs, **sorted by name**, so the `CHECK-LABEL` blocks follow that
   order and not the order of the source.

Change something and rerun lit: the first line of output that moved is
reported with the expected and actual text side by side. Track 1
([`../../lit-and-filecheck`](../../lit-and-filecheck)) explains `RUN:`,
`CHECK-LABEL`, `CHECK-NEXT` and `CHECK-NOT` in detail.

### Flags used here

| Flag | Meaning |
|---|---|
| `--print-records` | Print every class and record. The default. |
| `--print-detailed-records` | Also globals, source locations, and which `defm` made each record. |
| `--dump-json` | Every record as JSON (lesson 17; [`../backend/json`](../backend/json)). |
| `-I <dir>` | Add an include directory (lesson 15). |
| `-D <name>` | Define a preprocessor macro (lesson 15). |
| `--no-warn-on-unused-template-args` | Silence the warning shown in lesson 7. |

## Lessons

| # | Lesson | File | ProgRef |
|---|---|---|---|
| 1 | [Records, fields and literals](#1--records-fields-and-literals) | [`01_records_and_literals.td`](examples/01_records_and_literals.td) | Lexical Analysis; `def` |
| 2 | [Types](#2--types) | [`02_types.td`](examples/02_types.td) | Types; Simple values |
| 3 | [Values and suffixes](#3--values-and-suffixes) | [`03_values_and_suffixes.td`](examples/03_values_and_suffixes.td) | Values and Expressions; Suffixed values |
| 4 | [Bang operators](#4--bang-operators) | [`04_bang_operators.td`](examples/04_bang_operators.td) | Bang operators; Appendix A |
| 5 | [The paste operator](#5--the-paste-operator-) | [`05_paste.td`](examples/05_paste.td) | The paste operator; Appendix B |
| 6 | [Classes and records](#6--classes-and-records) | [`06_classes.td`](examples/06_classes.td) | `class`; `def`; Examples: classes and records |
| 7 | [Template arguments](#7--template-arguments) | [`07_template_args.td`](examples/07_template_args.td) | `class` (template args, `NAME`); Record Bodies |
| 8 | [`let`, and how records are built](#8--let-and-how-records-are-built) | [`08_let.td`](examples/08_let.td) | `let`; How records are built |
| 9 | [`multiclass` and `defm`](#9--multiclass-and-defm) | [`09_multiclass.td`](examples/09_multiclass.td) | `multiclass`; `defm`; Examples |
| 10 | [`defvar`, `defset`, `deftype`](#10--defvar-defset-deftype) | [`10_defvar_defset_deftype.td`](examples/10_defvar_defset_deftype.td) | `defvar`; `defset`; `deftype`; Defvar in a record body |
| 11 | [`foreach` and `if`](#11--foreach-and-if) | [`11_foreach_if.td`](examples/11_foreach_if.td) | `foreach`; `if` |
| 12 | [`dump` and `assert`](#12--dump-and-assert) | [`12_dump_assert.td`](examples/12_dump_assert.td) | `dump`; `assert` |
| 13 | [DAGs](#13--dags) | [`13_dags.td`](examples/13_dags.td) | Directed acyclic graphs |
| 14 | [Classes as subroutines](#14--classes-as-subroutines) | [`14_subroutines.td`](examples/14_subroutines.td) | Using Classes as Subroutines |
| 15 | [Preprocessing and `include`](#15--preprocessing-and-include) | [`15_preprocessor.td`](examples/15_preprocessor.td) | Include files; Preprocessing Facilities |
| 16 | [Capstone: MiniISA](#16--capstone-miniisa) | [`16_miniisa.td`](examples/16_miniisa.td) | (all of the above) |
| 17 | [Capstone: instruction encoding and `field`](#17--capstone-instruction-encoding-and-field) | [`17_encoding.td`](examples/17_encoding.td) | `field`; Suffixed values |
| | [Appendix: bang operators in LLVM 20](#appendix--bang-operators-in-llvm-20) | | Appendix A |

---

## 1 — Records, fields and literals

A **record** is a named set of typed fields, defined with `def`. A field
always states its type, because TableGen does not infer a field's type from
its value. `?` means "no value yet".

```tablegen
def Apple {
  string Color  = "red";
  int    Weight = 150;
  bit    Edible = 1;
  string Origin = ?;
}
```

Literals:
- Integers can be decimal, `0x` hex or `0b` binary. The sign belongs to the
  token, so `-42` is one literal.
- `true` and `false` are 1 and 0.
- Adjacent strings concatenate, as in C. The escapes are `\\ \' \" \t \n`.
- `[{ ... }]` is a code literal: a string that can span lines.
- `/* */` comments nest.
- An identifier may start with digits (`def 3DNow`), as long as the token is
  not a number.

The printer echoes strings without re-escaping them, and a field initialized
with a code literal prints as `code`:

```
def Literals {
  ...
  string Escaped = "a	b"c";
  code Code = [{x + 1}];
}
```

**Try it yourself.** Add a `list<int> SeedCounts = [2, 3, 5]` and a
`bits<4> RipenessScale = 0b1010` to `Apple`.

## 2 — Types

| Type | Values |
|---|---|
| `bit` | 0 or 1 |
| `int` | 64-bit signed integer |
| `string` | characters; `code` is another spelling |
| `bits<n>` | n individually addressable bits |
| `list<T>` | elements of type T, including other lists |
| `dag` | `(operator args...)`, a node of a tree (lesson 13) |
| *ClassName* | a record that inherits from that class |

```tablegen
def TypeShowcase {
  bits<8>        Opcode = 0b00010110;
  list<list<int>> Matrix = [[1, 2], [3, 4]];
  dag            D      = (op 1, "two");
  Anything       Ref    = X;              // X must be derived from Anything
}
```

A value converts implicitly when nothing is lost: an int to `bits<4>`, a
`bits<4>` to an int, 0 or 1 to a `bit`. `{0, 1, 1, 1}` is a bits value
written MSB first. An empty list needs its element type: `[]<int>`.

A class-typed field rejects anything else. The example builds this error
under `-DBAD_TYPE`:

```
error: Field 'R' of type 'Anything' is incompatible with value '5' of type 'int'
```

**Try it yourself.** Make a `bits<16>` instruction word, then extract its top
6 bits as an opcode and the low 10 as an immediate.

## 3 — Values and suffixes

A value can be followed by suffixes that select part of it:

| Suffix | Selects |
|---|---|
| `v{3}` | bit 3 of an int or bits value (bit 0 is least significant) |
| `v{7...4}` | bits 7 down to 4; `v{4...7}` gives the same bits reversed |
| `v{7, 0, 1}` | any list of bit positions |
| `l[1]` | element 1 of a list |
| `l[1,]` | a one-element list (note the trailing comma) |
| `l[3...4, 0, 0]` | a new list; ranges and repeats in any order |
| `l[!range(2)]` | indices can be expressions |
| `r.F` | field `F` of record `r` |

An identifier on its own can name several things: a field of this record, a
record, a template argument, a `defvar`, or a `foreach` variable.

```tablegen
def Lookups {
  int    Y = Other.X;
  int    Z = !add(Y, 1);              // Y: this record's own field
  string N = !cast<string>(Other);    // "Other"
}
```

The range syntax `{7-4}` with a hyphen is deprecated; use `...`.

**Try it yourself.** Split `0xBEEF` into its low and high bytes, and take
every other element of a list with a slice.

## 4 — Bang operators

A **bang operator** is a built-in function whose name starts with `!`. LLVM 20
has 51 of them, plus `!cond`. Lesson 4 uses all 43 that do not work on dags;
lesson 13 uses the other 8. The [appendix](#appendix--bang-operators-in-llvm-20)
lists them all.

Booleans are ints: 0 is false and anything else is true. A boolean result is
1 or 0.

```tablegen
int Quot = !div(-7, 2);              // -3: signed, rounds toward zero
int Srl  = !srl(-16, 60);            // 15: logical shift
int Sra  = !sra(-16, 2);             // -4: arithmetic shift
int From = !find("abcabc", "c", 3);  // 5: search starts at index 3
list<int> R3 = !range(10, 0, -3);    // [10, 7, 4, 1]
list<int> R4 = !range(["a", "b", "c"]);   // [0, 1, 2]: the indices
```

`!if(c, a, b)` and `!cond(c1 : v1, c2 : v2, ...)` choose a value. `!cond`
tries its conditions in order, and it is an error if none is true, so end with
`true : default`. `!foreach`, `!filter` and `!foldl` map, filter and fold a
list:

```tablegen
int Max = !foldl(0, [3, 9, 2, 7], m, x, !if(!gt(x, m), x, m));   // 9
```

`!cast<T>` converts a value. Cast a record to `string` to get its name; cast a
string to a record class to look up the record with that name. `!isa`,
`!exists` and `!initialized` test types, names and `?`. `!repr` turns any
value into a string for debugging; its format is not stable.

`!head` and `!tail` look odd until you write a recursive class, where `!tail`
shrinks the list on each step:

```tablegen
class Sum<list<int> xs> {
  int ret = !if(!empty(xs), 0, !add(!head(xs), Sum<!tail(xs)>.ret));
}
```

**Try it yourself.** The maximum of a list with `!foldl`; the odd numbers in
`!range(10)` with `!filter`; weekday names for 0–6 with `!cond`.

## 5 — The paste operator `#`

`#` concatenates strings or lists. It is the only infix operator, and it has
one odd rule: **an undefined name, or the name of a global `defvar` or
`defset`, is taken as verbatim text.**

| Where | Left operand | Right operand |
|---|---|---|
| a `def`/`defm` name | global names verbatim | global names verbatim |
| any other expression | evaluated | global names verbatim |

```tablegen
defvar suffix = "_suffstring";
def name # suffix;                           // record "namesuffix"
foreach i = [1, 2] in def rec # i;           // rec1, rec2: i is not global
string Strings = suffix # suffix;            // "_suffstringsuffix"
string Forced  = "x" # !cast<string>(suffix);   // "x_suffstring"
string S       = n #;                        // trailing #: n as a string
```

Template arguments, fields and `foreach` variables are not global, so pasting
them works as expected: `"x" # num` inside a class gives `"x5"`. When a global
must be evaluated on the right, wrap it in a bang operator.

**Try it yourself.** A class `GPR<int n>` with `AsmName = "x" # n`, and
records `GPR0`..`GPR7` made in a `foreach`.

## 6 — Classes and records

A **class** is an abstract record. `def D : C` creates record `D` with all of
`C`'s fields, and `let` in the body overrides a field. A record can also add
fields of its own.

```tablegen
class Fruit { string Color = "unknown"; bit Edible = 1; }
def Apple  : Fruit { let Color = "red"; }
def Cherry : Fruit { let Color = "dark red"; int Pits = 1; }
```

The comment the printer puts after `def` lists every class the record
inherits from, indirect ones first:

```
def Mango {	// Fruit Tropical
```

With **multiple inheritance**, the parents' fields are merged left to right,
so when two parents define the same field the *last* one wins: `def AB : A,
B` takes `B`'s `V`.

The lesson also includes ProgRef's `ModRefBits` example, where one class
reshapes another's data (a 2-bit `Value` becomes two named bits).

**Try it yourself.** A class `Vehicle` with `int Wheels = 4; bit Motorized =
1;` and records `Bicycle`, `Truck` and `Skateboard` that override it.

## 7 — Template arguments

```tablegen
class Inst<int opc, string mnem = "?", bit hasSideFx = 0> { ... }
def NOP : Inst<0x00>;                    // two defaults
def DIV : Inst<opc=0x20, mnem="div">;    // named
def MUL : Inst<0x21, hasSideFx=1>;       // positional, then named
```

- Arguments with a default are optional, and must come after the required
  ones.
- Positional arguments come before named ones, and no argument may be given
  twice.
- Every class has an implicit argument **`NAME`**, the name of the `def` or
  `defm` that inherits it. It matters most in multiclasses (lesson 9).
- A record can pass its own name to its parents: `def rec1 :
  SelfRef<(ops rec1)>`.
- An argument the class never reads gets a warning:
  `warning: unused template argument: Unused:unused`.

**Try it yourself.** A class `GPR<int n>` with `AsmName = "x" # n`, and
records `X0`..`X3`.

## 8 — `let`, and how records are built

`let` overrides a field. In a record body it affects that record. At top
level, `let ... in` affects every record defined in its scope, which is a
braced block or a single statement; scopes nest.

```tablegen
let hasSideFx = 1 in {
  def STORE : Inst;
  let Latency = 8 in
    def STORE8 : Inst;
}
```

Details:
- **Bit ranges.** The body form writes `let Opcode{7...4} = ...`; the
  top-level form writes `let Opcode<7...4> = ... in`.
- **The body wins.** Top-level bindings are applied right after inheritance,
  so a body `let` overrides them: `let Latency = 2 in def MUL : Inst { let
  Latency = 3; }` gives 3.
- **Inherited fields only.** A top-level `let` must name an inherited field.
  If the record defines the field itself, it is an *error*:
  `error: Value 'Own' unknown!` (the example's `-DBAD_LET` run).
- **No template arguments.** A `let` cannot set a template argument.

**How records are built** (ProgRef's order):

1. Inherit the parent classes' fields and substitute their template
   arguments.
2. Apply top-level `let`s.
3. Process the body: fields, `let`s, `defvar`s.
4. Resolve references between fields.

Step 4 comes last, so a `let` changes every field computed from the one it
sets. Template arguments were substituted in step 1, so they do not change:

```tablegen
class C<int x> { int Y = x; int Yplus1 = !add(Y, 1); int xplus1 = !add(x, 1); }
let Y = 10 in def rec1 : C<5>;     // Y = 10, Yplus1 = 11, xplus1 = 6
```

There is no "let append". To grow a list along a class chain, pass the extra
elements down as template arguments and `!listconcat` them; the lesson builds
`["HasV1", "HasV2", "HasFP"]` this way.

**Try it yourself.** Mark a group of instruction records as calls with one
top-level `let`, and add a third level to the list chain.

## 9 — `multiclass` and `defm`

A **multiclass** is a macro that defines several records. **`defm`** invokes
it. Inside the multiclass, `def _rr` means `def NAME # _rr`, so `defm ADD`
produces `ADD_rr`:

```tablegen
multiclass ri_inst<int opc, string asmstr> {
  def _rr : Inst<opc, ..., (ops GPR:$dst, GPR:$src1, GPR:$src2)>;
  def _ri : Inst<opc, ..., (ops GPR:$dst, GPR:$src1, Imm:$src2)>;
}
defm ADD : ri_inst<0b111, "add">;      // ADD_rr, ADD_ri
```

- A `defm` inside a multiclass is prefixed with `NAME` too. `basic_s` calls
  `basic_r` twice, so `defm FADD : basic_s` gives `FADDSSrr`, `FADDSSrm`,
  `FADDSDrr`, `FADDSDrm` and `FADDX`.
- A `defm` lists one or more multiclasses, then any plain classes. The plain
  classes' fields are added to every record it produces (`defm SS : R, XD`).
- A multiclass can inherit other multiclasses (`multiclass LoadStore :
  Loads`), and can contain `let`, `defvar`, `foreach`, `if` and `assert`.
- `defm : M;` gives the records a unique generated name
  (`anonymous_N_ld`), while `defm "" : M;` uses the multiclass's own names
  as they are (`_ld`).

**Try it yourself.** A multiclass `ShiftOps<int opc>` that produces `_l`,
`_r` and `_ra`, invoked as `defm SH : ShiftOps<0x3>;`.

## 10 — `defvar`, `defset`, `deftype`

- **`defvar`** names a value. At top level it is a global; inside a class or
  record body it is a local that does *not* become a field. It cannot be
  reassigned. An inner `defvar` shadows an outer name from that point on, so
  in `Shadow<3>`, `Before` is 3 and `After` is 7.
- **`defset list<C> Name = { ... }`** defines the records inside as usual and
  also collects them into a global list. A nested `defset` adds its records
  to both lists. Anonymous records created by `C<...>` inside an expression
  are not collected.
- **`deftype byte = bits<8>;`** names a type. It is allowed at top level only,
  and only for primitive types and other aliases.

```tablegen
defset list<Reg> AllRegs = {
  def R0 : Reg<0>;
  defset list<Reg> ArgRegs = { def A0 : Reg<10>; def A1 : Reg<11>; }
}
// !size(AllRegs) = 3, !size(ArgRegs) = 2
```

**Try it yourself.** Two `defset`s for callee- and caller-saved registers, and
a summary record built with `!listconcat` and `!size`.

## 11 — `foreach` and `if`

Both repeat or select *statements* (`def`, `defm`, `let`, nested loops) at top
level or in a multiclass. To compute a field's value inside a record, use
`!foreach` and `!if`.

```tablegen
foreach i = 0...3 in def R # i : Reg<i>;          // a range
foreach i = {8-9, 12} in def H # i : Reg<i>;      // a range list
foreach name = ["sp", "lr"] in def !toupper(name) : Reg<0>;   // any list
foreach i = !range(2) in {                        // a braced body
  defvar sq = !mul(i, i);                         // lives for one iteration
  def Sq # i : Reg<sq>;
}
```

`if c then ... else ...` chooses statements; a dangling `else` binds to the
nearest `if`. ProgRef says `if` can also appear inside a record body, but
`llvm-tblgen` 20 rejects that (`Unknown token when expecting a type`).

**Try it yourself.** Use `foreach` and `if` to make registers `X0`..`X31`, the
first 8 with `IsArg = 1`.

## 12 — `dump` and `assert`

**`dump "msg";`** prints a note on stderr: at top level immediately, and in a
class or multiclass each time something instantiates it. Pair it with `!repr`
to inspect a value.

```
12_dump_assert.td:19:3: note: MC got (op 1, 2)
```

**`assert cond, "msg";`** reports an **error** when `cond` is false.
`llvm-tblgen` finishes parsing and then exits with failure. When the check
happens depends on where the `assert` is:

| Where | Checked |
|---|---|
| top level | immediately |
| record | once the record is fully built |
| class | on every record built from it (it is inherited) |
| multiclass | on every `defm` |

Under `-DBAD` the example builds `Methuselah : Person<"Methuselah", 969>`:

```
error: assertion failed: person age is invalid: 969
error: assertion failed in this record
def Methuselah : Person<"Methuselah", 969>;
```

**Try it yourself.** Make a register class reject names longer than 4
characters.

## 13 — DAGs

A `dag` is `(operator arg, ...)`. The operator must be a record. Each argument
is a `value`, a `value:$name`, or a bare `$name` whose value is `?` (printed
`?:$name`). Arguments can be dags, which makes a tree. LLVM uses dags for
operand lists `(outs ...)`/`(ins ...)` and for instruction-selection patterns.

| Operator | Result |
|---|---|
| `!getdagop(d)`, `!getdagop<T>(d)` | the operator, optionally cast to class T |
| `!getdagarg<T>(d, key)` | an argument by index or `$name`; `?` if not a T |
| `!getdagname(d, i)` | the name of argument i |
| `!setdagop(d, op)` | d with a new operator |
| `!setdagarg(d, key, v)` | d with one argument replaced |
| `!setdagname(d, key, n)` | d with one argument renamed |
| `!con(d1, d2, ...)` | arguments concatenated; the operators must match |
| `!dag(op, args, names)` | a dag built from lists |
| `!size(d)`, `!empty(d)` | argument count; the operator is not counted |
| `!foreach(x, d, expr)` | each argument mapped (x is typed as a dag) |

```tablegen
dag Con = !con((add 1:$a, 2:$b), (add 3:$c));      // (add 1:$a, 2:$b, 3:$c)
dag Map = !foreach(x, (add EAX:$a, EBX:$b), !subst(EBX, EAX, x));
                                                   // (add EAX:$a, EAX:$b)
```

**Try it yourself.** Build `(add r1, (mul r2, r3))`, then read its second
argument back as a dag and get that dag's operator.

## 14 — Classes as subroutines

`ClassName<args>` used as a value creates an anonymous record, and a suffix
reads one of its fields. That makes a class a function: the template
arguments are the inputs, the fields the outputs. Several fields return
several values.

```tablegen
class DivMod<int a, int b> { int q = !div(a, b); int r = !sub(a, !mul(q, b)); }
def QR { int Q = DivMod<23, 5>.q; int R = DivMod<23, 5>.r; }    // 4, 3
```

A class can call itself, which is how a loop with an unknown number of steps
is written:

```tablegen
class Gcd<int a, int b> {
  int ret = !if(!eq(b, 0), a, Gcd<b, !sub(a, !mul(!div(a, b), b))>.ret);
}
```

**Try it yourself.** `Clamp<v, lo, hi>`, then `ClampPow2<v>`, which clamps to
[1, 16] and tests the result with `IsPow2`.

## 15 — Preprocessing and `include`

`include "file.td"` pastes a file in place, searching the `-I` directories.
The preprocessor only does conditional compilation. A macro has no value: it
is defined (by `#define` or `-D` on the command line) or it is not.

| Directive | Effect |
|---|---|
| `#define M` | define M |
| `#ifdef M` / `#ifndef M` | start a region kept if M is / is not defined |
| `#else`, `#endif` | the other branch; the end of the region |

Regions nest, and a region must end in the file it starts in. Macros defined
before an `include` apply inside the included file
([`Inputs/15_registers.td`](examples/Inputs/15_registers.td) tests `HAS_FP`).
The example has two `RUN:` lines, with and without `-DHAS_VECTOR`, and checks
which records each one produces.

Lessons 2, 8 and 12 use the same trick to keep an error case in the file
next to the working code.

**Try it yourself.** Make a record appear only when building with
`-DDEBUG_INFO`.

## 16 — Capstone: MiniISA

A toy ISA with 4 registers and 14 instructions, using most of the language
at once:
- `defset` collects the registers.
- A multiclass gives each ALU operation register-register and
  register-immediate forms.
- A top-level `let` sets flags on a group of instructions.
- `foreach` with `assert` validates the register names.
- A `Summary` record computes facts with `!filter`, `!foreach` and
  `!interleave`.

```
def Summary {
  int NumRegs = 4;
  int NumCalleeSaved = 2;
  string CalleeList = "r2, r3";
}
```

The same ISA comes back twice in [`../backend`](../backend). `json/` turns
these records into a C++ header. `stock/03_mini_target.td` rewrites the ISA
against LLVM's `Target.td`, so that the real `--gen-register-info`,
`--gen-instr-info`, `--gen-asm-writer`, `--gen-emitter` and
`--gen-disassembler` backends accept it.

## 17 — Capstone: instruction encoding and `field`

This is the most common pattern in target descriptions. A fixed-width
encoding word is assembled from bit ranges of operand fields:

```tablegen
class Inst<bits<6> opcode> {
  field bits<32> Inst;
  let Inst{31-26} = opcode;
}
class RType<bits<6> opcode, bits<6> funct> : Inst<opcode> {
  bits<5> rd; bits<5> rs; bits<5> rt; bits<5> shamt = 0;
  let Inst{25-21} = rs;  let Inst{20-16} = rt;  let Inst{15-11} = rd;
  let Inst{10-6} = shamt;  let Inst{5-0} = funct;
}
def ADD : RType<0b000000, 0b100000> { let rd = 1; let rs = 2; let rt = 3; }
```

In the class, `Inst` is a list of references (`rs{4}`, `RType:funct{0}`, …)
to operand fields that are still `?`. In `ADD` they resolve to plain bits,
0x00430820.

`field` is a reserved word that ProgRef calls deprecated except for this use:
it marks `Inst` as the encoding rather than an operand. With `llvm-tblgen` 20,
`--gen-emitter` produces the same output with or without it. It does change
`--dump-json`, which lists `field` members under `"!fields"`; the second
`RUN:` line checks that with `jq`.

---

## Appendix — Bang operators in LLVM 20

All 51, plus `!cond`, from LLVM 20's Appendix A. The lesson column says where
each is used.

| Group | Operators | Lesson |
|---|---|---|
| Arithmetic | `!add` `!sub` `!mul` `!div` `!logtwo` | 4 |
| Bitwise | `!and` `!or` `!xor` `!not` `!shl` `!srl` `!sra` | 4 |
| Comparison | `!eq` `!ne` `!lt` `!le` `!gt` `!ge` | 4 |
| Choice | `!if` `!cond` | 4 |
| Strings | `!strconcat` `!substr` `!find` `!subst` `!toupper` `!tolower` `!interleave` | 4 |
| Lists | `!listconcat` `!listflatten` `!listremove` `!listsplat` `!range` `!head` `!tail` | 4 |
| Strings, lists, dags | `!size` `!empty` | 4, 13 |
| Iteration | `!foreach` `!filter` `!foldl` | 4, 13 |
| Types and records | `!cast` `!isa` `!exists` `!initialized` `!repr` | 4 |
| DAGs | `!con` `!dag` `!getdagop` `!getdagarg` `!getdagname` `!setdagop` `!setdagarg` `!setdagname` | 13 |

`!getop` and `!setop` still parse but are deprecated in favour of `!getdagop`
and `!setdagop`.

## Where to go next

- [`../README.md`](../README.md) runs the stock backends on the real X86
  target, where every lesson above appears at scale.
- [`../backend`](../backend) covers what consumes these records: the stock
  `--gen-*` backends, a backend written as a script over `--dump-json`, and
  backends written in C++.
