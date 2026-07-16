#!/usr/bin/env python
"""
Claude Code PreToolUse guard — protects the regression staging/transform tables.

The whole point of the scenario system is: load the test data ONCE (as a named
regression scenario), then re-run it in place as many times as needed via the
run-mode flags (NEW / FAILED / ALL) under a new prefix — WITHOUT re-inserting data
or hand-resetting row status. See docs/DMT_DESIGN.html section 7, the canonical
per-object flow + run-mode rules.

This hook BLOCKS (exit 2) a Bash/PowerShell command that:
  * INSERTs into a DMT_*_STG_TBL / DMT_*_TFM_TBL   (re-loading test data), or
  * UPDATEs a *_STG_STATUS / TFM_STATUS column      (hand-resetting row status), or
  * DELETEs from a DMT_*_STG_TBL / DMT_*_TFM_TBL

There is NO exemption — not even the seed script. Test data is inserted into STG
ONCE (the source inventory), and from then on every test re-runs IN PLACE under a
new prefix. Nothing is ever re-inserted, status-reset, or deleted, because doing so
destroys run history and defeats the whole prefix/run-mode design.

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

# Any INSERT/DELETE/TRUNCATE/MERGE against a staging or transform table, or an
# UPDATE of a row-status column.
STG_WRITE = re.compile(
    r'\b(INSERT\s+INTO|DELETE\s+FROM|TRUNCATE\s+TABLE|MERGE\s+INTO)\s+("?DMT_OWNER"?\.)?"?DMT_[A-Z0-9_]+_(STG|TFM)_TBL'
    r'|\bUPDATE\s+("?DMT_OWNER"?\.)?"?DMT_[A-Z0-9_]+_(STG|TFM)_TBL[\s\S]{0,400}?\bSET\b[\s\S]{0,200}?\b(STG_STATUS|TFM_STATUS)\s*=',
    re.I)
DB = re.compile(r'connect_atp|oracledb|sqlcl|sqlplus|sql\s+/nolog|/c/Users/Monroe/tools/sqlcl', re.I)
# Scripts that write STG/TFM internally (the hook can't see SQL inside a file, so
# block them by name). Match only EXECUTION (python <script>), never reading it
# (grep/cat/sed/head of the file is fine).
STG_WRITER_SCRIPT = re.compile(r'\b(python[0-9.]*|py)\s+\S*insert_regression_test_data\.py', re.I)


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # can't parse -> don't interfere
    ti = data.get('tool_input', {}) or {}
    cmd = ti.get('command', '') or ''
    if not cmd:
        sys.exit(0)
    if (STG_WRITE.search(cmd) and DB.search(cmd)) or STG_WRITER_SCRIPT.search(cmd):
        sys.stderr.write(
            "BLOCKED (regression-scenario policy): NO inserts/deletes into STG/TFM tables and\n"
            "NO hand-reset of STG_STATUS/TFM_STATUS — there is no exemption, not even the seed\n"
            "script. Test data is inserted into STG ONCE (the source inventory); from then on\n"
            "every test re-runs IN PLACE under a new prefix. Nothing is re-inserted or deleted.\n"
            "  DMT_SUBMIT_RUN_V2('<PIPELINE>', p_scenario_name=>'RegressionTest', p_run_mode=>'ALL')\n"
            "    ALL = re-run every scenario row (new prefix) | FAILED = retry errors | NEW = new rows\n"
            "(SELECT-only queries are fine; this only blocks staging writes.)\n")
        sys.exit(2)  # exit 2 = block the tool call, stderr shown to the model
    sys.exit(0)


if __name__ == '__main__':
    main()
