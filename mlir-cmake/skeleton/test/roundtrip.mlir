// RUN: hello-opt %s | FileCheck %s
// CHECK: hello.world
func.func @f() {
  hello.world
  return
}
