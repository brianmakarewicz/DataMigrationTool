#!/usr/bin/env python
"""
Build the two DMT2 upload test zips from the RegressionTest scenario (scenario_id 1)
staging data, so both reproduce the regression set in either upload format.

Outputs (in this directory):
  regressionProprietary.zip
      One DMT_<OBJECT>_STG_TBL.csv per regression object, WITH a header row of
      real staging-column names. Only populated columns are emitted (SOURCE_ID
      is always included). Loadable by the proprietary/header path.
  FBDIFormat.zip
      The FBDI-named, headerless, positional CSVs for the FBDI objects in the
      regression set, laid out exactly as the pipeline's FBDI generators emit
      (column N = the staging column at FBDI position N, per fbdi_column_maps).
      Loadable by the FBDI path.

Both are loadable by DMT_CSV_UPLOAD_PKG.UPLOAD_ZIP_AUTO (auto-detect).

Usage:
    python build_regression_zips.py
Reads the local Docker DB (dmt_owner). Read-only against the DB.
"""
import csv
import io
import os
import zipfile

import oracledb

from fbdi_column_maps import MAPS

SCENARIO_ID = 1
HERE = os.path.dirname(os.path.abspath(__file__))

# Staging admin/infrastructure columns never emitted as business data.
ADMIN = {'STG_SEQUENCE_ID', 'STAGE_DATE', 'STG_STATUS', 'ERROR_TEXT',
         'LAST_UPDATED_DATE', 'SCENARIO_ID'}


def connect():
    conn = oracledb.connect(user="dmt_owner", password="DmtLocal#2026",
                            dsn="localhost:1523/FREEPDB1")
    conn.call_timeout = 30000
    return conn


def fmt(v):
    """Render a value the way the FBDI generators do (dates YYYY/MM/DD)."""
    if v is None:
        return ''
    import datetime
    if isinstance(v, datetime.datetime):
        # match generator date formatting; most generators use YYYY/MM/DD
        if v.hour or v.minute or v.second:
            return v.strftime('%Y/%m/%d %H:%M:%S')
        return v.strftime('%Y/%m/%d')
    if isinstance(v, datetime.date):
        return v.strftime('%Y/%m/%d')
    return str(v)


def object_rows(cur, staging_table, columns):
    """Return scenario-1 rows for the given columns, ordered by STG_SEQUENCE_ID."""
    col_sql = ", ".join(f'"{c}"' for c in columns)
    cur.execute(
        f'select {col_sql} from {staging_table} '
        f'where scenario_id = :1 order by stg_sequence_id', [SCENARIO_ID])
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
    """FBDI-named headerless positional CSVs for regression FBDI objects."""
    cur.execute("select object_code, staging_table, fbdi_csv_filename, nvl(display_order,0) "
                "from dmt_upload_object_tbl where fbdi_csv_filename is not null "
                "order by display_order")
    fbdi_objs = cur.fetchall()
    written = []
    with zipfile.ZipFile(out_path, 'w', zipfile.ZIP_DEFLATED) as z:
        for oc, st, fbdi_fn, _do in fbdi_objs:
            if oc not in MAPS:
                continue
            _fn, colmap = MAPS[oc]
            width = len(colmap)
            # Which staging columns exist, and at which position
            stg_cols = set(table_columns(cur, st))
            # Fetch the distinct staging columns we need
            needed = [c for c in colmap if c and c in stg_cols]
            if not needed:
                continue
            rows = object_rows(cur, st, needed)
            if not rows:
                continue
            # value lookup per row keyed by column name
            buf = io.StringIO()
            w = csv.writer(buf, lineterminator='\n', quoting=csv.QUOTE_ALL)
            for r in rows:
                valof = dict(zip(needed, r))
                line = []
                for c in colmap:
                    if c and c in valof:
                        line.append(fmt(valof[c]))
                    else:
                        line.append('')   # EMPTY / constant / non-STG slot
                w.writerow(line)
            z.writestr(fbdi_fn, buf.getvalue())
            written.append((oc, fbdi_fn, len(rows), width))
    return written


def main():
    conn = connect()
    cur = conn.cursor()
    prop_path = os.path.join(HERE, 'regressionProprietary.zip')
    fbdi_path = os.path.join(HERE, 'FBDIFormat.zip')

    prop = build_proprietary(cur, prop_path)
    fbdi = build_fbdi(cur, fbdi_path)

    print(f"regressionProprietary.zip: {len(prop)} CSVs")
    for oc, fn, nrows, ncols in prop:
        print(f"    {oc:22} {fn:35} rows={nrows} cols={ncols}")
    print(f"\nFBDIFormat.zip: {len(fbdi)} CSVs")
    for oc, fn, nrows, ncols in fbdi:
        print(f"    {oc:22} {fn:35} rows={nrows} width={ncols}")
    conn.close()


if __name__ == '__main__':
    main()
