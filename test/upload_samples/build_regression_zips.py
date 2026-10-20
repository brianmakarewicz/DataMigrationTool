#!/usr/bin/env python
"""
Build the two DMT2 upload test zips from the current regression baseline scenario
(scripts/regression_scenario.json "current_scenario") staging data, so both
reproduce the regression set in either upload format.

Outputs (in this directory):
  regressionProprietary.zip
      One DMT_<OBJECT>_STG_TBL.csv per regression object, WITH a header row of
      real staging-column names. Only populated columns are emitted (SOURCE_ID
      is always included). Loadable by the proprietary/header path.
  FBDIFormat.zip
      Every FBDI file the pipeline's generators write (fbdi_column_maps.FILES),
      headerless and positional, laid out exactly as the generators emit
      (column N = the staging column at FBDI position N), dates in the file's
      own date format. Rows per file follow the file's row_filter (PO Order /
      Blanket / Contract split the shared PO staging tables by style); a file fed
      by two objects (Assets FaMassAdditions.csv) is one row per driver row
      joined to the other object. Loadable by the FBDI path.

Both are loadable by DMT_CSV_UPLOAD_PKG.UPLOAD_ZIP_AUTO (auto-detect).

Usage:
    python build_regression_zips.py
Reads the local Docker DB (dmt_owner). Read-only against the DB.
"""
import csv
import datetime
import io
import json
import os
import zipfile

import oracledb

from fbdi_column_maps import FILES, MDY

HERE = os.path.dirname(os.path.abspath(__file__))
SCENARIO_JSON = os.path.join(HERE, '..', '..', 'scripts', 'regression_scenario.json')
SCENARIO_ID = None   # resolved in main() from regression_scenario.json

# Staging admin/infrastructure columns never emitted as business data.
ADMIN = {'STG_SEQUENCE_ID', 'STAGE_DATE', 'STG_STATUS', 'ERROR_TEXT',
         'LAST_UPDATED_DATE', 'SCENARIO_ID'}


def connect():
    conn = oracledb.connect(user="dmt_owner", password="DmtLocal#2026",
                            dsn="localhost:1523/FREEPDB1")
    conn.call_timeout = 30000
    return conn


def fmt(v, date_mask=None):
    """Render a value the way the FBDI generators do: dates YYYY/MM/DD, or
    MM/DD/YYYY for a file whose date_mask says so (Grants, Billing Events)."""
    if v is None:
        return ''
    d = '%m/%d/%Y' if date_mask == MDY else '%Y/%m/%d'
    if isinstance(v, datetime.datetime):
        if v.hour or v.minute or v.second:
            return v.strftime(d + ' %H:%M:%S')
        return v.strftime(d)
    if isinstance(v, datetime.date):
        return v.strftime(d)
    return str(v)


def current_scenario_id(cur):
    name = json.load(open(SCENARIO_JSON, encoding='utf-8'))['current_scenario']
    cur.execute("select scenario_id from dmt_scenario_tbl where scenario_name = :1", [name])
    row = cur.fetchone()
    if not row:
        raise SystemExit(f"regression scenario {name} not found on this database")
    return row[0], name


# The linking key each child FBDI file carries (backlog #793), written the way the
# generator writes it, from staging: {file: (slot, SQL over the file's staging row t)}.
# The generator writes TFM ids; from staging the stand-in is the staging row id.
LINK_KEYS = {
    'FaMassAdditions.csv': (1, 't.STG_SEQUENCE_ID'),   # MASS_ADDITION_ID of the book row
    'FaMassaddDistributions.csv': (1, '(SELECT MIN(b.STG_SEQUENCE_ID) FROM DMT_FA_ASSET_BOOK_STG_TBL b '
                                      'WHERE b.SCENARIO_ID = t.SCENARIO_ID AND b.ASSET_NUMBER = t.ASSET_NUMBER)'),
    'InvTransactionLotsInterface.csv': (1, 'NVL((SELECT TO_CHAR(p.INV_LOTSERIAL_INTERFACE_NUM) '
                                           'FROM DMT_INV_TRX_STG_TBL p WHERE p.STG_SEQUENCE_ID = '
                                           'TO_NUMBER(t.SOURCE_ID DEFAULT NULL ON CONVERSION ERROR)), '
                                           'TO_CHAR(t.INVENTORY_LOT_INTERFACE_NUMBER))'),
    'InvSerialNumbersInterface.csv': (1, '(SELECT TO_CHAR(p.INV_LOTSERIAL_INTERFACE_NUM) '
                                         'FROM DMT_INV_TRX_STG_TBL p WHERE p.STG_SEQUENCE_ID = '
                                         'TO_NUMBER(t.SOURCE_ID DEFAULT NULL ON CONVERSION ERROR))'),
}
KEY = '__LINK_KEY'


def object_rows(cur, staging_table, columns, row_filter=None, key_sql=None):
    """Return the scenario's rows for the given columns (plus the file's linking key
    as the last value when key_sql is given), ordered by STG_SEQUENCE_ID, narrowed by
    an FBDI file's row_filter (which may reference :scn)."""
    col_sql = ", ".join(f't."{c}"' for c in columns) + (f', {key_sql}' if key_sql else '')
    where = 't.scenario_id = :scn' + (f' and ({row_filter})' if row_filter else '')
    cur.execute(
        f'select {col_sql} from {staging_table} t '
        f'where {where} order by t.stg_sequence_id', scn=SCENARIO_ID)
    return cur.fetchall()


def table_columns(cur, staging_table):
    cur.execute(
        "select column_name from user_tab_columns "
        "where table_name = :1 order by column_id", [staging_table])
    return [r[0] for r in cur]


def build_proprietary(cur, out_path):
    """One header CSV per registered regression object, populated columns only."""
    cur.execute("""
        select object_code, staging_table, csv_filename, nvl(display_order,0)
        from   dmt_upload_object_tbl where is_active = 'Y' order by display_order""")
    objects = cur.fetchall()
    written = []
    with zipfile.ZipFile(out_path, 'w', zipfile.ZIP_DEFLATED) as z:
        for oc, st, csv_fn, _do in objects:
            all_cols = table_columns(cur, st)
            # business columns (+ SOURCE_ID which is a real natural key)
            biz = [c for c in all_cols if c not in ADMIN]
            if 'SOURCE_ID' not in biz and 'SOURCE_ID' in all_cols:
                biz.insert(0, 'SOURCE_ID')
            rows = object_rows(cur, st, biz)
            if not rows:
                continue
            # keep only columns that are populated in at least one row (but always SOURCE_ID)
            keep_idx = [i for i, c in enumerate(biz)
                        if c == 'SOURCE_ID' or any(r[i] is not None for r in rows)]
            keep_cols = [biz[i] for i in keep_idx]
            buf = io.StringIO()
            w = csv.writer(buf, lineterminator='\n')
            w.writerow(keep_cols)
            for r in rows:
                w.writerow([fmt(r[i]) for i in keep_idx])
            z.writestr(csv_fn, buf.getvalue())
            written.append((oc, csv_fn, len(rows), len(keep_cols)))
    return written


def build_fbdi(cur, out_path):
    """Every FBDI file of fbdi_column_maps.FILES, headerless and positional."""
    cur.execute("select object_code, staging_table from dmt_upload_object_tbl")
    stg_of = dict(cur.fetchall())
    groups = {}
    for x in FILES:
        groups.setdefault(x.file, []).append(x)
    written = []
    with zipfile.ZipFile(out_path, 'w', zipfile.ZIP_DEFLATED) as z:
        for fname, entries in groups.items():
            first = entries[0]
            colmap = first.cols
            if first.driver:
                # One file row per driver row, joined to the other object(s) on the key.
                drv_obj, key = first.driver
                per_obj = {}
                for x in entries:
                    st = stg_of[x.object]
                    have = set(table_columns(cur, st))
                    cols = list(dict.fromkeys([key] + [c for c in colmap if c and c in have]))
                    ks = LINK_KEYS.get(fname, (None, None))[1] if x.object == drv_obj else None
                    per_obj[x.object] = [dict(zip(cols + ([KEY] if ks else []), r))
                                         for r in object_rows(cur, st, cols, x.row_filter, ks)]
                lookup = {o: {r[key]: r for r in rows} for o, rows in per_obj.items() if o != drv_obj}
                rows = []
                for d in per_obj[drv_obj]:
                    merged = {}
                    for o in lookup:
                        merged.update(lookup[o].get(d[key], {}))
                    merged.update(d)
                    rows.append(merged)
            else:
                st = stg_of[first.object]
                have = set(table_columns(cur, st))
                cols = [c for c in colmap if c and c in have]
                if not cols:
                    continue
                ks = LINK_KEYS.get(fname, (None, None))[1]
                rows = [dict(zip(cols + ([KEY] if ks else []), r))
                        for r in object_rows(cur, st, cols, first.row_filter, ks)]
            if not rows:
                continue
            buf = io.StringIO()
            w = csv.writer(buf, lineterminator='\n', quoting=csv.QUOTE_ALL)
            for r in rows:
                key_slot = LINK_KEYS.get(fname, (None, None))[0]
                w.writerow([fmt(r.get(KEY)) if i == key_slot else
                            (fmt(r.get(c), first.date_mask) if c else '')
                            for i, c in enumerate(colmap, 1)])
            z.writestr(fname, buf.getvalue())
            written.append((', '.join(x.object for x in entries), fname, len(rows), len(colmap)))
    return written


def main():
    global SCENARIO_ID
    conn = connect()
    cur = conn.cursor()
    SCENARIO_ID, name = current_scenario_id(cur)
    print(f"source scenario: {name} (scenario_id {SCENARIO_ID})")
    prop_path = os.path.join(HERE, 'regressionProprietary.zip')
    fbdi_path = os.path.join(HERE, 'FBDIFormat.zip')

    prop = build_proprietary(cur, prop_path)
    fbdi = build_fbdi(cur, fbdi_path)

    print(f"regressionProprietary.zip: {len(prop)} CSVs")
    for oc, fn, nrows, ncols in prop:
        print(f"    {oc:22} {fn:35} rows={nrows} cols={ncols}")
    print(f"\nFBDIFormat.zip: {len(fbdi)} CSVs")
    for oc, fn, nrows, ncols in fbdi:
        print(f"    {fn:36} {oc:28} rows={nrows} width={ncols}")
    conn.close()


if __name__ == '__main__':
    main()
