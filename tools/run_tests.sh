#!/usr/bin/env bash
# Run all Vivarium headless test harnesses. Requires Godot 4.7 on PATH
# (override with GODOT=/path/to/godot). Usage:  bash tools/run_tests.sh
set -u
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
echo "Godot: $("$GODOT" --version 2>/dev/null || echo 'NOT FOUND on PATH')"
echo "Building class cache..."
"$GODOT" --headless --import >/dev/null 2>&1
fails=0
for h in phase1 phase2 phase3 phase4 phase6 phase7; do
  printf "  %-8s " "$h"
  res=$("$GODOT" --headless --path . --script "res://test/${h}_harness.gd" 2>&1 | grep -E "RESULT")
  echo "${res:-<no result — see full output>}"
  echo "$res" | grep -q "PASS" || fails=$((fails + 1))
done
echo "--------------------------------------"
if [ "$fails" -eq 0 ]; then echo "ALL PASS"; else echo "$fails harness(es) FAILED"; fi
exit "$fails"
