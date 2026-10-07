# A backend in Python, over `--dump-json`

The TableGen Overview offers two ways to write a backend: extend TableGen in
C++ ([`../writing`](../writing)), or "write a script in any language that can
consume the JSON output". This is the second way. [`td2cpp.py`](td2cpp.py)
runs `llvm-tblgen --dump-json` and turns the records into a C++ header:

| TableGen | C++ |
|---|---|
| record `R2` | `struct R2_t { … };` and `constexpr R2_t R2 = { … };` |
| `int`, `bit` | `int64_t` |
| `string`, `code` | `const char*` |
| `bits<n>`, `list<T>` | `std::array<…, n>`; a `bits` array is least significant bit first |
| `dag`, record references | a string with the JSON |
| class `Inst` | `std::array<const char*, N> AllInst`, the names of its records |

The JSON format is documented in BackEnds under
[JSON Reference](https://releases.llvm.org/20.1.0/docs/TableGen/BackEnds.html#json-reference).
[`../stock`](../stock) lesson 1 shows a sample. A `null` value is `?`;
`"!instanceof"` maps each class to its records; each record carries
`"!superclasses"`, `"!fields"`, `"!locs"` and `"!anonymous"`.

## Run it

```bash
python3 td2cpp.py --out-dir gen ../../language/examples/16_miniisa.td
```

```cpp
struct R2_t {  // Register
  const char* AsmName;
  int64_t CalleeSaved;
  std::array<int64_t, 2> Encoding;
};
constexpr R2_t R2 = { "r2", 1, {{ 0, 1 }} };      // bits<2> 0b10, LSB first
...
constexpr std::array<const char*, 4> AllRegister = {{ "R0", "R1", "R2", "R3" }};
```

[`CMakeLists.txt`](CMakeLists.txt) runs the script as a build step on the
language track's two capstone lessons and compiles a program against each
header. It needs Python and `llvm-tblgen`, and no LLVM libraries:

```bash
cmake -S . -B build && cmake --build build
./build/miniisa_demo     # MiniISA summary: 4 regs, 2 callee-saved (r2, r3) ...
./build/encoding_demo    # ADD  (R-type) encoding = 0x00430820 ...
```

`encoding_demo` packs lesson 17's `Inst` bits back into a 32-bit word. That is
the value `--gen-emitter` would compute; [`../stock`](../stock) lesson 3 runs
the real thing.

| File | Test |
|---|---|
| [`td2cpp.py`](td2cpp.py) | [`td2cpp.test`](td2cpp.test) checks the header it writes for lesson 16 |
| [`miniisa_demo.cpp`](miniisa_demo.cpp), [`encoding_demo.cpp`](encoding_demo.cpp) | [`demos.test`](demos.test) runs both (after the CMake build) |

## Script or C++?

A script is quick to write, works in any language, and needs no LLVM headers
or libraries. In exchange:

- You only get **defs**. Classes, template arguments and unresolved
  expressions (`"kind": "complex"`) are not in the JSON.
- There are **no source locations to point an error at**: you get the
  `"!locs"` strings, but not TableGen's diagnostics with the offending line.
- **Large inputs are slow**: X86's JSON takes about 7 seconds to write.

`td2cpp.py` is also schema-agnostic: it mirrors whatever the `.td` contains.
A real backend knows its schema (which classes and fields mean what) and
emits exactly the tables its consumer needs. [`../writing`](../writing) does
that in C++.
