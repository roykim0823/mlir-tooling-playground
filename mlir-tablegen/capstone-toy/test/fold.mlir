// The -toy-fold pass end to end: the DRR pattern from ToyOps.td and the PDLL
// patterns from ToyPatterns.pdll, wrapped in the pass declared in ToyPasses.td,
// driven by our own toy-opt.
//
// RUN: toy-opt %s -toy-fold | FileCheck %s
//
// The same pass with options, spelled the way -pass-pipeline requires. The
// `report` option emits a remark (on stderr, hence 2>&1) with the fold count;
// the IR itself goes to /dev/null so FileCheck sees only the diagnostic.
// RUN: toy-opt %s -pass-pipeline='builtin.module(toy-fold{report=true})' \
// RUN:   -o /dev/null 2>&1 | FileCheck %s --check-prefix=REPORT
//
// max-iterations=1 still folds everything (one greedy iteration runs its
// worklist to a fixpoint) but the driver cannot *confirm* convergence without
// a second, no-change iteration, and the remark says so.
// RUN: toy-opt %s -pass-pipeline='builtin.module(toy-fold{max-iterations=1 report=true})' \
// RUN:   -o /dev/null 2>&1 | FileCheck %s --check-prefix=ONE

// CHECK-LABEL: func.func @single_fold
func.func @single_fold() -> f64 {
  // CHECK-NEXT: %[[C:.*]] = toy.constant 3.000000e+00
  // CHECK-NEXT: return %[[C]]
  %0 = toy.constant 1.0
  %1 = toy.constant 2.0
  %2 = toy.add %0, %1
  return %2 : f64
}

// A chain add(add(1,2),3) needs two rounds: the inner add folds first, and
// only then does the outer one see two constants.
// CHECK-LABEL: func.func @chained_fold
func.func @chained_fold() -> f64 {
  // CHECK-NEXT: %[[C:.*]] = toy.constant 6.000000e+00
  // CHECK-NEXT: return %[[C]]
  // CHECK-NOT: toy.add
  %0 = toy.constant 1.0
  %1 = toy.constant 2.0
  %2 = toy.constant 3.0
  %3 = toy.add %0, %1
  %4 = toy.add %3, %2
  return %4 : f64
}

// Nothing to fold when an operand is not a constant.
// CHECK-LABEL: func.func @non_constant_untouched
// CHECK-SAME:  (%[[ARG:.*]]: f64)
func.func @non_constant_untouched(%arg: f64) -> f64 {
  // CHECK-NEXT: %[[C:.*]] = toy.constant 1.000000e+00
  // CHECK-NEXT: %[[S:.*]] = toy.add %[[ARG]], %[[C]]
  // CHECK-NEXT: return %[[S]]
  %0 = toy.constant 1.0
  %1 = toy.add %arg, %0
  return %1 : f64
}

// The PDLL patterns (ToyPatterns.pdll): mul(const, const) folds via the native
// FoldMulF64 rewrite, and mul by 1.0 disappears in either operand order.
// CHECK-LABEL: func.func @mul_fold_pdll
func.func @mul_fold_pdll() -> f64 {
  // CHECK-NEXT: %[[C:.*]] = toy.constant 6.000000e+00
  // CHECK-NEXT: return %[[C]]
  %0 = toy.constant 2.0
  %1 = toy.constant 3.0
  %2 = toy.mul %0, %1
  return %2 : f64
}

// CHECK-LABEL: func.func @mul_by_one_pdll
// CHECK-SAME:  (%[[ARG:.*]]: f64)
func.func @mul_by_one_pdll(%arg: f64) -> (f64, f64) {
  // CHECK-NEXT: return %[[ARG]], %[[ARG]]
  %one = toy.constant 1.0
  %0 = toy.mul %arg, %one
  %1 = toy.mul %one, %arg
  return %0, %1 : f64, f64
}

// DRR and PDLL patterns interleave in one greedy run: mul folds (PDLL), then
// the add sees two constants (DRR).
// CHECK-LABEL: func.func @mixed_drr_pdll
func.func @mixed_drr_pdll() -> f64 {
  // CHECK-NEXT: %[[C:.*]] = toy.constant 7.000000e+00
  // CHECK-NEXT: return %[[C]]
  %0 = toy.constant 2.0
  %1 = toy.constant 3.0
  %2 = toy.mul %0, %1
  %3 = toy.constant 1.0
  %4 = toy.add %2, %3
  return %4 : f64
}

// toy.sub has NO DRR or PDLL pattern. It folds because the C++ pattern in
// ToyPatterns.cpp is written against BinaryArithOpInterface, which toy.sub
// implements (ToyInterfaces.td / ToyInterfaces.cpp).
// CHECK-LABEL: func.func @sub_fold_interface
func.func @sub_fold_interface() -> f64 {
  // CHECK-NEXT: %[[C:.*]] = toy.constant 2.000000e+00
  // CHECK-NEXT: return %[[C]]
  %0 = toy.constant 5.0
  %1 = toy.constant 3.0
  %2 = toy.sub %0, %1
  return %2 : f64
}

// The pass never removes side-effecting ops: toy.print keeps the value alive.
// CHECK-LABEL: func.func @print_kept
func.func @print_kept() {
  // CHECK-NEXT: %[[C:.*]] = toy.constant 5.000000e+00
  // CHECK-NEXT: toy.print %[[C]]
  %0 = toy.constant 2.0
  %1 = toy.constant 3.0
  %2 = toy.add %0, %1
  toy.print %2
  return
}

// Eleven BinaryArithOpInterface ops (add/mul/sub) in this file; all but the
// non-constant add fold.
// REPORT: remark: toy-fold: folded 10 op(s)
// REPORT-NOT: max-iterations

// ONE: remark: toy-fold: folded 10 op(s); stopped at max-iterations without confirming a fixpoint
