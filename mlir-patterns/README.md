# Rewriting IR — DRR and PDLL

Once ODS has defined the ops, the next thing every dialect needs is a way to
**rewrite** them: constant folding, canonicalization, lowering. MLIR offers two
declarative languages for that, and this track teaches them side by side, on
the same toy dialect, lesson for lesson:

| Directory | Language | Tool | Compiles to |
|---|---|---|---|
| [`drr/`](drr) | **DRR**, Declarative Rewrite Rules, written in TableGen (`Pat`, `Pattern`) | `mlir-tblgen --gen-rewriters` | C++ `RewritePattern` classes |
| [`pdll/`](pdll) | **PDLL**, MLIR's own pattern language | `mlir-pdll` | PDL, a dialect of IR describing patterns, interpreted at run time |

Read [`drr/`](drr/README.md) first: it is the shorter of the two and introduces
the vocabulary (source pattern, result pattern, constraints, native code).
Then read [`pdll/`](pdll/README.md), whose five lessons are the PDLL twins of
the five DRR lessons and which ends with a DRR-vs-PDLL-vs-C++ comparison. The
third option, a hand-written C++ `RewritePattern`, appears in
[`../mlir-capstone/`](../mlir-capstone/README.md), where all three kinds of
pattern run in the same pass.

Both halves need the ODS lessons ([`../mlir-tablegen/ods/`](../mlir-tablegen/ods))
first: a pattern's operators are the ops you defined there.

```bash
./gen-all.sh          # mlir-tblgen over drr/, mlir-pdll over pdll/, output under generated/
```
