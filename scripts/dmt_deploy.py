#!/usr/bin/env python
"""
DMT git-first deploy tool — the ONLY sanctioned way to change the queryapp DB.

Why two tracks: objects differ in how they change.

  CODE  (stateless: PACKAGE spec+body, VIEW, PROCEDURE, FUNCTION, TRIGGER, TYPE)
        Redeployable with CREATE OR REPLACE, no data at risk.
        RULE: deploy ONLY from a committed git file. Never hand-type DDL.
          python dmt_deploy.py code <file.sql> [<file2.sql> ...]
        (packages: pass the .pks spec first, then the .pkb body)
        Each file is run as a SQL*Plus script, block by block: a PL/SQL unit
        ends at a "/" line, a plain SQL statement at ";" or "/", so a body file
        that carries a second block after its "/" runs both (backlog #758).

  TABLE (stateful: cannot CREATE OR REPLACE; changes are ALTERs)
        RULE: (1) the git create-table script must ALREADY reflect the change
              (git-first), (2) the change is applied via a migration file that is
              logged in DMT_MIGRATION_LOG so it runs exactly once.
          python dmt_deploy.py table --create schema/tables/dmt_x_tbl.sql \\
                                      --migration schema/migration/2026xx_add_col.sql

After any deploy: run `dmt_db_git_sync.py --pull` and COMMIT.

Shared-database deploy rule (owner decision 2026-10-08, backlog #641 / #740): both
tracks run through scripts/dmt_deploy_guard.py, the same guard ci_promote.py
deploy-local/deploy-prod and apex_deploy.py import use. Before deploying it waits
(bounded, DMT_DEPLOY_GUARD_TIMEOUT_S, default 45 min) while any DMT_WQ_ / DMT_PF_ /
DMT_PL_ / DMT_RC_ scheduler job is running and REFUSES on timeout (exit 3); right
after deploying it requires 0 invalid objects in the schema (exit 4, listing them).
"""
import sys, os, re, hashlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dmt_deploy_guard as guard  # noqa: E402 - shared with ci_promote.py / apex_deploy.py

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))


def connect():
    # DMT2 is Docker-only (CLAUDE.md: no ATP yet). Honor DMT2_CONN
    # (user/password@host:port/service) like dmt_regression_run.py; fall back
    # to the local Docker instance. The old connect_atp('queryapp') target is
    # the frozen stack's ATP and is wrong for DMT2.
    conn_str = os.environ.get('DMT2_CONN', 'dmt_owner/DmtLocal#2026@localhost:1523/FREEPDB1')
    m = re.match(r'^([^/]+)/(.+)@(?://)?(.+)$', conn_str)
    if not m:
        sys.exit(f"Cannot parse DMT2_CONN: {conn_str!r}")
    user, password, dsn = m.groups()
    import os as _os
    import oracledb
    _w = _os.environ.get('DMT2_WALLET')
    _kw = dict(config_dir=_w, wallet_location=_w, wallet_password=_os.environ.get('DMT2_WALLET_PW')) if _w else {}
    return oracledb.connect(user=user, password=password, dsn=dsn, **_kw)
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


# ---------------------------------------------------------------- script splitter
# Backlog #758: a code file is a SQL*Plus script, not one statement. A package
# body file may end its CREATE with a "/" line and then carry a second block (e.g.
# db/packages/dmt_ess_util_pkg.pkb.sql recompiles itself with PLSQL_CCFLAGS in a
# trailing anonymous block). Sending the whole file as one statement compiled the
# body with PLS-00103 and left it INVALID. split_script() splits the way SQL*Plus
# and SQLcl do:
#   * a PL/SQL unit (CREATE [OR REPLACE] [EDITIONABLE|NONEDITIONABLE] PACKAGE,
#     PACKAGE BODY, PROCEDURE, FUNCTION, TRIGGER, TYPE, TYPE BODY or LIBRARY, or an
#     anonymous DECLARE / BEGIN block) runs to a line holding only "/". Semicolons
#     inside it never end it, and it is sent with its final "END x;" intact;
#   * any other SQL statement (CREATE VIEW, ALTER ..., GRANT ...) ends at a line
#     ending in ";" (the ";" is dropped) or at a "/" line;
#   * between statements, blank lines, "--" comment lines, REM lines and the
#     SQL*Plus display/settings commands (SET, PROMPT, SHOW, WHENEVER, SPOOL,
#     DEFINE/UNDEFINE, COLUMN, TTITLE/BTITLE, CLEAR, EXIT/QUIT) are skipped;
#   * an "@" / "@@" / START include is refused (the included file would silently
#     not run; deploy each committed file directly);
#   * a PL/SQL unit still open at end of file is run anyway (some older files omit
#     the final "/"), so single-block files behave exactly as before.
# Chosen over shelling out to SQLcl: no Java/SQLcl install needed on the machine or
# in CI, the per-object compile-error check and the deploy guard stay in-process,
# and the splitter is unit-tested offline (test/unit/test_dmt_deploy_split.py).
_PLSQL_START_RE = re.compile(
    r'^\s*(?:CREATE\s+(?:OR\s+REPLACE\s+)?(?:(?:EDITIONABLE|NONEDITIONABLE)\s+)?'
    r'(?:PACKAGE|PROCEDURE|FUNCTION|TRIGGER|TYPE|LIBRARY)\b'
    r'|DECLARE\b|BEGIN\b)', re.I)
_SQLPLUS_CMD_RE = re.compile(
    r'^\s*(?:REM(?:ARK)?|SET|PROMPT|PRO|SHOW|SHO|WHENEVER|SPOOL|SPO|DEFINE|DEF|'
    r'UNDEFINE|UNDEF|COLUMN|COL|TTITLE|BTITLE|CLEAR|EXIT|QUIT)(?:\s|$)', re.I)
_INCLUDE_RE = re.compile(r'^\s*(?:@|START\s)', re.I)
_SLASH_RE = re.compile(r'^\s*/\s*$')


class ScriptError(ValueError):
    pass


def _strip_leading_comments(text):
    """text without its leading whitespace, '--' lines and /* */ comments. Used
    only to classify a statement, never to change what is sent."""
    t = text
    while True:
        t2 = t.lstrip()
        if t2.startswith('--'):
            nl = t2.find('\n')
            t2 = '' if nl < 0 else t2[nl + 1:]
        elif t2.startswith('/*'):
            end = t2.find('*/')
            t2 = '' if end < 0 else t2[end + 2:]
        if t2 == t:
            return t
        t = t2


def _sql_code(line):
    """The code part of one line: the text before a trailing '--' comment that
    sits outside a quoted literal."""
    in_q = False
    for i, ch in enumerate(line):
        if ch == "'":
            in_q = not in_q
        elif not in_q and line.startswith('--', i):
            return line[:i]
    return line


def _ends_sql(line):
    """True when a line of a plain SQL statement ends it: its code part ends with
    ';'. A comment line never ends a statement, even one that ends in ';' (a
    view's comments often do)."""
    return _sql_code(line).rstrip().endswith(';')


def split_script(text):
    """Split a SQL*Plus-style script into [(kind, statement)], kind 'plsql' or
    'sql', each statement ready for cursor.execute(). Raises ScriptError on an
    include, or on a non-PL/SQL statement left unterminated at end of file."""
    stmts = []
    buf = []            # lines of the current statement (leading comments included)
    kind = None         # 'plsql' | 'sql' once the statement's first code line is seen
    in_comment = False  # inside a /* */ comment that opened before any code

    def has_code(lines):
        return bool(_strip_leading_comments('\n'.join(lines)).strip())

    def flush():
        nonlocal buf, kind
        if has_code(buf):
            if kind == 'sql' and _ends_sql(buf[-1]):
                # drop the terminating ';' and any comment after it
                buf[-1] = _sql_code(buf[-1]).rstrip()[:-1]
            stmts.append((kind, '\n'.join(buf).strip()))
        buf, kind = [], None

    for lineno, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if in_comment:
            buf.append(line)
            if '*/' in line:
                in_comment = False
            continue
        if kind is None:
            # between statements: only comments (if anything) buffered so far
            if _SLASH_RE.match(line):
                buf = []       # "/" with no statement buffered: nothing to run
                continue
            if not stripped or stripped.startswith('--'):
                if buf:
                    buf.append(line)
                continue
            if _INCLUDE_RE.match(line):
                raise ScriptError(f"line {lineno}: script include '{stripped}' is not "
                                  f"supported -- deploy each committed file directly.")
            if _SQLPLUS_CMD_RE.match(line):
                continue
            code = _strip_leading_comments(line).strip()
            if not code:
                buf.append(line)            # a /* */ comment line before the code
                if line.count('/*') > line.count('*/'):
                    in_comment = True
                continue
            kind = 'plsql' if _PLSQL_START_RE.match(code) else 'sql'
            buf.append(line)
            if kind == 'sql' and _ends_sql(line):
                flush()
            continue
        # inside a statement
        if _SLASH_RE.match(line):
            flush()
            continue
        buf.append(line)
        if kind == 'sql' and _ends_sql(line):
            flush()
    if has_code(buf):
        if kind == 'plsql':
            flush()            # final PL/SQL unit without "/": run it (legacy files)
        else:
            raise ScriptError("statement at end of file is not terminated by ';' or '/': "
                              + _strip_leading_comments('\n'.join(buf)).strip()[:80])
    return stmts


_OBJ_RE = re.compile(r'CREATE\s+(?:OR\s+REPLACE\s+)?(?:EDITIONABLE\s+|NONEDITIONABLE\s+)?'
                     r'(?:FORCE\s+)?'
                     r'(PACKAGE\s+BODY|PACKAGE|VIEW|PROCEDURE|FUNCTION|TRIGGER|TYPE\s+BODY|TYPE)\s+'
                     r'(?:"?\w+"?\.)?"?(\w+)"?', re.I)


def created_object(stmt):
    """(object type, OBJECT_NAME) a CREATE statement makes, or None."""
    m = _OBJ_RE.match(_strip_leading_comments(stmt).strip())
    if not m:
        return None
    return re.sub(r'\s+', ' ', m.group(1).upper()), m.group(2).upper()


def _compile_errors(cur, oname):
    cur.execute("""SELECT type, line, position, text FROM user_errors
                   WHERE name=:1 ORDER BY type, sequence""", [oname])
    return cur.fetchall()


def _fail_with_errors(conn, label, errs):
    print(f"  DEPLOYED WITH ERRORS: {label}")
    for typ, ln, pos, txt in errs[:10]:
        print(f"    {typ} {ln}:{pos} {str(txt).strip()}")
    conn.rollback()
    sys.exit(1)


def deploy_code(paths, connect_fn=None):
    """Run every statement of each committed code file in order (split_script),
    then require 0 compile errors on every object the file created. The check runs
    after each CREATE and again after the whole file, because a later block may
    recompile an earlier object (backlog #758). connect_fn is injectable for the
    offline unit test (test/unit/test_dmt_deploy_split.py)."""
    import oracledb
    conn = (connect_fn or connect)(); cur = conn.cursor()
    for p in paths:
        path, raw = _read(p)
        if not CODE_RE.search(raw):
            sys.exit(f"REFUSED: {p} is not a CREATE OR REPLACE code object. "
                     f"Tables/ALTERs go through `table --migration`, not `code`.")
        if re.search(r'\bALTER\s+TABLE\b|\bCREATE\s+TABLE\b|\bDROP\s+TABLE\b', raw, re.I):
            sys.exit(f"REFUSED: {p} contains table DDL. Code deploys must not alter tables.")
        try:
            stmts = split_script(raw)
        except ScriptError as e:
            sys.exit(f"REFUSED: {p}: {e}")
        created = []
        for i, (kind, stmt) in enumerate(stmts, 1):
            try:
                cur.execute(stmt)
            except oracledb.DatabaseError as e:
                print(f"  FAILED: {p} statement {i} of {len(stmts)} ({kind}): {e}")
                conn.rollback(); sys.exit(1)
            obj = created_object(stmt)
            if obj:
                created.append(obj)
                errs = _compile_errors(cur, obj[1])
                if errs:
                    _fail_with_errors(conn, f"{obj[1]} ({p} statement {i} of {len(stmts)})", errs)
        for otype, oname in created:
            errs = _compile_errors(cur, oname)
            if errs:
                _fail_with_errors(conn, f"{oname} after the whole of {p} ran", errs)
            print(f"  deployed OK: {oname} ({otype})")
        extra = len(stmts) - len(created)
        if extra:
            print(f"  ran {extra} further block(s)/statement(s) in {os.path.basename(path)} OK")
    conn.commit(); cur.close(); conn.close()
    print("Reminder: run `python scripts/dmt_db_git_sync.py --pull` and commit.")


def deploy_table(create_path, migration_path):
    conn = connect(); cur = conn.cursor()
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


def run_guarded(label, deploy_fn, connect_fn=None, timeout_s=None):
    """Run deploy_fn under the shared-database deploy rule and return an exit code:
    3 when DMT child jobs are still running at the timeout (or the check failed)
    and nothing was deployed; deploy_fn's own failure code when it failed; 4 when
    it succeeded but invalid objects remain; 0 when deployed and clean. The
    invalid-object check runs even after a failed deploy, so they are listed.
    connect_fn is injectable for the offline unit test (test/unit/test_deploy_guard.py)."""
    connect_fn = connect_fn or connect
    if not guard.wait_until_no_dmt_jobs(connect_fn, label, timeout_s=timeout_s):
        print(f"[dmt_deploy] NOT deploying ({label}): DMT child jobs are running "
              f"(or the check failed).", file=sys.stderr)
        return 3
    rc = 0
    try:
        deploy_fn()
    except SystemExit as e:
        if isinstance(e.code, int):
            rc = e.code
        elif e.code is not None:
            print(e.code, file=sys.stderr)
            rc = 1
    clean = guard.assert_no_invalid(connect_fn, label)
    if rc == 0 and not clean:
        return 4
    return rc


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    if sys.argv[1] == 'code':
        if len(sys.argv) < 3:
            sys.exit("usage: dmt_deploy.py code <file.sql> [...]")
        paths = sys.argv[2:]
        sys.exit(run_guarded("code", lambda: deploy_code(paths)))
    elif sys.argv[1] == 'table':
        args = sys.argv[2:]
        create = args[args.index('--create') + 1] if '--create' in args else None
        mig = args[args.index('--migration') + 1] if '--migration' in args else None
        if not create or not mig:
            sys.exit("usage: dmt_deploy.py table --create <create_tbl.sql> --migration <migration.sql>")
        sys.exit(run_guarded("table", lambda: deploy_table(create, mig)))
    else:
        sys.exit(f"unknown track '{sys.argv[1]}'. Use: code | table")


if __name__ == '__main__':
    main()
