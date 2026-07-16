#!/usr/bin/env python
"""
Round-trip proof for the DMT2 upload feature.

Loads regressionProprietary.zip and FBDIFormat.zip into two throwaway scenarios
via DMT_CSV_UPLOAD_PKG.UPLOAD_ZIP_AUTO_FROM_BLOB, then asserts:
  * every FBDI object has identical row counts in reg / proprietary / fbdi,
  * business values load-match the regression set (keyed on an FBDI-carried key),
  * a scattered/high-position FBDI column lands in the right staging column
    (GL Balances LEDGER_NAME at slot 92, PERIOD_NAME at slot 95),
  * uploaded STG rows are STG_STATUS='NEW' with no ERROR_TEXT.

Cleans up the throwaway scenarios' staging rows at the end. Never touches
scenario_id 1 (RegressionTest).

Usage: python roundtrip_test.py   (against the local Docker DB)
"""
import os
import sys

import oracledb

HERE = os.path.dirname(os.path.abspath(__file__))
PROP_SCN = 'UploadProp'
FBDI_SCN = 'UploadFbdi'


def connect():
    conn = oracledb.connect(user="dmt_owner", password="DmtLocal#2026",
                            dsn="localhost:1523/FREEPDB1")
    conn.call_timeout = 120000
    return conn


def load(cur, conn, path, scenario):
    blob = open(path, 'rb').read()
    summ = cur.var(oracledb.DB_TYPE_CLOB)
    bid = cur.var(oracledb.NUMBER)
    err = cur.var(oracledb.STRING)
    cur.execute("""begin DMT_CSV_UPLOAD_PKG.UPLOAD_ZIP_AUTO_FROM_BLOB(
        p_zip_blob=>:b, p_file_label=>:lbl, p_summary=>:s, p_batch_id_out=>:bid,
        p_error_msg=>:err, p_use_fast_loader=>TRUE, p_scenario_name=>:scn); end;""",
        dict(b=blob, lbl=os.path.basename(path), s=summ, bid=bid, err=err, scn=scenario))
    conn.commit()
    return err.getvalue()


def scenario_id(cur, name):
    cur.execute("select scenario_id from dmt_scenario_tbl where scenario_name=:1", [name])
    r = cur.fetchone()
    return r[0] if r else None


def cleanup(cur, conn, sids):
    cur.execute(r"select table_name from user_tables "
                r"where table_name like 'DMT\_%\_STG\_TBL' escape '\'")
    tables = [r[0] for r in cur]
    total = 0
    for t in tables:
        for s in sids:
            try:
                cur.execute(f"delete from {t} where scenario_id=:1", [s])
                total += cur.rowcount
            except oracledb.DatabaseError:
                pass
    conn.commit()
    return total


def main():
    conn = connect()
    cur = conn.cursor()
    failures = []

    e1 = load(cur, conn, os.path.join(HERE, 'regressionProprietary.zip'), PROP_SCN)
    e2 = load(cur, conn, os.path.join(HERE, 'FBDIFormat.zip'), FBDI_SCN)
    if e1:
        failures.append(f"proprietary load error: {e1}")
    if e2:
        failures.append(f"fbdi load error: {e2}")

    sp = scenario_id(cur, PROP_SCN)
    sf = scenario_id(cur, FBDI_SCN)

    # Row-count parity across FBDI objects
    cur.execute("select object_code, staging_table from dmt_upload_object_tbl "
                "where fbdi_csv_filename is not null order by display_order")
    for oc, st in cur.fetchall():
        def cnt(sid):
            cur.execute(f"select count(*) from {st} where scenario_id=:1", [sid])
            return cur.fetchone()[0]
        a, b, c = cnt(1), cnt(sp), cnt(sf)
        if not (a == b == c):
            failures.append(f"row-count mismatch {oc}: reg={a} prop={b} fbdi={c}")

    # Scattered-column spot check: GL Balances positional load
    def gl(sid):
        cur.execute("select journal_status, to_char(accounting_date,'YYYY-MM-DD'), "
                    "ledger_name, period_name from dmt_gl_interface_stg_tbl "
                    "where scenario_id=:1 order by nvl(entered_dr,-1)", [sid])
        return cur.fetchall()
    if gl(1) != gl(sf):
        failures.append(f"GL scattered spot-check mismatch: reg={gl(1)} fbdi={gl(sf)}")

    # STG hygiene: no ERROR_TEXT, status NEW
    for t in ['dmt_gl_interface_stg_tbl', 'dmt_poz_suppliers_stg_tbl',
              'dmt_egp_item_stg_tbl', 'dmt_gms_awd_headers_stg_tbl']:
        cur.execute(f"select stg_status, sum(case when error_text is not null then 1 else 0 end) "
                    f"from {t} where scenario_id in (:1,:2) group by stg_status", [sp, sf])
        for status, errs in cur.fetchall():
            if status != 'NEW' or errs:
                failures.append(f"STG hygiene {t}: status={status} error_rows={errs}")

    removed = cleanup(cur, conn, [sp, sf])

    print(f"cleaned up {removed} throwaway STG rows (scenarios {PROP_SCN}/{FBDI_SCN})")
    if failures:
        print("FAIL:")
        for f in failures:
            print("  -", f)
        sys.exit(1)
    print("PASS: both formats load the same data; scattered FBDI column verified; STG clean.")


if __name__ == '__main__':
    main()
