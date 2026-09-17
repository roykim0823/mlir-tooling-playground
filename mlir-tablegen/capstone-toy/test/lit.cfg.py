# -*- Python -*-
# Main lit config for the Toy capstone test suite. Same two-file layout as
# ../../../lit-and-filecheck/example/test/lit.cfg.py; the one real difference is
# that the tool under test is OUR binary (toy-opt, in the build dir), not the
# prebuilt mlir-opt.

import os

import lit.formats
from lit.llvm import llvm_config

config.name = "TOY_CAPSTONE"
config.test_format = lit.formats.ShTest(not llvm_config.use_lit_shell)
config.suffixes = [".mlir", ".test", ".toytext"]   # .test: LSP sessions (lsp.test); .toytext: toy-translate imports
config.excludes = ["Inputs"]                       # helper files for tests, not tests themselves

config.test_source_root = os.path.dirname(__file__)
config.test_exec_root = os.path.join(config.toy_obj_root, "test")

# %s, %t, FileCheck, not, count, ... (FileCheck/not come from the prebuilt LLVM).
llvm_config.use_default_substitutions()
llvm_config.with_environment("PATH", config.llvm_tools_dir, append_path=True)

# `toy-opt` in a RUN line resolves to the freshly built binary. Because it is a
# substitution (not just PATH), lit errors out at config time if it is missing
# instead of silently running some other toy-opt.
llvm_config.add_tool_substitutions(["toy-opt", "toy-reduce", "toy-lsp-server", "toy-translate"], [config.toy_tools_dir])
# ...and on PATH, so helper scripts (test/Inputs/interesting.sh) can call toy-opt.
llvm_config.with_environment("PATH", config.toy_tools_dir, append_path=True)

# plugin.mlir drives the STOCK mlir-opt with our dialect loaded as a plugin.
# `%toy_plugin` expands to the built library (path baked in by CMake). The test
# is gated on the `toy-plugin` feature so a build without libMLIR simply
# reports it as UNSUPPORTED.
llvm_config.add_tool_substitutions(["mlir-opt"], [config.llvm_tools_dir])
if config.toy_plugin_available:
    config.available_features.add("toy-plugin")
    config.substitutions.append(("%toy_plugin", config.toy_plugin))
