# Runnable "Try it" scripts

One script per tutorial chapter. Each echoes every command before running it, so
the terminal output reads like a transcript of the chapter's **Try it** section.

| Script | Runs the examples from |
|--------|------------------------|
| `try-01.sh` | `01-lit-basics.md` — `llvm-lit` discovery, filtering, timing |
| `try-02.sh` | `02-filecheck-basics.md` — `CHECK:`, an intentional failure |
| `try-03.sh` | `03-filecheck-directives.md` — directives + `--dump-input=fail` |
| `try-04.sh` | `04-filecheck-variables.md` — capture-and-reuse, undefined-variable demo |
| `try-05.sh` | `05-mlir-testing.md` — check + diagnostic tests via lit |
| `try-06.sh` | `06-hands-on.md` — all six labs (with backup/restore) |
| `run-all.sh` | every chapter, in order |
| `_common.sh` | shared helpers (sourced, not run directly) |

## Usage

```bash
# from tutorials/lit-and-filecheck/
scripts/try-03.sh
scripts/run-all.sh
```

- The example project is built automatically on first run (`ensure_built`).
- Tools are auto-detected from the LLVM build bundled in this repo. Override:
  ```bash
  LLVM_BIN=/path/to/your/llvm-build/bin scripts/run-all.sh
  ```
- Scripts are **idempotent**: the ones that demonstrate failures expect non-zero
  exits, and `try-06.sh` restores any files it modifies on exit.
- Commands labelled `# (expected to fail …)` are teaching the error message —
  a non-zero exit there is success.
