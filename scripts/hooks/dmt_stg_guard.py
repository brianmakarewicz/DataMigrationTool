#!/usr/bin/env python
"""
Claude Code PreToolUse guard — protects the regression staging/transform tables.

The whole point of the scenario system is: load the test data ONCE (as a named
regression scenario), then re-run it in place as many times as needed via the
run-mode flags (NEW / FAILED / ALL) under a new prefix — WITHOUT re-inserting data
or hand-resetting row status. See docs/DMT_DESIGN.html section 7, the canonical
per-object flow + run-mode rules.

This hook BLOCKS (exit 2) a Bash/PowerShell command that:
  * INSERTs into a DMT_*_STG_TBL / DMT_*_TFM_TBL   (re-loading test data ad-hoc), or
  * UPDATEs a *_STG_STATUS / TFM_STATUS column      (hand-resetting row status), or
  * DELETEs from a DMT_*_STG_TBL / DMT_*_TFM_TBL

...unless the command runs the sanctioned scenario-setup script
(insert_regression_test_data.py) — the ONE place test data is (re)loaded, as part
of setting up or resetting a scenario, not on every test run.

To re-run existing scenario data instead of reloading it:
    DMT_SUBMIT_RUN_V2('P2P', p_scenario_name=>'RegressionTest', p_run_mode=>'ALL')
      ALL    = re-run every scenario row under a new prefix
      FAILED = retry only the errored rows
      NEW    = only rows not yet processed

HONEST LIMITATION: like the DDL guard, it only sees SQL in the command text
(heredocs, inline cur.execute). SQL hidden in a separate file a generic script
reads is invisible — the real enforcement there is discipline. Guardrail, not sandbox.
"""
import sys, json, re

# INSERT/DELETE against a staging or transform table, or UPDATE of a row-status column.
STG_WRITE = re.compile(
    r'\b(INSERT\s+INTO|DELETE\s+FROM)\s+("?DMT_OWNER"?\.)?"?DMT_[A-Z0-9_]+_(STG|TFM)_TBL'
    r'|\bUPDATE\s+("?DMT_OWNER"?\.)?"?DMT_[A-Z0-9_]+_(STG|TFM)_TBL[\s\S]{0,400}?\bSET\b[\s\S]{0,200}?\b(STG_STATUS|TFM_STATUS)\s*=',
    re.I)
DB = re.compile(r'connect_atp|oracledb|sqlcl|sqlplus|sql\s+/nolog|/c/Users/Monroe/tools/sqlcl', re.I)
# The one sanctioned place test data is (re)loaded / a scenario is (re)set up.
SANCTIONED = re.compile(r'insert_regression_test_data\.py', re.I)


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # can't parse -> don't interfere
    ti = data.get('tool_input', {}) or {}
    cmd = ti.get('command', '') or ''
    if not cmd:
        sys.exit(0)
    if STG_WRITE.search(cmd) and DB.search(cmd) and not SANCTIONED.search(cmd):
        sys.stderr.write(
            "BLOCKED (regression-scenario policy): don't insert/delete test data into the\n"
            "STG/TFM tables or hand-reset STG_STATUS/TFM_STATUS ad-hoc. Test data is loaded\n"
            "ONCE as a scenario and re-run in place with the run-mode flags:\n"
            "  DMT_SUBMIT_RUN_V2('<PIPELINE>', p_scenario_name=>'RegressionTest', p_run_mode=>'ALL')\n"
            "    ALL = re-run every scenario row (new prefix) | FAILED = retry errors | NEW = new rows\n"
            "To (re)load or set up scenario data, use the one sanctioned script:\n"
            "  python scripts/insert_regression_test_data.py\n"
            "(SELECT-only queries are fine; this only blocks staging writes.)\n")
        sys.exit(2)  # exit 2 = block the tool call, stderr shown to the model
    sys.exit(0)


if __name__ == '__main__':
    main()
