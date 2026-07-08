#!/bin/sh
# ============================================================
# run_golden_tests.sh — DMT2 golden-file test runner (Stage B4).
#
# Sibling of test/unit/run_unit_tests.sh: executes every
# test/golden/test_*_golden.sh against the local Docker DB and
# prints one PASS/FAIL line per object. Exit 0 only if every
# compare passed — future CI hook.
#
# Usage:  sh test/golden/run_golden_tests.sh
# Env overrides: DMT2_CONN, SQLCL, JAVA_HOME, PYTHON
# ============================================================

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR" || exit 2

FAILED=0
TOTAL=0
found=0
for t in test_*_golden.sh; do
    [ -e "$t" ] || continue
    found=1
    TOTAL=$((TOTAL + 1))
    sh "$t"
    [ $? -eq 0 ] || FAILED=$((FAILED + 1))
done

if [ $found -eq 0 ]; then
    echo "FAIL  no test_*_golden.sh scripts found in $SCRIPT_DIR"
    exit 2
fi

echo "----"
echo "golden tests: $((TOTAL - FAILED))/$TOTAL passed"
[ $FAILED -eq 0 ] || exit 1
exit 0
