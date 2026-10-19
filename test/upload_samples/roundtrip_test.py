#!/usr/bin/env python
"""
Round-trip proof for the DMT2 upload feature (both formats), against the local Docker DB.

Leg 1 -- the rebuilt test zips. Loads regressionProprietary.zip and FBDIFormat.zip
(build_regression_zips.py, built from the current regression baseline scenario in
scripts/regression_scenario.json) into two NEW scenarios via
DMT_CSV_UPLOAD_PKG.UPLOAD_ZIP_AUTO_FROM_BLOB, then asserts:
  * every staging object fed by an FBDI file has the same row count in the baseline,
    the proprietary scenario and the FBDI scenario;
  * for every registered FBDI file (DMT_UPLOAD_FBDI_FILE_TBL), the staged values of
    every column it maps (DMT_UPLOAD_FBDI_POS_TBL) equal the baseline's, row for row
    (compared as sorted multisets over the file's rows: its row_filter, and one row
    per distinct header where the file repeats it);
  * the scattered GL Balances columns (LEDGER_NAME slot 92, PERIOD_NAME slot 95) land;
  * uploaded STG rows are STG_STATUS='NEW' with no ERROR_TEXT.

Leg 2 -- real generated files (backlog #792). Zips the latest non-empty CSV the
pipeline's FBDI generators actually wrote (DMT_FBDI_CSV_TBL) for every file newly
registered by #792, uploads it into a third NEW scenario, and asserts that for every
(file, staging object) pair the staged rows equal the TFM rows that file carried
(TFM FBDI_CSV_ID = the file), on every mapped column. This proves the slot numbers
against the generators themselves, not against our own map. Dates are compared as
dates (several generators write the date part only).

Staging rows are never deleted (design section 3): each run uses fresh, timestamped
scenarios and leaves them in place. Never touches the regression baseline.

Usage: python roundtrip_test.py   (against the local Docker DB)
"""
import csv
import datetime
import decimal
import io
import json
import os
import re
import sys
import zipfile

import oracledb

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from fbdi_column_maps import FILES  # noqa: E402

STAMP = datetime.datetime.now().strftime('%y%m%d%H%M%S')
PROP_SCN = f'UploadProp-{STAMP}'
FBDI_SCN = f'UploadFbdi-{STAMP}'
GEN_SCN = f'UploadGen-{STAMP}'

# Files newly registered by backlog #792 (leg 2 uploads their real generated CSVs).
NEW_FILES = [
    'RaInterfaceDistributionsAll.csv', 'FaMassAdditions.csv', 'FaMassaddDistributions.csv',
    'InvTransactionsInterface.csv', 'InvTransactionLotsInterface.csv', 'InvSerialNumbersInterface.csv',
    'PoHeadersInterfaceBlanket.csv', 'PoLinesInterfaceBlanket.csv', 'PoHeadersInterfaceContract.csv',
    'GmsAwardFundingInterface.csv', 'GmsAwardProjectsInterface.csv', 'GmsAwardFundSrcInterface.csv',
    'GmsAwardPrjFundSrcInterface.csv', 'GmsAwardKeywordsInterface.csv', 'GmsAwardBdgtPeriodsInterface.csv',
    'GmsAwardCertsInterface.csv', 'GmsAwardCfdasInterface.csv', 'GmsAwardFundAllocInterface.csv',
    'GmsAwardOrgCreditsInterface.csv', 'GmsAwardPrjTaskBrdInterface.csv', 'GmsAwardReferencesInterface.csv',
    'GmsAwardTermsInterface.csv',
]
# Columns a generator writes from ANOTHER row than the TFM row it carries (leg 2 compares
# them against that other row's value only through the file, not the TFM row):
#   lots slot 1 / slot 4 = the parent transaction's INV_LOTSERIAL_INTERFACE_NUM and
#   SOURCE_LINE_ID (backlog #137 / #218), not the lot TFM row's own staged values.
DERIVED = {('InvTransactionLotsInterface.csv', 'INV_TRX_LOTS'):
           {'INVENTORY_LOT_INTERFACE_NUMBER', 'SOURCE_LINE_ID'}}


def connect():
    conn = oracledb.connect(user="dmt_owner", password="DmtLocal#2026",
                            dsn="localhost:1523/FREEPDB1")
    conn.call_timeout = 300000
    return conn


def load(cur, conn, blob, label, scenario):
    summ = cur.var(oracledb.DB_TYPE_CLOB)
    bid = cur.var(oracledb.NUMBER)
    err = cur.var(oracledb.STRING)
    cur.execute("""begin DMT_CSV_UPLOAD_PKG.UPLOAD_ZIP_AUTO_FROM_BLOB(
        p_zip_blob=>:b, p_file_label=>:lbl, p_summary=>:s, p_batch_id_out=>:bid,
        p_error_msg=>:err, p_use_fast_loader=>TRUE, p_scenario_name=>:scn); end;""",
                dict(b=blob, lbl=label, s=summ, bid=bid, err=err, scn=scenario))
    conn.commit()
    s = summ.getvalue()
    return err.getvalue(), (s.read() if hasattr(s, 'read') else s) or ''


def scenario_id(cur, name):
    cur.execute("select scenario_id from dmt_scenario_tbl where scenario_name=:1", [name])
    r = cur.fetchone()
    return r[0] if r else None


def norm(v, date_only=False):
    if v is None:
        return ''
    if isinstance(v, datetime.datetime):
        v = v.replace(microsecond=0)
        return v.strftime('%Y-%m-%d') if date_only else v.isoformat(' ')
    if isinstance(v, datetime.date):
        return v.isoformat()
    if isinstance(v, (int, float, decimal.Decimal)):
        d = decimal.Decimal(str(v)).normalize()
        return format(d, 'f')
    return str(v)


def file_registry(cur):
    cur.execute("""select f.fbdi_file_id, f.fbdi_csv_filename, f.object_code, o.staging_table,
                          f.distinct_rows_flag
                   from dmt_upload_fbdi_file_tbl f
                   join dmt_upload_object_tbl o on o.object_code = f.object_code
                   order by f.fbdi_csv_filename, f.load_order""")
    reg = cur.fetchall()
    cur.execute("select fbdi_file_id, column_name from dmt_upload_fbdi_pos_tbl order by fbdi_file_id, fbdi_position")
    cols = {}
    for fid, c in cur.fetchall():
        cols.setdefault(fid, []).append(c)
    return reg, cols


def rows(cur, table, cols, where, binds, distinct=False, date_only=False):
    sql = (f"select {'distinct ' if distinct else ''}{', '.join(cols)} from {table} where {where}")
    cur.execute(sql, binds)
    return sorted(tuple(norm(v, date_only) for v in r) for r in cur.fetchall())


def leg1(cur, conn, failures):
    print("== Leg 1: rebuilt FBDIFormat.zip / regressionProprietary.zip from the baseline")
    base_name = json.load(open(os.path.join(HERE, '..', '..', 'scripts', 'regression_scenario.json'),
                               encoding='utf-8'))['current_scenario']
    base = scenario_id(cur, base_name)
    for path, scn in (('regressionProprietary.zip', PROP_SCN), ('FBDIFormat.zip', FBDI_SCN)):
        err, summ = load(cur, conn, open(os.path.join(HERE, path), 'rb').read(), path, scn)
        print(f"   {path} -> {scn}: " + (summ.strip().splitlines()[-1] if summ.strip() else ''))
        if err:
            failures.append(f"{path} load error: {err}")
        for line in summ.splitlines():
            m = re.search(r'(\d+) errors', line)
            if 'SKIPPED' in line or (m and m.group(1) != '0'):
                failures.append(f"{path}: {line.strip()}")
    sp, sf = scenario_id(cur, PROP_SCN), scenario_id(cur, FBDI_SCN)
    reg, poscols = file_registry(cur)
    filt = {(x.file, x.object): x.row_filter for x in FILES}

    print(f"   row counts (baseline {base_name} / proprietary / FBDI):")
    for oc, st in sorted({(r[2], r[3]) for r in reg}):
        c = []
        for sid in (base, sp, sf):
            cur.execute(f"select count(*) from {st} where scenario_id=:1", [sid])
            c.append(cur.fetchone()[0])
        ok = c[0] == c[1] == c[2]
        print(f"     {'PASS' if ok else 'FAIL'}  {oc:22} {c[0]:>3} / {c[1]:>3} / {c[2]:>3}")
        if not ok:
            failures.append(f"row-count mismatch {oc}: base={c[0]} prop={c[1]} fbdi={c[2]}")

    print("   values per FBDI file (every mapped column, baseline vs FBDI scenario):")
    for fid, fn, oc, st, dist in reg:
        cols = poscols.get(fid, [])
        rf = filt.get((fn, oc))
        where = 'scenario_id = :scn' + (f' and ({rf})' if rf else '')
        a = rows(cur, st, cols, where, {'scn': base}, dist == 'Y')
        b = rows(cur, st, cols, where, {'scn': sf}, dist == 'Y')
        ok = a == b and len(a) > 0
        print(f"     {'PASS' if ok else 'FAIL'}  {fn:36} {oc:20} rows={len(b):>2} cols={len(cols)}")
        if not ok:
            diff = [r for r in a if r not in b][:1] + [r for r in b if r not in a][:1]
            failures.append(f"value mismatch {fn}->{oc}: base rows={len(a)} fbdi rows={len(b)} e.g. {diff}")

    cur.execute("select ledger_name, period_name from dmt_gl_interface_stg_tbl "
                "where scenario_id=:1 order by 1, 2", [sf])
    gl_f = cur.fetchall()
    cur.execute("select ledger_name, period_name from dmt_gl_interface_stg_tbl "
                "where scenario_id=:1 order by 1, 2", [base])
    if gl_f != cur.fetchall() or not any(r[0] for r in gl_f):
        failures.append("GL scattered spot-check (slots 92/95) mismatch")

    for oc, st in sorted({(r[2], r[3]) for r in reg}):
        cur.execute(f"select stg_status, sum(case when error_text is not null then 1 else 0 end) "
                    f"from {st} where scenario_id in (:1,:2) group by stg_status", [sp, sf])
        for status, errs in cur.fetchall():
            if status != 'NEW' or errs:
                failures.append(f"STG hygiene {st}: status={status} error_rows={errs}")


def leg2(cur, conn, failures):
    print("== Leg 2: the real generated CSVs of every file #792 registered")
    picked = {}
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as z:
        for fn in NEW_FILES:
            cur.execute("""select fbdi_csv_id, run_id, csv_content from dmt_fbdi_csv_tbl
                           where filename = :1 and dbms_lob.getlength(csv_content) > 0
                           order by run_id desc, fbdi_csv_id desc fetch first 1 row only""", [fn])
            r = cur.fetchone()
            if not r:
                failures.append(f"no generated {fn} with content in DMT_FBDI_CSV_TBL")
                continue
            text = r[2].read()
            picked[fn] = (r[0], r[1], len(list(csv.reader(io.StringIO(text)))))
            z.writestr(fn, text)
    err, summ = load(cur, conn, buf.getvalue(), 'generated.zip', GEN_SCN)
    print("   generated.zip -> " + GEN_SCN + ": " + (summ.strip().splitlines()[-1] if summ.strip() else ''))
    if err:
        failures.append(f"generated zip load error: {err}")
    for line in summ.splitlines():
        if 'SKIPPED' in line:
            failures.append(f"generated zip: {line.strip()}")
    sg = scenario_id(cur, GEN_SCN)
    reg, poscols = file_registry(cur)
    print("   staged rows vs the TFM rows each generated file carried (every mapped column):")
    for fid, fn, oc, st, dist in reg:
        if fn not in picked:
            continue
        csv_id, run_id, lines = picked[fn]
        tfm = st.replace('_STG_TBL', '_TFM_TBL')
        cols = [c for c in poscols.get(fid, []) if c not in DERIVED.get((fn, oc), set())]
        a = rows(cur, tfm, cols, 'fbdi_csv_id = :id', {'id': csv_id}, dist == 'Y', date_only=True)
        b = rows(cur, st, cols, 'scenario_id = :scn', {'scn': sg}, dist == 'Y', date_only=True)
        if dist != 'Y' and len(b) != lines:
            failures.append(f"{fn}->{oc}: file has {lines} rows, staged {len(b)}")
        ok = a == b and len(b) > 0
        skipped = sorted(DERIVED.get((fn, oc), set()))
        print(f"     {'PASS' if ok else 'FAIL'}  {fn:36} {oc:20} run {run_id} file rows={lines:>2} "
              f"staged={len(b):>2} cols={len(cols)}" + (f" (not compared: {', '.join(skipped)})" if skipped else ''))
        if not ok:
            diff = [r for r in a if r not in b][:1] + [r for r in b if r not in a][:1]
            failures.append(f"generated {fn}->{oc}: tfm rows={len(a)} staged={len(b)} e.g. {diff}")


def main():
    conn = connect()
    cur = conn.cursor()
    failures = []
    leg1(cur, conn, failures)
    leg2(cur, conn, failures)
    print(f"\nscenarios left in place: {PROP_SCN}, {FBDI_SCN}, {GEN_SCN}")
    if failures:
        print("FAIL:")
        for f in failures:
            print("  -", f)
        sys.exit(1)
    print("PASS: both formats load the same data; every FBDI file round-trips; "
          "the real generated files stage exactly the rows their generators wrote.")


if __name__ == '__main__':
    main()
