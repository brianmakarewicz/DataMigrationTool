#!/bin/sh
# ============================================================
# run_golden_tests.sh — DMT2 golden-file test runner (Stage B4).
#
# Sibling of test/unit/run_unit_tests.sh: executes every
# test/golden/test_*_golden.sh against the local Docker DB and
# prints one PASS/FAIL line per object. Exit 0 only if every
# object passes — future CI hook.
#
# DETERMINISM GUARD (2026-07-09)
# ------------------------------
# Each test_*_golden.sh runs the FULL land -> transform -> generate
# -> extract -> golden-compare cycle once, landing fresh staging
# rows and minting a NEW prefix/run each time it is invoked. A
# single pass is NOT sufficient proof: the transform INSERT..SELECT
# assigns the TFM identity id in heap-scan order, so a missing
# ORDER BY only reorders rows on roughly one run in six. To make
# that flakiness a HARD failure, this runner invokes every object's
# test TWICE (two independent runs, new prefix each). Because each
# run byte-compares its own output against the single shared golden,
# "run 1 == golden AND run 2 == golden" transitively proves
# "run 1 == run 2" — the two independent runs produced identical
# output. If either run differs from the golden the object FAILS.
# Override the repeat count with GOLDEN_RUNS (default 2).
#
# Usage:  sh test/golden/run_golden_tests.sh
# Env overrides: DMT2_CONN, SQLCL, JAVA_HOME, PYTHON, GOLDEN_RUNS
# ============================================================

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR" || exit 2

GOLDEN_RUNS="${GOLDEN_RUNS:-2}"

FAILED=0
TOTAL=0
found=0
for t in test_*_golden.sh; do
    [ -e "$t" ] || continue
    found=1
    TOTAL=$((TOTAL + 1))

    # Twice-through determinism guard: run the same object's full
    # cycle GOLDEN_RUNS times (new prefix/run each). Every repeat
    # must pass its golden compare or the object is flaky -> FAIL.
    obj_fail=0
    n=1
    while [ "$n" -le "$GOLDEN_RUNS" ]; do
        echo "-- $t  (determinism run $n/$GOLDEN_RUNS)"
        sh "$t"
        if [ $? -ne 0 ]; then
            obj_fail=1
            echo "FAIL  $t  (run $n/$GOLDEN_RUNS differed from golden — non-deterministic or regressed)"
            break
        fi
        n=$((n + 1))
    done

    if [ $obj_fail -ne 0 ]; then
        FAILED=$((FAILED + 1))
    else
        echo "OK    $t  (byte-identical across $GOLDEN_RUNS independent runs)"
    fi
done

if [ $found -eq 0 ]; then
    echo "FAIL  no test_*_golden.sh scripts found in $SCRIPT_DIR"
    exit 2
fi

echo "----"
echo "golden tests: $((TOTAL - FAILED))/$TOTAL passed (each proven across $GOLDEN_RUNS runs)"
[ $FAILED -eq 0 ] || exit 1
exit 0
