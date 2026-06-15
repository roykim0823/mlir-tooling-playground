# -*- Python -*-
# The hand-written ("main") lit config. This is the file you edit by hand and
# check into source control. The generated lit.site.cfg.py (in the build dir)
# sets the absolute paths and then load_config()s this file.

import os

import lit.formats
from lit.llvm import llvm_config

# Suite name shown in lit's reports.
config.name = "LIT_FILECHECK_EXAMPLE"

# ShTest = "treat each RUN: line as a shell command".
config.test_format = lit.formats.ShTest(not llvm_config.use_lit_shell)

# Files with these extensions are tests.
config.suffixes = [".mlir"]

# Where the .mlir test files live (this directory).
config.test_source_root = os.path.dirname(__file__)

# Where tests execute (the build dir, set by the site config).
config.test_exec_root = os.path.join(config.example_obj_root, "test")

# Registers the standard substitutions: FileCheck, count, not, %s, %t, etc.
# Requires config.llvm_tools_dir, which the site config set for us.
llvm_config.use_default_substitutions()

# Make the tools used in RUN lines resolve to the prebuilt LLVM/MLIR binaries.
# This both (a) puts the tools dir on PATH and (b) registers `mlir-opt` as a
# substitution pointing at the exact built binary.
llvm_config.with_environment("PATH", config.llvm_tools_dir, append_path=True)
llvm_config.add_tool_substitutions(["mlir-opt", "mlir-runner"], [config.llvm_tools_dir])
