#!/usr/bin/env python
"""
Claude Code PreToolUse guard — enforces git-first DB changes for the DMT project.

Wire it in settings.json (see docs/DMT_DESIGN.html C5). It reads the tool call on
stdin and BLOCKS (exit 2) a Bash/PowerShell command that runs DDL against the DB
directly instead of through the sanctioned deploy tool:

  * CREATE OR REPLACE package/view/procedure/function/trigger/type  -> use `dmt_deploy.py code`
  * ALTER TABLE / CREATE TABLE / DROP                               -> use `dmt_deploy.py table --migration`

Read-only queries (SELECT via connect_atp) are NOT blocked — only DDL.

HONEST LIMITATION: it can only see DDL that appears in the command text (heredocs,
inline `cur.execute("CREATE OR REPLACE ...")`). DDL hidden inside a separate file
that a generic script reads is invisible to the hook — the real enforcement there
is the discipline of using dmt_deploy.py. This is a guardrail, not a sandbox.
"""
import sys, json, re

DDL = re.compile(r'\b(CREATE\s+OR\s+REPLACE\s+'
                 r'(PACKAGE\s+BODY|PACKAGE|VIEW|PROCEDURE|FUNCTION|TRIGGER|TYPE)'
                 r'|ALTER\s+TABLE|CREATE\s+TABLE|DROP\s+(TABLE|VIEW|PACKAGE|PROCEDURE|FUNCTION|TRIGGER|INDEX))\b',
                 re.I)
DB = re.compile(r'connect_atp|oracledb|sqlcl|sqlplus|sql\s+/nolog|apex_export', re.I)
SANCTIONED = re.compile(r'dmt_deploy\.py', re.I)


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # can't parse -> don't interfere
    cmd = (data.get('tool_input', {}) or {}).get('command', '') or ''
    if not cmd:
        sys.exit(0)
    if DDL.search(cmd) and DB.search(cmd) and not SANCTIONED.search(cmd):
        sys.stderr.write(
            "BLOCKED (git-first policy): this command runs DDL against the DB directly.\n"
            "  - Code (package/view/proc): edit the git .sql file, then\n"
            "        python scripts/dmt_deploy.py code <file.sql>\n"
            "  - Table change: add a migration file, update the create-table script, then\n"
            "        python scripts/dmt_deploy.py table --create <create.sql> --migration <mig.sql>\n"
            "  - After deploy: python scripts/dmt_db_git_sync.py --pull && commit.\n"
            "(SELECT-only queries are fine; this only blocks DDL.)\n")
        sys.exit(2)  # exit 2 = block the tool call, stderr shown to the model
    sys.exit(0)


if __name__ == '__main__':
    main()
