#!/usr/bin/env bash
# Runs the scene-based test harnesses in test/ headlessly and reports PASS/FAIL.
#
#   ./tools/run_tests.sh              # uses `godot` from PATH
#   GODOT=/path/to/godot ./tools/run_tests.sh
#
# Each harness is a Node script that drives a live run and prints "PASS: name"
# or "FAIL: name" per check. They expect to be autoloaded alongside the main
# scene, so this injects each one into [autoload] in turn and restores
# project.godot afterwards.
#
# test_shot and test_shot_gear are omitted: they are visual probes and assert
# nothing, so they have no pass/fail to report.
set -uo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
SUITES=(test_chars test_elite test_gear test_joy test_stages test_ui)
BACKUP="$(mktemp)"
cp project.godot "$BACKUP"
restore() { cp "$BACKUP" project.godot; rm -f "$BACKUP"; }
trap restore EXIT

"$GODOT" --headless --path . --import >/dev/null 2>&1

total_pass=0
total_fail=0
failed_suites=()

for suite in "${SUITES[@]}"; do
	cp "$BACKUP" project.godot
	python3 - "$suite" <<'PY'
import sys
suite = sys.argv[1]
p = "project.godot"
s = open(p).read()
assert "[autoload]\n\n" in s, "no [autoload] section in project.godot"
open(p, "w").write(s.replace("[autoload]\n\n",
    '[autoload]\n\nTestRunner="*res://test/%s.gd"\n' % suite, 1))
PY
	out="$(timeout 300 "$GODOT" --headless --path . --quit-after 2000 2>&1)"
	pass=$(printf '%s\n' "$out" | grep -c '^PASS: ')
	fail=$(printf '%s\n' "$out" | grep -c '^FAIL: ')
	total_pass=$((total_pass + pass))
	total_fail=$((total_fail + fail))
	if [ "$fail" -ne 0 ] || [ "$pass" -eq 0 ]; then
		failed_suites+=("$suite")
		printf '%-14s pass=%-4s fail=%-4s  PROBLEM\n' "$suite" "$pass" "$fail"
		printf '%s\n' "$out" | grep '^FAIL: ' | sed 's/^/    /'
		[ "$pass" -eq 0 ] && echo "    (no checks ran at all -- harness did not reach its assertions)"
	else
		printf '%-14s pass=%-4s fail=%-4s  ok\n' "$suite" "$pass" "$fail"
	fi
done

echo "-----------------------------------------"
echo "TOTAL pass=$total_pass fail=$total_fail"
if [ "${#failed_suites[@]}" -ne 0 ]; then
	echo "FAILING SUITES: ${failed_suites[*]}"
	exit 1
fi
