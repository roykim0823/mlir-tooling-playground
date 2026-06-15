#!/usr/bin/env bash
# Runs every chapter's "Try it" script in order. Builds the example once up front.
#
#   ./run-all.sh              run chapters 1..6
#   LLVM_BIN=/path ./run-all.sh   use a specific LLVM build
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

ensure_built

for n in 01 02 03 04 05 06; do
  echo
  echo "###################################################################"
  echo "###  scripts/try-$n.sh"
  echo "###################################################################"
  bash "$SCRIPTS_DIR/try-$n.sh"
done

echo
echo ">> All chapter scripts completed successfully."
