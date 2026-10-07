# -*- Python -*-
# One lit suite for the whole llvm-tablegen track. Every example .td carries its
# own RUN: lines and the CHECK: lines that are its expected output, so
#
#     lit -v llvm-tablegen                 # everything
#     lit -v llvm-tablegen/language        # one directory
#     lit -v llvm-tablegen/language/examples/08_let.td   # one file
#
# replays the track and fails on the first line of output that drifted.
#
# Unlike the lit-and-filecheck example (track 1), there is no CMake-generated
# lit.site.cfg.py: the only configuration is where LLVM lives, read from
# $LLVM_BIN with the Homebrew llvm@20 path as the default.

import os

import lit.formats

config.name = "llvm-tablegen"
config.test_format = lit.formats.ShTest(execute_external=True)
config.suffixes = [".td", ".test"]
config.test_source_root = os.path.dirname(__file__)
config.test_exec_root = os.path.join(config.test_source_root, ".lit-out")

# Inputs/ hold files that RUN lines include; x86/ is the fetched X86 target;
# build/ trees hold CMake's own files.
config.excludes = ["Inputs", "x86", "build", ".lit-out"]

llvm_bin = os.environ.get("LLVM_BIN", "/opt/homebrew/opt/llvm@20/bin")
llvm_include = os.path.join(os.path.dirname(llvm_bin), "include")
if not os.path.exists(os.path.join(llvm_bin, "llvm-tblgen")):
    lit_config.fatal(f"no llvm-tblgen in {llvm_bin}; set LLVM_BIN")

# llvm-tblgen, FileCheck, not and count all resolve from the LLVM install.
config.environment["PATH"] = os.pathsep.join(
    [llvm_bin, config.environment.get("PATH", os.environ["PATH"])])
config.environment["LLVM_BIN"] = llvm_bin

root = config.test_source_root
config.substitutions.append(("%llvm_include", llvm_include))
config.substitutions.append(("%x86", os.path.join(root, "x86")))
config.substitutions.append(
    ("%writing_bin", os.path.join(root, "backend", "writing", "build")))
config.substitutions.append(
    ("%stock_bin", os.path.join(root, "backend", "stock", "build")))
config.substitutions.append(
    ("%json_bin", os.path.join(root, "backend", "json", "build")))

# Optional pieces become features, so their tests report UNSUPPORTED instead of
# failing when the piece has not been fetched or built yet.
if os.path.exists(os.path.join(root, "x86", "X86.td")):
    config.available_features.add("x86-td")
if os.path.exists(os.path.join(root, "backend", "writing", "build", "01-skeleton")):
    config.available_features.add("writing-build")
if os.path.exists(os.path.join(root, "backend", "stock", "build", "searchable-demo")):
    config.available_features.add("stock-build")
if os.path.exists(os.path.join(root, "backend", "json", "build", "miniisa_demo")):
    config.available_features.add("json-build")
for tool in ("jq", "python3"):
    if any(os.access(os.path.join(p, tool), os.X_OK)
           for p in os.environ["PATH"].split(os.pathsep)):
        config.available_features.add(tool)
