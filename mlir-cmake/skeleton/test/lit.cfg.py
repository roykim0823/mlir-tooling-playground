import os
import lit.formats
from lit.llvm import llvm_config

config.name = "HELLO"
config.test_format = lit.formats.ShTest(not llvm_config.use_lit_shell)
config.suffixes = [".mlir"]
config.test_source_root = os.path.dirname(__file__)
config.test_exec_root = os.path.join(config.hello_obj_root, "test")
config.excludes = ["CMakeLists.txt"]

llvm_config.use_default_substitutions()
llvm_config.with_environment("PATH", config.llvm_tools_dir, append_path=True)
# hello-opt lives in build/bin because of LLVM_RUNTIME_OUTPUT_INTDIR.
llvm_config.add_tool_substitutions(["hello-opt"], [config.hello_tools_dir])
