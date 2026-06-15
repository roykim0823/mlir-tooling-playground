// RUN: mlir-opt %s -split-input-file -verify-diagnostics

// Demonstrates: a DIAGNOSTIC test. No FileCheck here. Instead, mlir-opt with
// the -verify-diagnostics flag checks that each emitted error matches an
// expected-error annotation. The test PASSES only if the expected diagnostics
// actually fire. The -split-input-file flag cuts the file into independent
// sub-tests at each five-dash separator line so one broken case does not mask
// the others.
//
// NOTE: keep the five-dash separator out of prose comments. mlir-opt splits on
// any line matching it, so writing it inside an explanatory sentence would
// accidentally create a bogus extra sub-test.

func.func @bad_branch() {
  // expected-error @+1 {{reference to an undefined block}}
  cf.br ^missing
}

// -----

func.func @bad_return() -> i32 {
  %0 = arith.constant 1 : i64
  // expected-error @+1 {{doesn't match function result type ('i32')}}
  return %0 : i64
}
