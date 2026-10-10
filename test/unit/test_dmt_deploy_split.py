#!/usr/bin/env python3
"""
test_dmt_deploy_split.py - offline proof that scripts/dmt_deploy.py runs a code file
statement by statement, the way SQL*Plus / SQLcl do (backlog #758).

The defect: `dmt_deploy.py code` sent a whole file to the database as ONE statement.
db/packages/dmt_ess_util_pkg.pkb.sql ends its package body with "/" and then carries
a second anonymous block, so the body compiled with PLS-00103 and was left INVALID.

What it proves, with no database (a fake connection records every statement):
  * split_script on the two-block fixture test/unit/fixtures/multi_block_pkg.pkb.sql
    returns exactly two PL/SQL blocks; the body keeps its "END x;" and contains no
    "/" line and none of the second block; semicolons in comments, literals and
    trailing comments never end a PL/SQL block;
  * the real dmt_ess_util_pkg.pkb.sql splits into the body plus the recompile block;
  * plain SQL: a view ending in ";" is sent without the ";", a comment line ending in
    ";" inside the view does not cut it, a "/" also ends a statement, SQL*Plus
    settings lines (SET, PROMPT, SHOW ERRORS) are skipped;
  * a "DECLARE ... /" block followed by CREATE TYPE statements (db/types files)
    splits into three PL/SQL statements;
  * an "@" include is refused, and an unterminated plain SQL statement at end of
    file is refused; an unterminated final PL/SQL unit still runs (legacy files);
  * every committed db/packages, db/views, db/procedures and db/types file splits
    without error, and no plain SQL statement keeps a trailing ";";
  * deploy_code on the fixture executes TWO statements in order (not one), checks
    compile errors after the CREATE and again after the whole file (a later block
    can recompile the object), and exits 1 naming the object when that final check
    finds errors.

    python test/unit/test_dmt_deploy_split.py

Exit 0 when every case passes, 1 otherwise.
"""
import glob
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import dmt_deploy as dd  # noqa: E402

FIXTURE = REPO / "test" / "unit" / "fixtures" / "multi_block_pkg.pkb.sql"
passed = 0
failed = 0


def check(cond, name):
    global passed, failed
    if cond:
        passed += 1
        print(f"PASS  {name}")
    else:
        failed += 1
        print(f"FAIL  {name}")


def raises(fn, exc):
    try:
        fn()
    except exc:
        return True
    return False


# 1. The two-block fixture.
stmts = dd.split_script(FIXTURE.read_text(encoding="utf-8"))
check(len(stmts) == 2 and all(k == "plsql" for k, _ in stmts),
      "fixture: two PL/SQL blocks, not one statement")
body, block = stmts[0][1], stmts[1][1]
check(body.rstrip().endswith("END DMT_SPLIT_FIXTURE_PKG;"),
      "fixture: package body keeps its final 'END x;'")
check(not any(ln.strip() == "/" for ln in body.splitlines()) and "declare" not in body,
      "fixture: package body holds no '/' line and none of the second block")
check("RETURN 'a;b';" in body and "ends in a semicolon;" in body,
      "fixture: ';' in a comment, a literal and a trailing comment did not end the body")
check(block.lower().startswith("declare") and block.rstrip().endswith("end;"),
      "fixture: second block is the whole anonymous block, ending 'end;'")
check(dd.created_object(body) == ("PACKAGE BODY", "DMT_SPLIT_FIXTURE_PKG")
      and dd.created_object(block) is None,
      "fixture: the body is recognised as the object created; the block is not")

# 2. The real file that exposed the defect.
real = dd.split_script((REPO / "db" / "packages" / "dmt_ess_util_pkg.pkb.sql")
                       .read_text(encoding="utf-8"))
check(len(real) == 2 and dd.created_object(real[0][1]) == ("PACKAGE BODY", "DMT_ESS_UTIL_PKG")
      and "COMPILE BODY" in real[1][1] and "COMPILE BODY" not in real[0][1],
      "dmt_ess_util_pkg.pkb.sql: body and the conditional-recompile block run separately")

# 3. Plain SQL, SQL*Plus commands, terminators.
view = ("SET DEFINE OFF\nPROMPT creating view\n"
        "CREATE OR REPLACE VIEW V1 AS\n  SELECT 1 AS A\n  -- a comment ending in ;\n"
        "  FROM dual;  -- trailing comment; with a semicolon\n"
        "SHOW ERRORS\n"
        "GRANT SELECT ON V1 TO PUBLIC\n/\n")
vs = dd.split_script(view)
check([k for k, _ in vs] == ["sql", "sql"], "view script: two SQL statements, commands skipped")
check(vs[0][1].endswith("FROM dual") and "-- a comment ending in ;" in vs[0][1],
      "view: ';' and trailing comment dropped; an inner comment ending in ';' did not cut it")
check(vs[1][1] == "GRANT SELECT ON V1 TO PUBLIC", "a '/' line also ends a plain SQL statement")

types = ("DECLARE\n  x NUMBER;\nBEGIN\n  NULL;\nEND;\n/\n\n"
         "CREATE OR REPLACE TYPE T_OBJ AS OBJECT (a NUMBER);\n/\n"
         "CREATE OR REPLACE TYPE T_TAB AS TABLE OF T_OBJ;\n/\n")
ts = dd.split_script(types)
check([k for k, _ in ts] == ["plsql"] * 3
      and [dd.created_object(t) for _, t in ts] == [None, ("TYPE", "T_OBJ"), ("TYPE", "T_TAB")],
      "types script: DECLARE block then two CREATE TYPE statements")

check(raises(lambda: dd.split_script("@other_file.sql\n"), dd.ScriptError),
      "an '@' include is refused")
check(raises(lambda: dd.split_script("CREATE OR REPLACE VIEW V2 AS SELECT 1 A FROM dual\n"),
             dd.ScriptError),
      "an unterminated plain SQL statement at end of file is refused")
legacy = dd.split_script("CREATE OR REPLACE PROCEDURE P IS BEGIN NULL; END;\n")
check(len(legacy) == 1 and legacy[0][1].endswith("END;"),
      "an unterminated final PL/SQL unit still runs (legacy single-block files)")

# 4. Every committed code file splits cleanly.
problems = []
for f in sorted(glob.glob(str(REPO / "db" / "packages" / "*.sql"))
                + glob.glob(str(REPO / "db" / "views" / "*.sql"))
                + glob.glob(str(REPO / "db" / "procedures" / "*.sql"))
                + glob.glob(str(REPO / "db" / "types" / "*.sql"))):
    try:
        for k, t in dd.split_script(Path(f).read_text(encoding="utf-8")):
            if k == "sql" and t.rstrip().endswith(";"):
                problems.append(f"{os.path.basename(f)}: SQL keeps ';'")
    except dd.ScriptError as e:
        problems.append(f"{os.path.basename(f)}: {e}")
check(not problems, "every committed code file splits cleanly" + (f" ({problems[:3]})" if problems else ""))


# 5. deploy_code against a fake connection.
class FakeDB:
    def __init__(self, errors_after=None):
        self.executed = []      # statements run (user_errors queries excluded)
        self.err_checks = 0
        self.errors_after = errors_after  # return errors on this user_errors check (1-based)

    def connect(self):
        db = self

        class Cur:
            rows = []

            def execute(self, sql, binds=None):
                if "user_errors" in sql:
                    db.err_checks += 1
                    self.rows = ([("PACKAGE BODY", 1, 1, "PLS-00103: Encountered the symbol")]
                                 if db.err_checks == db.errors_after else [])
                else:
                    db.executed.append(sql)

            def fetchall(self):
                return self.rows

            def close(self):
                pass

        class Con:
            def cursor(self):
                return Cur()

            def commit(self):
                pass

            def rollback(self):
                pass

            def close(self):
                pass
        return Con()


db = FakeDB()
rc = 0
try:
    dd.deploy_code([str(FIXTURE)], connect_fn=db.connect)
except SystemExit as e:
    rc = e.code
check(rc == 0 and len(db.executed) == 2, "deploy_code: the fixture runs as two statements")
check(db.executed[0].rstrip().endswith("END DMT_SPLIT_FIXTURE_PKG;")
      and db.executed[1].lower().startswith("declare"),
      "deploy_code: body first, then the recompile block")
check(db.err_checks == 2, "deploy_code: compile errors checked after the CREATE and after the file")

db2 = FakeDB(errors_after=2)   # clean after the CREATE, broken after the recompile block
rc2 = 0
try:
    dd.deploy_code([str(FIXTURE)], connect_fn=db2.connect)
except SystemExit as e:
    rc2 = e.code
check(rc2 == 1 and len(db2.executed) == 2,
      "deploy_code: errors left by a later block fail the deploy (exit 1)")

print(f"\n{passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
