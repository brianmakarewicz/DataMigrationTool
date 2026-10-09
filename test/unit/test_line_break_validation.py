#!/usr/bin/env python
"""
test_line_break_validation.py -- unit test for backlog #651 (values with line
breaks never reach an FBDI CSV). SELECT-only: it writes nothing, so it can run
against the shared local database at any time.

  1. DMT_UTIL_PKG.LINE_BREAK_ERROR on built JSON rows: CR, LF and CRLF are each
     caught and the field is named; several fields are all named in column
     order; clean rows, numbers, nulls and ERROR_TEXT (not a CSV field) are not
     flagged; the message carries the [POST_VALIDATION] tag.
  2. The same call over JSON_OBJECT(t.* RETURNING CLOB) of every row of every
     TFM table a validator checks (the exact expression the validators use)
     runs without error and flags nothing in the existing regression data, so
     the check cannot change the outcome of an existing scenario.

Usage:  python test/unit/test_line_break_validation.py
Env:    DMT2_DSN / DMT2_USER / DMT2_PWD (default: the local Docker instance)
Exit 0 = all pass, 1 = a failure.
"""
import os
import re
import sys

import oracledb

DSN = os.environ.get('DMT2_DSN', 'localhost:1523/FREEPDB1')
USER = os.environ.get('DMT2_USER', 'dmt_owner')
PWD = os.environ.get('DMT2_PWD', 'DmtLocal#2026')
REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))

fails = 0


def check(name, ok, detail=''):
    global fails
    print(('PASS ' if ok else 'FAIL ') + name + ('' if ok else f'  -- {detail}'))
    if not ok:
        fails += 1


def lb(cur, json_expr):
    cur.execute(f"SELECT DMT_UTIL_PKG.LINE_BREAK_ERROR({json_expr}) FROM dual")
    return cur.fetchone()[0]


def main():
    con = oracledb.connect(user=USER, password=PWD, dsn=DSN)
    con.call_timeout = 300000
    cur = con.cursor()

    # 1. Function behaviour on built rows.
    r = lb(cur, "JSON_OBJECT('VENDOR_NAME' VALUE 'Acme', 'ALIAS' VALUE 'a' || CHR(10) || 'b' RETURNING CLOB)")
    check('LF is caught and the field named',
          r is not None and r.startswith('[POST_VALIDATION] Field ALIAS contains a line break'), r)
    r = lb(cur, "JSON_OBJECT('DESCRIPTION' VALUE 'a' || CHR(13) || 'b' RETURNING CLOB)")
    check('CR is caught', r is not None and 'Field DESCRIPTION ' in r, r)
    r = lb(cur, "JSON_OBJECT('DESCRIPTION' VALUE 'a' || CHR(13) || CHR(10) || 'b' RETURNING CLOB)")
    check('CRLF is caught once', r is not None and r.count('DESCRIPTION') == 1, r)
    r = lb(cur, "JSON_OBJECT('A1' VALUE 'x' || CHR(10), 'B2' VALUE 'ok', 'C3' VALUE CHR(13) || 'y' RETURNING CLOB)")
    check('several fields are all named, in column order',
          r is not None and 'Fields A1, C3 contain line breaks' in r and 'B2' not in r, r)
    r = lb(cur, "JSON_OBJECT('A1' VALUE 'plain', 'N1' VALUE 42, 'D1' VALUE NULL RETURNING CLOB)")
    check('clean row, number and null are not flagged', r is None, r)
    r = lb(cur, "JSON_OBJECT('A1' VALUE 'plain', 'ERROR_TEXT' VALUE 'e1' || CHR(10) || 'e2' RETURNING CLOB)")
    check('ERROR_TEXT is not a CSV field and is skipped', r is None, r)
    r = lb(cur, "JSON_OBJECT('A1' VALUE 'tab' || CHR(9) || 'only' RETURNING CLOB)")
    check('a tab is not a line break', r is None, r)
    r = lb(cur, "CAST(NULL AS CLOB)")
    check('NULL row returns NULL', r is None, r)
    r = lb(cur, "JSON_OBJECT('ALIAS' VALUE 'a' || CHR(10) RETURNING CLOB)")
    check('message says the row is not sent and how to fix it',
          r is not None and 'remove them from the source value' in r and 'Row not sent to Fusion' in r, r)

    # 2. The validators' exact expression over every checked TFM table.
    src = open(os.path.join(REPO, 'scripts', 'check_line_break_validation.py'), encoding='utf-8').read()
    tables = set()
    for v in sorted(set(re.findall(r"\('(\w+)', 'VALIDATE_\w*LINE_BREAKS'", src))):
        body = open(os.path.join(REPO, 'db', 'packages', f'dmt_{v}_validator_pkg.pkb.sql'),
                    encoding='utf-8').read()
        tables.update(re.findall(r'(?m)^\s*UPDATE (DMT_\w+_TFM_TBL) t\s*$', body))
    check('validators check 55 TFM tables', len(tables) == 55, f'{len(tables)} tables')
    flagged, scanned = 0, 0
    for t in sorted(tables):
        cur.execute(f"SELECT COUNT(*), COUNT(DMT_UTIL_PKG.LINE_BREAK_ERROR(JSON_OBJECT(t.* RETURNING CLOB))) "
                    f"FROM {t} t")
        n, f = cur.fetchone()
        scanned += n
        flagged += f
        if f:
            print(f'      {t}: {f} existing row(s) hold a line break')
    check(f'existing TFM data ({scanned} rows in {len(tables)} tables) has no line breaks',
          flagged == 0, f'{flagged} flagged')

    con.close()
    print(f'{"ALL PASS" if not fails else str(fails) + " FAILURE(S)"}')
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
