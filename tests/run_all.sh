#!/bin/bash
# Runs every test in tests/ (each *_test.gd, headless at a fixed 60 fps) and prints a line
# per test with its result, then any failed checks. Exits 1 if anything failed.
#   tests/run_all.sh                 every test
#   tests/run_all.sh units classic   just these (names without "_test.gd")
# The Godot binary can be set with GODOT=/path/to/Godot.
# (The performance checks, tests/perf_*.gd, are run separately: they measure, not pass/fail.)

cd "$(dirname "$0")/.." || exit 1
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
if [ $# -gt 0 ]; then
	list=""
	for n in "$@"; do list="$list tests/${n%_test}_test.gd"; done
else
	list=$(ls tests/*_test.gd)
fi
failed=0
for t in $list; do
	name=$(basename "$t" .gd)
	out=$(perl -e 'alarm 1200; exec @ARGV' "$GODOT" --headless --path . --fixed-fps 60 -s "$t" 2>&1)
	code=$?
	summary=$(echo "$out" | grep -E "checks, [0-9]+ failed|^FAILS:" | tail -1)
	errors=$(echo "$out" | grep -c "SCRIPT ERROR")
	note=""
	[ "$errors" -gt 0 ] && note="  ($errors script errors)"
	printf "%-20s %s%s\n" "$name" "${summary:-no result (crashed or timed out)}" "$note"
	echo "$out" | grep -E "^FAIL |SCRIPT ERROR" | head -8 | sed 's/^/      /'
	if [ $code -ne 0 ] || [ "$errors" -gt 0 ] || [ -z "$summary" ]; then
		failed=1
	fi
done
exit $failed
