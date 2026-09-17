// The Toy dialect and the -toy-fold pass inside the STOCK mlir-opt, loaded
// from ToyPlugin.dylib/.so (lib/ToyPlugin.cpp). No toy-opt involved. The same library
// serves as both the dialect plugin and the pass plugin.
//
// REQUIRES: toy-plugin
//
// Passes from a plugin are run through -pass-pipeline, NOT as a `-toy-fold`
// flag: mlir-opt parses its command line before it loads plugins, so the
// per-pass flags of plugin passes never exist. The pipeline string is parsed
// after loading and works.
// RUN: mlir-opt --load-dialect-plugin=%toy_plugin --load-pass-plugin=%toy_plugin %s \
// RUN:   -pass-pipeline='builtin.module(toy-fold)' | FileCheck %s
//
// The dialect plugin alone is enough to parse and print; only the pass needs
// the second flag.
// RUN: mlir-opt --load-dialect-plugin=%toy_plugin %s | FileCheck %s --check-prefix=PARSE
//
// Without the plugin, stock mlir-opt does not know the dialect at all.
// RUN: not mlir-opt %s 2>&1 | FileCheck %s --check-prefix=NOPLUGIN

// CHECK-LABEL: func.func @folded_by_plugin_pass
func.func @folded_by_plugin_pass() -> f64 {
  // CHECK-NEXT: %[[C:.*]] = toy.constant 5.000000e+00
  // CHECK-NEXT: return %[[C]]
  %0 = toy.constant 2.0
  %1 = toy.constant 3.0
  %2 = toy.add %0, %1
  return %2 : f64
}

// PARSE-LABEL: func.func @folded_by_plugin_pass
// PARSE: toy.add

// NOPLUGIN: error: Dialect `toy' not found for custom op 'toy.constant'
