#!/bin/sh
# ============================================================
# run_unit_tests.sh — DMT2 unit-test runner (Git Bash / POSIX sh)
#
# Executes every test/unit/test_*.sql against the local Docker DB
# (dmt2-local, port 1523) as DMT_OWNER and prints one PASS/FAIL
# line per script. Exit code 0 only if every script passed —
# this is the future CI hook.
#
# Usage:  sh test/unit/run_unit_tests.sh
# Env overrides: DMT2_CONN (full SQLcl connect string),
#                SQLCL (path to sql binary), JAVA_HOME
# ============================================================

set -u

JAVA_HOME="${JAVA_HOME:-/c/Users/Monroe/tools/jdk-21.0.11+10}"
export JAVA_HOME
PATH="$JAVA_HOME/bin:$PATH"
export PATH

SQLCL="${SQLCL:-/c/Users/Monroe/tools/sqlcl/bin/sql}"
DMT2_CONN="${DMT2_CONN:-dmt_owner/DmtLocal#2026@//localhost:1523/FREEPDB1}"

# Repo root = two levels up from this script
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR" || exit 2

FAILED=0
TOTAL=0
LOG_DIR="${TMPDIR:-/tmp}/dmt2_unit_tests"
mkdir -p "$LOG_DIR"

found=0
for t in test_*.sql; do
    [ -e "$t" ] || continue
    found=1
    TOTAL=$((TOTAL + 1))
    log="$LOG_DIR/${t%.sql}.log"

    # Pipe stdin so SQLcl never hangs on a prompt; -S = silent banner
    echo exit | "$SQLCL" -S "$DMT2_CONN" "@$t" > "$log" 2>&1
    rc=$?

    summary=$(grep -E '^TEST_.*: [0-9]+ passed' "$log" | tail -1)
    if [ $rc -eq 0 ] && [ -n "$summary" ]; then
        echo "PASS  $t  ($summary)"
    else
        FAILED=$((FAILED + 1))
        firsterr=$(grep -E 'FAIL test|ORA-|SP2-' "$log" | head -1)
        echo "FAIL  $t  (exit $rc${firsterr:+; $firsterr})  [log: $log]"
    fi
done

if [ $found -eq 0 ]; then
    echo "FAIL  no test_*.sql scripts found in $SCRIPT_DIR"
    exit 2
fi

echo "----"
echo "unit tests: $((TOTAL - FAILED))/$TOTAL passed"
[ $FAILED -eq 0 ] || exit 1
exit 0
