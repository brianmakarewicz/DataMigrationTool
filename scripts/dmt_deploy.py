#!/usr/bin/env python
"""
DMT git-first deploy tool — the ONLY sanctioned way to change the queryapp DB.

Why two tracks: objects differ in how they change.

  CODE  (stateless: PACKAGE spec+body, VIEW, PROCEDURE, FUNCTION, TRIGGER, TYPE)
        Redeployable with CREATE OR REPLACE, no data at risk.
        RULE: deploy ONLY from a committed git file. Never hand-type DDL.
          python dmt_deploy.py code <file.sql> [<file2.sql> ...]
        (packages: pass the .pks spec first, then the .pkb body)

  TABLE (stateful: cannot CREATE OR REPLACE; changes are ALTERs)
        RULE: (1) the git create-table script must ALREADY reflect the change
              (git-first), (2) the change is applied via a migration file that is
              logged in DMT_MIGRATION_LOG so it runs exactly once.
          python dmt_deploy.py table --create schema/tables/dmt_x_tbl.sql \\
                                      --migration schema/migration/2026xx_add_col.sql

After any deploy: run `dmt_db_git_sync.py --pull` and COMMIT.
"""
import sys, os, re, hashlib
sys.path.insert(0, r'C:\Users\Monroe\workspace')
from conn_helper import connect_atp

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
CODE_RE = re.compile(r'^\s*CREATE\s+OR\s+REPLACE\s+'
                     r'(EDITIONABLE\s+|NONEDITIONABLE\s+)?'
                     r'(PACKAGE\s+BODY|PACKAGE|VIEW|PROCEDURE|FUNCTION|TRIGGER|TYPE\s+BODY|TYPE)\b',
                     re.I | re.M)


def _read(path):
    if not os.path.isabs(path):
        path = os.path.join(REPO, path)
    if not os.path.commonpath([os.path.abspath(path), REPO]) == REPO:
        sys.exit(f"REFUSED: {path} is outside the repo — deploy only from committed files.")
    if not os.path.exists(path):
        sys.exit(f"REFUSED: {path} does not exist. Create + commit the file first (git-first).")
    return path, open(path, encoding='utf-8').read()


def _strip(ddl):
    ddl = ddl.strip()
    return ddl[:-1].strip() if ddl.endswith('/') else ddl


def deploy_code(paths):
    conn = connect_atp('queryapp', 'DMT_OWNER'); cur = conn.cursor()
    for p in paths:
        path, raw = _read(p)
        # drop a leading snapshot comment line, then require CREATE OR REPLACE <object>
        body = '\n'.join(l for l in raw.splitlines() if not l.lstrip().startswith('--') or 'CREATE' in l.upper())
        if not CODE_RE.search(raw):
            sys.exit(f"REFUSED: {p} is not a CREATE OR REPLACE code object. "
                     f"Tables/ALTERs go through `table --migration`, not `code`.")
        if re.search(r'\bALTER\s+TABLE\b|\bCREATE\s+TABLE\b|\bDROP\s+TABLE\b', raw, re.I):
            sys.exit(f"REFUSED: {p} contains table DDL. Code deploys must not alter tables.")
        cur.execute(_strip(raw))
        # report compile errors
        m = re.search(r'CREATE\s+OR\s+REPLACE\s+(?:EDITIONABLE\s+|NONEDITIONABLE\s+)?'
                      r'(PACKAGE\s+BODY|PACKAGE|VIEW|PROCEDURE|FUNCTION|TRIGGER|TYPE\s+BODY|TYPE)\s+'
                      r'(?:DMT_OWNER\.)?"?(\w+)"?', raw, re.I)
        if m:
            otype, oname = m.group(1).upper().replace(' ', ' '), m.group(2).upper()
            cur.execute("""SELECT line, position, text FROM user_errors
                           WHERE name=:1 ORDER BY sequence""", [oname])
            errs = cur.fetchall()
            if errs:
                print(f"  DEPLOYED WITH ERRORS: {oname}")
                for ln, pos, txt in errs[:10]:
                    print(f"    {ln}:{pos} {txt.strip()}")
                conn.rollback(); sys.exit(1)
            print(f"  deployed OK: {oname} ({otype})")
    conn.commit(); cur.close(); conn.close()
    print("Reminder: run `python scripts/dmt_db_git_sync.py --pull` and commit.")


def deploy_table(create_path, migration_path):
    conn = connect_atp('queryapp', 'DMT_OWNER'); cur = conn.cursor()
    # ensure migration log exists
    cur.execute("""SELECT COUNT(*) FROM user_tables WHERE table_name='DMT_MIGRATION_LOG'""")
    if cur.fetchone()[0] == 0:
        sys.exit("REFUSED: DMT_MIGRATION_LOG missing. Deploy schema/tables/dmt_migration_log_tbl.sql "
                 "first via: python dmt_deploy.py table --create <that file> --migration <that file>")
    create_abs, create_sql = _read(create_path)
    mig_abs, mig_sql = _read(migration_path)
    mig_name = os.path.basename(mig_abs)

    # already applied?
    cur.execute("SELECT COUNT(*) FROM DMT_MIGRATION_LOG WHERE migration_name=:1", [mig_name])
    if cur.fetchone()[0] > 0:
        print(f"  SKIP: {mig_name} already applied."); return

    # git-first check: for an ADD (col ...), the create script must already mention the column
    for col in re.findall(r'ADD\s*\(?\s*"?(\w+)"?\s+\w', mig_sql, re.I):
        if not re.search(r'\b' + re.escape(col) + r'\b', create_sql, re.I):
            sys.exit(f"REFUSED (git-first): migration adds column {col} but the create-table script "
                     f"{create_path} does not mention it. Update + commit the create script first.")

    for stmt in [s for s in re.split(r';\s*\n|/\s*\n', mig_sql) if s.strip() and not s.strip().startswith('--')]:
        cur.execute(_strip(stmt))
    cur.execute("""INSERT INTO DMT_MIGRATION_LOG(migration_name, checksum, applied_by)
                   VALUES(:1,:2,USER)""", [mig_name, hashlib.sha1(mig_sql.encode()).hexdigest()[:16]])
    conn.commit(); cur.close(); conn.close()
    print(f"  applied migration: {mig_name}")
    print("Reminder: run `python scripts/dmt_db_git_sync.py --pull` and commit both the migration and create script.")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    if sys.argv[1] == 'code':
        if len(sys.argv) < 3:
            sys.exit("usage: dmt_deploy.py code <file.sql> [...]")
        deploy_code(sys.argv[2:])
    elif sys.argv[1] == 'table':
        args = sys.argv[2:]
        create = args[args.index('--create') + 1] if '--create' in args else None
        mig = args[args.index('--migration') + 1] if '--migration' in args else None
        if not create or not mig:
            sys.exit("usage: dmt_deploy.py table --create <create_tbl.sql> --migration <migration.sql>")
        deploy_table(create, mig)
    else:
        sys.exit(f"unknown track '{sys.argv[1]}'. Use: code | table")


if __name__ == '__main__':
    main()
