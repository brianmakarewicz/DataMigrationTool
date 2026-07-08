#!/usr/bin/env python
"""
DMT DB <-> git sync guard.

Root problem: fixes get deployed straight to the DB via SQLcl/oracledb
(CREATE OR REPLACE), while the .sql files in git are separate manual snapshots.
Nothing links the two, so a DB change silently drifts from git until someone
remembers to re-dump and commit.

This tool makes the snapshot deterministic: it dumps each tracked DB object to
its git file in a fixed format. Because the format is stable, running --pull and
then `git status` IS the drift report — any diff means the DB was changed without
committing the source.

Usage:
  python dmt_db_git_sync.py --pull    # DB -> git files (run before committing / at session close)
  python dmt_db_git_sync.py --check   # non-zero exit + list if any tracked object differs from git

Workflow that keeps them aligned (see docs/DMT_DESIGN.html C5):
  1. edit the .sql file   2. deploy FROM that file   3. --pull   4. commit
Never hand-type CREATE OR REPLACE against the DB without a matching file.

Extend MANIFEST when a new run-detail object is added.
"""
import sys, os
sys.path.insert(0, r'C:\Users\Monroe\workspace')
from conn_helper import connect_atp

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
HEADER = "-- Deployed on queryapp ATP (DMT_OWNER). Snapshot of live DB object. Do not hand-edit without deploying.\n"

# object_name -> (object_type, relative git path)
MANIFEST = {
    'DMT_V_CEMLI_TFM_TABLES': ('VIEW',      'schema/views/DMT_V_CEMLI_TFM_TABLES.sql'),
    'DMT_RECORD_DETAIL_V':    ('VIEW',      'schema/views/DMT_RECORD_DETAIL_V.sql'),
    'DMT_OBJECT_DETAIL_V':    ('VIEW',      'schema/views/DMT_OBJECT_DETAIL_V.sql'),
    'DMT_V_CATALOG_HEALTH':   ('VIEW',      'schema/views/DMT_V_CATALOG_HEALTH.sql'),
    'DMT_RUN_DETAIL_TILES':   ('PROCEDURE', 'packages/apex/dmt_run_detail_tiles.sql'),
}


def deployed_text(cur, name, otype):
    if otype == 'VIEW':
        cur.execute("SELECT text FROM all_views WHERE view_name=:1 AND owner='DMT_OWNER'", [name])
        row = cur.fetchone()
        if not row:
            return None
        return f"{HEADER}CREATE OR REPLACE VIEW DMT_OWNER.{name} AS\n{row[0]}\n/\n"
    else:  # PROCEDURE / FUNCTION / PACKAGE etc.
        cur.execute("""SELECT text FROM all_source WHERE owner='DMT_OWNER' AND name=:1 AND type=:2
                       ORDER BY line""", [name, otype])
        rows = cur.fetchall()
        if not rows:
            return None
        body = ''.join(r[0] for r in rows)
        return f"{HEADER}CREATE OR REPLACE {body}\n/\n"


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else '--check'
    conn = connect_atp('queryapp', 'DMT_OWNER')
    cur = conn.cursor()
    drift, missing = [], []
    for name, (otype, rel) in MANIFEST.items():
        path = os.path.join(REPO, rel)
        db = deployed_text(cur, name, otype)
        if db is None:
            missing.append(f"{name}: not found in DB")
            continue
        if mode == '--pull':
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                f.write(db)
            print(f"  pulled {name} -> {rel}")
        else:  # --check
            cur_file = open(path, encoding='utf-8').read() if os.path.exists(path) else None
            if cur_file != db:
                drift.append(rel)
                print(f"  DRIFT  {name}  (DB != {rel})")
    cur.close(); conn.close()
    if missing:
        for m in missing:
            print("  WARN  " + m)
    if mode == '--check':
        if drift:
            print(f"\n{len(drift)} object(s) differ from git — run: python scripts/dmt_db_git_sync.py --pull, then commit")
            sys.exit(1)
        print("OK — every tracked DB object matches its git file")
    sys.exit(0)


if __name__ == '__main__':
    main()
