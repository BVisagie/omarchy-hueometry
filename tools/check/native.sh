#!/usr/bin/env bash
# Builds the generator natively (C, via clang) and checks it produces exactly
# the puzzles the JavaScript build does: the game runs the JavaScript build,
# the laws are proved about Bend's semantics, and both lanes must agree.
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build
bend tests/native/gen.bend -o build/gen-native >/dev/null
./build/gen-native > build/gen-native.txt
node tests/native/gen.mjs > build/gen-js.txt
if ! diff -u build/gen-js.txt build/gen-native.txt; then
  echo "the native and JavaScript generators disagree" >&2
  exit 1
fi
echo "native and JavaScript generators agree on $(wc -l < build/gen-js.txt) puzzles"
