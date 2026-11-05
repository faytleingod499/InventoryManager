#!/bin/bash
# Runs the headless test: ./tests/run.sh   (needs Godot 3.5.3 headless and the decompiled game, see make_stubs.sh)
#   GODOT=/path/to/Godot_v3.5.3-stable_linux_headless.64 GAME=/path/to/decomp ./tests/run.sh
set -e
cd "$(dirname "$0")"
GODOT=${GODOT:-/home/claude/godot/Godot_v3.5.3-stable_linux_headless.64}
./make_stubs.sh
for t in e_inv e_hotbar; do
  echo "##### $t"
  timeout 120 "$GODOT" --path . -s $t.gd 2>&1 | grep -v "^Godot Engine\|^$\|getting unowned cosmetic\|locked$" || true
done
