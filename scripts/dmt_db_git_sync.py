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
  python dmt_db_git_sync.py --check --schema DMT2_OWNER   # override target schema

Target schema (whose owner these objects are dumped from) is a parameter:
  * --schema NAME  (CLI), else
  * $DMT2_SCHEMA   (env), else
  * DMT2_OWNER     (default for this repo).

Connection: same convention as dmt_deploy.py / dmt_regression_run.py. Honors
$DMT2_CONN (user/password@dsn) when set; otherwise builds an ATP connection for
the target schema from ~/workspace/connections.json (atp_queryapp wallet + the
schema's password). Nothing hardcodes DMT_OWNER or the frozen ConversionTool
connect_atp() call any more.

Workflow that keeps them aligned (see docs/DMT_DESIGN.html C5):
  1. edit the .sql file   2. deploy FROM that file   3. --pull   4. commit
Never hand-type CREATE OR REPLACE against the DB without a matching file.

Extend MANIFEST when a new run-detail object is added.
"""
import argparse
import os
import re
import sys

import oracledb

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
CONNECTIONS = os.environ.get(
    'DMT2_CONNECTIONS', r'C:\Users\Monroe\workspace\connections.json')
DEFAULT_SCHEMA = os.environ.get('DMT2_SCHEMA', 'DMT2_OWNER')

# object_name -> (object_type, relative git path). DMT2 repo DDL lives under db/,
# NOT the frozen ConversionTool schema/… layout.
MANIFEST = {
    'DMT_V_CEMLI_TFM_TABLES': ('VIEW',      'db/views/dmt_v_cemli_tfm_tables.sql'),
    'DMT_RECORD_DETAIL_V':    ('VIEW',      'db/views/dmt_record_detail_v.sql'),
    'DMT_OBJECT_DETAIL_V':    ('VIEW',      'db/views/dmt_object_detail_v.sql'),
    'DMT_V_CATALOG_HEALTH':   ('VIEW',      'db/views/dmt_v_catalog_health.sql'),
    'DMT_RUN_DETAIL_TILES':   ('PROCEDURE', 'db/procedures/dmt_run_detail_tiles.sql'),
}


def connect(schema):
    """Connect to the target schema. Prefer $DMT2_CONN (user/password@dsn, the
    same convention dmt_deploy.py / dmt_regression_run.py use); otherwise build
    an ATP connection for `schema` from connections.json (atp_queryapp wallet +
    the schema's password)."""
    conn_str = os.environ.get('DMT2_CONN')
    if conn_str:
        m = re.match(r'^([^/]+)/(.+)@(?://)?(.+)$', conn_str)
        if not m:
            sys.exit(f"Cannot parse DMT2_CONN: {conn_str!r}")
        user, password, dsn = m.groups()
        w = os.environ.get('DMT2_WALLET')
        kw = dict(config_dir=w, wallet_location=w,
                  wallet_password=os.environ.get('DMT2_WALLET_PW')) if w else {}
        return oracledb.connect(user=user, password=password, dsn=dsn, **kw)
    return _connect_atp(schema)


def _connect_atp(schema):
    import json
    with open(CONNECTIONS, encoding='utf-8') as fh:
        atp = json.load(fh)['atp_queryapp']
    schemas = atp.get('schemas', {})
    if schema not in schemas or 'password' not in (schemas.get(schema) or {}):
        sys.exit(f"No password for schema {schema!r} in {CONNECTIONS} "
                 f"(atp_queryapp.schemas). Set $DMT2_CONN instead, or add it.")
    w = atp['wallet_dir']
    return oracledb.connect(
        user=schema, password=schemas[schema]['password'], dsn=atp['dsn'],
        config_dir=w, wallet_location=w, wallet_password=atp['wallet_password'])


def header(schema):
    return (f"-- Deployed on queryapp ATP ({schema}). Snapshot of live DB object. "
            f"Do not hand-edit without deploying.\n")


def normalize(sql, otype):
    """Reduce a CREATE-OR-REPLACE object to a serialization-independent form so
    --check compares SOURCE, not formatting. The committed files are SQLcl/
    DBMS_METADATA exports (quoted identifiers, EDITIONABLE, an explicit column
    list) while all_views.text / all_source is a different serialization; a byte
    compare would always report drift. Strategy: drop comment lines, drop the
    CREATE framing, remove double-quotes, then for a VIEW keep only the SELECT
    body (the committed file adds a `(col, col, …)` clause after the name that
    the DB text omits — dropping it makes the two comparable). Finally fold
    case + whitespace and a trailing slash."""
    if sql is None:
        return None
    lines = [l for l in sql.splitlines()
             if not l.lstrip().startswith('--') or 'CREATE' in l.upper()]
    s = '\n'.join(lines).replace('"', '')
    s = re.sub(r'\bCREATE\s+OR\s+REPLACE\s+(?:EDITIONABLE\s+|NONEDITIONABLE\s+)?',
               ' ', s, flags=re.I)
    s = re.sub(r'/\s*$', ' ', s.strip())
    if otype == 'VIEW':
        # keep only the query: strip `VIEW name [(cols)] AS` prefix
        m = re.search(r'\bVIEW\b.*?\bAS\b', s, flags=re.I | re.S)
        if m:
            s = s[m.end():]
    s = re.sub(r'\s+', ' ', s).strip().upper()
    return re.sub(r';\s*$', '', s).strip()


def deployed_text(cur, name, otype, schema):
    hdr = header(schema)
    if otype == 'VIEW':
        cur.execute("SELECT text FROM all_views WHERE view_name=:1 AND owner=:2",
                    [name, schema])
        row = cur.fetchone()
        if not row:
            return None
        return f"{hdr}CREATE OR REPLACE VIEW {name} AS\n{row[0]}\n/\n"
    else:  # PROCEDURE / FUNCTION / PACKAGE etc.
        cur.execute("""SELECT text FROM all_source WHERE owner=:1 AND name=:2 AND type=:3
                       ORDER BY line""", [schema, name, otype])
        rows = cur.fetchall()
        if not rows:
            return None
        body = ''.join(r[0] for r in rows)
        return f"{hdr}CREATE OR REPLACE {body}\n/\n"


def main():
    ap = argparse.ArgumentParser(description='DMT DB <-> git sync guard')
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument('--check', action='store_const', dest='mode', const='--check',
                      help='(default) list tracked objects that differ from git; non-zero exit if any')
    mode.add_argument('--pull', action='store_const', dest='mode', const='--pull',
                      help='dump each tracked DB object to its git file')
    ap.add_argument('--schema', default=DEFAULT_SCHEMA,
                    help=f'target schema owner (default {DEFAULT_SCHEMA}; env DMT2_SCHEMA)')
    ap.set_defaults(mode='--check')
    args = ap.parse_args()
    mode, schema = args.mode, args.schema

    conn = connect(schema)
    cur = conn.cursor()
    drift, missing = [], []
    for name, (otype, rel) in MANIFEST.items():
        path = os.path.join(REPO, rel)
        db = deployed_text(cur, name, otype, schema)
        if db is None:
            missing.append(f"{name}: not found in {schema}")
            continue
        if mode == '--pull':
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                f.write(db)
            print(f"  pulled {name} -> {rel}")
        else:  # --check — compare SOURCE (normalized), not byte-serialization
            cur_file = open(path, encoding='utf-8').read() if os.path.exists(path) else None
            if normalize(cur_file, otype) != normalize(db, otype):
                drift.append(rel)
                print(f"  DRIFT  {name}  (DB != {rel})")
    cur.close(); conn.close()
    if missing:
        for m in missing:
            print("  WARN  " + m)
    if mode == '--check':
        if drift:
            print(f"\n{len(drift)} object(s) differ from git — run: "
                  f"python scripts/dmt_db_git_sync.py --pull --schema {schema}, then commit")
            sys.exit(1)
        print(f"OK — every tracked DB object matches its git file ({schema})")
    sys.exit(0)


if __name__ == '__main__':
    main()
