#!/usr/bin/env python3
"""
Backlog #51 -- End-to-end verification of the multi-CSV zip upload (Requirement A).

Proves that DMT_CSV_UPLOAD_PKG, given ONE zip that mixes CSVs for several
different objects (Suppliers + a child, PurchaseOrders header+lines+locations+
distributions), will:

  1. Route each CSV to the CORRECT staging table by filename
     (DMT_UPLOAD_OBJECT_TBL.CSV_FILENAME / FBDI_CSV_FILENAME).
  2. Load the good rows into each staging table.
  3. Honour parent-before-child load order (DISPLAY_ORDER) even when the files
     are in scrambled order inside the zip.
  4. Capture bad rows (bad datatype) in DMT_UPLOAD_ERROR_TBL and report them in
     the returned summary CLOB -- errors are RETURNED, not swallowed.

This is staging-load only. It does NOT touch Fusion.

WHY THE BLOB OVERLOAD
---------------------
The public entry points UPLOAD_ZIP_BUNDLE / UPLOAD_ZIP_AUTO read the zip from
APEX_APPLICATION_TEMP_FILES, which only an APEX session may write and which the
schema owner (DMT_OWNER) has no INSERT privilege on (ORA-41900). Their ONLY
extra step over the *_FROM_BLOB overloads is that single
"SELECT BLOB_CONTENT FROM APEX_APPLICATION_TEMP_FILES" fetch. Everything that
Requirement A is about -- APEX_ZIP unpack, filename->object routing,
DISPLAY_ORDER parent-before-child sort, the per-file UPLOAD_CSV_FROM_BLOB /
fbdi_load_from_blob loaders, LOG ERRORS row capture, and the summary CLOB -- is
the identical shared code path. This test drives that shared path through the
BLOB overloads, which are directly callable by the schema owner.

  Leg 1  UPLOAD_ZIP_AUTO_FROM_BLOB, all-proprietary bundle
         == exactly the routing/order/error logic of UPLOAD_ZIP_BUNDLE
  Leg 2  UPLOAD_ZIP_AUTO_FROM_BLOB, mixed proprietary + FBDI bundle
         == the auto-detect path of UPLOAD_ZIP_AUTO

No production code is modified.

Run:  python e2e_multi_object_zip_test.py
Requires: oracledb  (pip install oracledb)
"""

import io
import os
import sys
import zipfile

# Force UTF-8 stdout so summary CLOBs containing em-dashes print on Windows.
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

try:
    import oracledb
except ImportError:
    sys.exit("oracledb not installed. Run: pip install oracledb")

DSN = "localhost:1523/FREEPDB1"
USER = "dmt_owner"
PWD = "DmtLocal#2026"

HERE = os.path.dirname(os.path.abspath(__file__))

# Both scenario names this test stamps its fabricated rows with. Cleanup deletes
# every row tagged with these, so nothing is left NEW for a real pipeline run to
# sweep. (The Suppliers/PO pre-transform validators pick up STG_STATUS IN
# ('NEW','RETRY') with no scenario scoping, so residual rows MUST be removed.)
SCN_LEG1 = "E51_ZIP_BUNDLE_PROP"
SCN_LEG2 = "E51_ZIP_AUTO_MIXED"

# Every staging table this test loads into (across both legs).
LOADED_STG_TABLES = [
    "DMT_POZ_SUPPLIERS_STG_TBL",
    "DMT_POZ_SUP_ADDR_STG_TBL",
    "DMT_POZ_SUP_SITE_STG_TBL",
    "DMT_PO_HEADERS_INT_STG_TBL",
    "DMT_PO_LINES_INT_STG_TBL",
    "DMT_PO_LINE_LOCS_INT_STG_TBL",
    "DMT_PO_DISTS_INT_STG_TBL",
]

# ---------------------------------------------------------------------------
# Proprietary CSV fixtures (header row + data). Filename MUST equal
# DMT_UPLOAD_OBJECT_TBL.CSV_FILENAME so the loader routes it. Header names must
# match uploadable staging columns (verified against the dictionary).
#
# Objects covered by the proprietary bundle:
#   Suppliers        DMT_POZ_SUPPLIERS_STG_TBL      (parent,  display_order 1)
#   SupplierAddress  DMT_POZ_SUP_ADDR_STG_TBL       (         display_order 2)
#   PO Header        DMT_PO_HEADERS_INT_STG_TBL     (parent,  display_order 6)
#   PO Lines         DMT_PO_LINES_INT_STG_TBL       (child,   display_order 7)  <- BAD row here
#   PO Line Locs     DMT_PO_LINE_LOCS_INT_STG_TBL   (child,   display_order 8)
#   PO Distributions DMT_PO_DISTS_INT_STG_TBL       (child,   display_order 9)
# 6 staging tables across 3 objects, including parent+child.
# ---------------------------------------------------------------------------

PROP = {
    "DMT_POZ_SUPPLIERS_STG_TBL.csv": [
        ["IMPORT_ACTION", "VENDOR_NAME", "SEGMENT1", "VENDOR_TYPE_LOOKUP_CODE"],
        ["CREATE", "E51 Test Supplier One", "E51-SUP-001", "SUPPLIER"],
        ["CREATE", "E51 Test Supplier Two", "E51-SUP-002", "SUPPLIER"],
        ["CREATE", "E51 Test Supplier Three", "E51-SUP-003", "SUPPLIER"],
    ],
    "DMT_POZ_SUP_ADDR_STG_TBL.csv": [
        ["IMPORT_ACTION", "VENDOR_NAME", "PARTY_SITE_NAME", "COUNTRY", "ADDRESS_LINE1"],
        ["CREATE", "E51 Test Supplier One", "MAIN", "US", "100 Test Ave"],
        ["CREATE", "E51 Test Supplier Two", "MAIN", "US", "200 Test Blvd"],
    ],
    "DMT_PO_HEADERS_INT_STG_TBL.csv": [
        ["INTERFACE_HEADER_KEY", "ACTION", "DOCUMENT_NUM", "DOCUMENT_TYPE_CODE", "PRC_BU_NAME"],
        ["E51-H1", "ORIGINAL", "E51-PO-1", "STANDARD", "US1 Business Unit"],
        ["E51-H2", "ORIGINAL", "E51-PO-2", "STANDARD", "US1 Business Unit"],
    ],
    # LINE_NUM is NUMBER; row 3 puts the non-numeric string "NOT_A_NUMBER" there
    # -> per-row datatype rejection (ORA-01722 invalid number).
    "DMT_PO_LINES_INT_STG_TBL.csv": [
        ["INTERFACE_LINE_KEY", "INTERFACE_HEADER_KEY", "LINE_NUM", "ITEM_DESCRIPTION", "AMOUNT"],
        ["E51-L1", "E51-H1", "1", "Good line one", "100.50"],
        ["E51-L2", "E51-H1", "2", "Good line two", "200.75"],
        ["E51-L3-BAD", "E51-H1", "NOT_A_NUMBER", "Bad line - LINE_NUM not numeric", "300.00"],
    ],
    "DMT_PO_LINE_LOCS_INT_STG_TBL.csv": [
        ["INTERFACE_LINE_LOCATION_KEY", "INTERFACE_LINE_KEY", "SHIPMENT_NUM", "QUANTITY"],
        ["E51-LL1", "E51-L1", "1", "10"],
        ["E51-LL2", "E51-L2", "1", "20"],
    ],
    "DMT_PO_DISTS_INT_STG_TBL.csv": [
        ["INTERFACE_DISTRIBUTION_KEY", "INTERFACE_LINE_LOCATION_KEY", "DISTRIBUTION_NUM", "QUANTITY_ORDERED"],
        ["E51-D1", "E51-LL1", "1", "10"],
    ],
}

# filename -> (staging table, expected GOOD rows loaded, expected errored rows)
PROP_EXPECT = {
    "DMT_POZ_SUPPLIERS_STG_TBL.csv":     ("DMT_POZ_SUPPLIERS_STG_TBL",     3, 0),
    "DMT_POZ_SUP_ADDR_STG_TBL.csv":      ("DMT_POZ_SUP_ADDR_STG_TBL",      2, 0),
    "DMT_PO_HEADERS_INT_STG_TBL.csv":    ("DMT_PO_HEADERS_INT_STG_TBL",    2, 0),
    "DMT_PO_LINES_INT_STG_TBL.csv":      ("DMT_PO_LINES_INT_STG_TBL",      2, 1),  # 1 bad row
    "DMT_PO_LINE_LOCS_INT_STG_TBL.csv":  ("DMT_PO_LINE_LOCS_INT_STG_TBL",  2, 0),
    "DMT_PO_DISTS_INT_STG_TBL.csv":      ("DMT_PO_DISTS_INT_STG_TBL",      1, 0),
}

# For Leg 2's mixed bundle: an FBDI (headerless, positional) member for
# POZ_SUP_SITE. Positions 1-5 are IMPORT_ACTION, VENDOR_NAME,
# PROCUREMENT_BUSINESS_UNIT_NAME, PARTY_SITE_NAME, VENDOR_SITE_CODE.
# Routed by FBDI_CSV_FILENAME = 'PozSupplierSitesInt.csv'.
FBDI_FILE = "PozSupplierSitesInt.csv"
FBDI_STG = "DMT_POZ_SUP_SITE_STG_TBL"
FBDI_ROWS = [
    ["CREATE", "E51 Test Supplier One", "US1 Business Unit", "MAIN", "E51-SITE-1"],
    ["CREATE", "E51 Test Supplier Two", "US1 Business Unit", "MAIN", "E51-SITE-2"],
]


def csv_bytes(rows):
    return ("\r\n".join(",".join(str(c) for c in r) for r in rows) + "\r\n").encode("utf-8")


def build_prop_zip(path):
    # Deliberately scramble the order so we PROVE the loader re-sorts by
    # DISPLAY_ORDER: children before parents inside the zip.
    order = [
        "DMT_PO_DISTS_INT_STG_TBL.csv",       # order 9 (child)
        "DMT_PO_LINES_INT_STG_TBL.csv",       # order 7 (child)
        "DMT_POZ_SUP_ADDR_STG_TBL.csv",       # order 2
        "DMT_PO_LINE_LOCS_INT_STG_TBL.csv",   # order 8 (child)
        "DMT_POZ_SUPPLIERS_STG_TBL.csv",      # order 1 (parent)
        "DMT_PO_HEADERS_INT_STG_TBL.csv",     # order 6 (parent)
    ]
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        for name in order:
            z.writestr(name, csv_bytes(PROP[name]))
    data = buf.getvalue()
    with open(path, "wb") as f:
        f.write(data)
    return data, order


def build_mixed_zip(path):
    # Proprietary suppliers + FBDI supplier-sites, scrambled.
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr(FBDI_FILE, csv_bytes(FBDI_ROWS))                       # FBDI, order 3
        z.writestr("DMT_POZ_SUP_ADDR_STG_TBL.csv", csv_bytes(PROP["DMT_POZ_SUP_ADDR_STG_TBL.csv"]))  # prop, order 2
        z.writestr("DMT_POZ_SUPPLIERS_STG_TBL.csv", csv_bytes(PROP["DMT_POZ_SUPPLIERS_STG_TBL.csv"]))  # prop, order 1
        z.writestr("garbage_unmatched_file.csv", b"a,b,c\r\n1,2,3\r\n")   # should be SKIPPED
    data = buf.getvalue()
    with open(path, "wb") as f:
        f.write(data)
    return data


def blob_from_bytes(cur, data):
    v = cur.var(oracledb.DB_TYPE_BLOB)
    cur.execute("DECLARE b BLOB; BEGIN DBMS_LOB.CREATETEMPORARY(b, TRUE); :o := b; END;", o=v)
    lob = v.getvalue()
    lob.write(data)
    return lob


def call_auto_from_blob(cur, conn, data, label, scenario, fast=True):
    lob = blob_from_bytes(cur, data)
    p_summary = cur.var(oracledb.DB_TYPE_CLOB)
    p_batch_out = cur.var(oracledb.NUMBER)
    p_err = cur.var(oracledb.STRING, 4000)
    cur.callproc(
        "DMT_CSV_UPLOAD_PKG.UPLOAD_ZIP_AUTO_FROM_BLOB",
        [lob, label, None, p_summary, p_batch_out, p_err, fast, scenario],
    )
    conn.commit()
    summary = p_summary.getvalue()
    if hasattr(summary, "read"):
        summary = summary.read()
    return summary, p_batch_out.getvalue(), p_err.getvalue()


def scenario_id(cur, name):
    cur.execute("SELECT SCENARIO_ID FROM DMT_SCENARIO_TBL WHERE SCENARIO_NAME = :n", n=name)
    r = cur.fetchone()
    return r[0] if r else None


def residual_count(cur):
    """Count every row this test could have left behind, keyed on its own tags:
    staging rows by SCENARIO_ID, log rows by object+scenario batch tag, error
    rows by BATCH_TAG prefix. Returns the total (0 == fully cleaned)."""
    sids = [s for s in (scenario_id(cur, SCN_LEG1), scenario_id(cur, SCN_LEG2)) if s is not None]
    total = 0
    if sids:
        binds = ",".join(f":{i}" for i in range(len(sids)))
        for t in LOADED_STG_TABLES:
            try:
                cur.execute(f"SELECT COUNT(*) FROM {t} WHERE SCENARIO_ID IN ({binds})", sids)
                total += cur.fetchone()[0]
            except oracledb.DatabaseError:
                pass
    cur.execute(
        "SELECT COUNT(*) FROM DMT_UPLOAD_ERROR_TBL WHERE BATCH_TAG LIKE :a OR BATCH_TAG LIKE :b",
        a=SCN_LEG1 + "~%", b=SCN_LEG2 + "~%")
    total += cur.fetchone()[0]
    return total


def cleanup(cur, conn, batch_ids):
    """Delete every row this test inserted, keyed on the SCENARIO_ID / batch tag
    it stamps. Mirrors the sibling roundtrip_test.py convention: delete by
    scenario across the *_STG_TBL tables, and never touch scenario_id 1.
    Also removes the matching DMT_UPLOAD_LOG_TBL and DMT_UPLOAD_ERROR_TBL rows."""
    sids = [s for s in (scenario_id(cur, SCN_LEG1), scenario_id(cur, SCN_LEG2))
            if s is not None and s != 1]
    deleted = 0

    # Staging tables: delete by scenario id (the tag stamped on every loaded row).
    if sids:
        binds = ",".join(f":{i}" for i in range(len(sids)))
        for t in LOADED_STG_TABLES:
            try:
                cur.execute(f"DELETE FROM {t} WHERE SCENARIO_ID IN ({binds})", sids)
                deleted += cur.rowcount
            except oracledb.DatabaseError:
                pass

    # Upload log rows for the batches this run created.
    bids = [b for b in batch_ids if b is not None]
    if bids:
        binds = ",".join(f":{i}" for i in range(len(bids)))
        try:
            cur.execute(f"DELETE FROM DMT_UPLOAD_LOG_TBL WHERE BATCH_ID IN ({binds})", bids)
            deleted += cur.rowcount
        except oracledb.DatabaseError:
            pass

    # Error rows tagged with either scenario name.
    try:
        cur.execute(
            "DELETE FROM DMT_UPLOAD_ERROR_TBL WHERE BATCH_TAG LIKE :a OR BATCH_TAG LIKE :b",
            a=SCN_LEG1 + "~%", b=SCN_LEG2 + "~%")
        deleted += cur.rowcount
    except oracledb.DatabaseError:
        pass

    conn.commit()
    return deleted


def run_leg1(cur, conn):
    print("#" * 72)
    print("# LEG 1 -- all-proprietary multi-object bundle")
    print("#          (identical routing/order/error path to UPLOAD_ZIP_BUNDLE)")
    print("#" * 72)
    scenario = SCN_LEG1
    zpath = os.path.join(HERE, "e51_multi_object_bundle.zip")
    data, order = build_prop_zip(zpath)
    print(f"Built {len(data)}-byte zip; member order inside zip (deliberately scrambled):")
    for n in order:
        print(f"    {n}")
    print(f"Zip: {zpath}\n")

    # Watermark each table's MAX(STG_SEQUENCE_ID) so we measure only this run.
    pre = {}
    for _, (tbl, _, _) in PROP_EXPECT.items():
        cur.execute(f"SELECT NVL(MAX(STG_SEQUENCE_ID),0) FROM {tbl}")
        pre[tbl] = cur.fetchone()[0]

    summary, batch_id, err_msg = call_auto_from_blob(cur, conn, data, "e51_prop.zip", scenario)
    print(f"returned batch_id_out = {batch_id}")
    print(f"returned error_msg    = {err_msg}")
    print(f"returned summary CLOB =\n----\n{summary}\n----\n")

    sid = scenario_id(cur, scenario)
    print(f"scenario '{scenario}' resolved to SCENARIO_ID = {sid}\n")

    print("Per-table routing + row counts (this run only):")
    all_pass = True
    max_order_seen = 0
    order_ok = True
    for csvname, (tbl, exp_loaded, exp_err) in sorted(PROP_EXPECT.items(), key=lambda x: x[1][0]):
        cur.execute(f"SELECT COUNT(*) FROM {tbl} WHERE STG_SEQUENCE_ID > :w", w=pre[tbl])
        delta = cur.fetchone()[0]
        # cross-check the scenario tag actually landed on the new rows
        cur.execute(
            f"SELECT COUNT(*) FROM {tbl} WHERE STG_SEQUENCE_ID > :w AND SCENARIO_ID = :s",
            w=pre[tbl], s=sid)
        tagged = cur.fetchone()[0]
        ok = (delta == exp_loaded and tagged == exp_loaded)
        all_pass = all_pass and ok
        print(f"  [{'PASS' if ok else 'FAIL'}] {csvname:33s} -> {tbl:32s} "
              f"loaded={delta} tagged={tagged} (expected {exp_loaded})")

    # Parent-before-child proof.
    # STG_SEQUENCE_ID is a PER-TABLE sequence, so it is NOT comparable across
    # tables. Actual load order is recorded in DMT_UPLOAD_LOG_TBL: each file gets
    # one LOG_ID from a single sequence at the moment it loads, so LOG_ID order
    # for this batch == the real load order. We assert each parent file's LOG_ID
    # is lower than every child file's LOG_ID.
    print("\nActual load order for this batch (DMT_UPLOAD_LOG_TBL, LOG_ID order):")
    cur.execute(
        """SELECT LOG_ID, OBJECT_CODE, FILE_NAME
           FROM DMT_UPLOAD_LOG_TBL WHERE BATCH_ID = :b ORDER BY LOG_ID""",
        b=batch_id)
    log_rows = cur.fetchall()
    log_id_of = {}
    for lr in log_rows:
        log_id_of[lr[1]] = lr[0]
        print(f"    LOG_ID={lr[0]}  {lr[1]:18s}  {lr[2]}")

    print("\nParent-before-child ordering proof (by LOG_ID):")
    fam = {
        "PO_HEADERS_INT": ["PO_LINES_INT", "PO_LINE_LOCS_INT", "PO_DISTS_INT"],
        "POZ_SUPPLIERS": ["POZ_SUP_ADDR"],
    }
    order_ok = True
    for parent, kids in fam.items():
        p = log_id_of.get(parent)
        for kid in kids:
            k = log_id_of.get(kid)
            ok = p is not None and k is not None and p < k
            order_ok = order_ok and ok
            print(f"  [{'PASS' if ok else 'FAIL'}] parent {parent} (LOG_ID {p}) "
                  f"loaded before child {kid} (LOG_ID {k})")

    # Error capture
    print("\nError capture (DMT_UPLOAD_ERROR_TBL, BATCH_TAG starts with scenario):")
    cur.execute(
        """SELECT ROW_NUMBER, ERROR_TYPE, ERROR_MESSAGE, BATCH_TAG
           FROM DMT_UPLOAD_ERROR_TBL WHERE BATCH_TAG LIKE :p
           ORDER BY ERROR_ID""",
        p=scenario + "~%")
    rows = cur.fetchall()
    err_captured = False
    for r in rows:
        msg = r[2]
        if hasattr(msg, "read"):
            msg = msg.read()
        print(f"  ROW={r[0]} TYPE={r[1]}")
        print(f"    MSG: {str(msg)[:160]}")
        print(f"    TAG: {r[3]}")
        if "ORA-" in str(msg) or "invalid number" in str(msg).lower():
            err_captured = True
    if not rows:
        print("  (none found)")

    summary_reports_error = summary is not None and "error" in str(summary).lower()

    checks = {
        "all good rows routed, loaded & scenario-tagged": all_pass,
        "parent loaded before child (DISPLAY_ORDER honoured)": order_ok,
        "bad row captured in DMT_UPLOAD_ERROR_TBL": err_captured,
        "summary CLOB reports the error count": summary_reports_error,
    }
    print("\nLeg 1 checks:")
    for k, v in checks.items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    return all(checks.values()), batch_id


def run_leg2(cur, conn):
    print("\n" + "#" * 72)
    print("# LEG 2 -- mixed proprietary + FBDI bundle (UPLOAD_ZIP_AUTO auto-detect)")
    print("#" * 72)
    scenario = SCN_LEG2
    zpath = os.path.join(HERE, "e51_mixed_auto_bundle.zip")
    data = build_mixed_zip(zpath)
    print(f"Built {len(data)}-byte mixed zip: 2 proprietary (Suppliers, SupplierAddresses),")
    print(f"  1 FBDI ({FBDI_FILE} -> {FBDI_STG}), 1 unmatched (should be SKIPPED).")
    print(f"Zip: {zpath}\n")

    tables = ["DMT_POZ_SUPPLIERS_STG_TBL", "DMT_POZ_SUP_ADDR_STG_TBL", FBDI_STG]
    pre = {}
    for tbl in tables:
        cur.execute(f"SELECT NVL(MAX(STG_SEQUENCE_ID),0) FROM {tbl}")
        pre[tbl] = cur.fetchone()[0]

    summary, batch_id, err_msg = call_auto_from_blob(cur, conn, data, "e51_mixed.zip", scenario)
    print(f"returned batch_id_out = {batch_id}")
    print(f"returned error_msg    = {err_msg}")
    print(f"returned summary CLOB =\n----\n{summary}\n----\n")

    exp = {"DMT_POZ_SUPPLIERS_STG_TBL": 3, "DMT_POZ_SUP_ADDR_STG_TBL": 2, FBDI_STG: 2}
    fmt = {"DMT_POZ_SUPPLIERS_STG_TBL": "proprietary",
           "DMT_POZ_SUP_ADDR_STG_TBL": "proprietary", FBDI_STG: "FBDI"}
    all_pass = True
    print("Per-table routing + row counts (this run only):")
    for tbl in tables:
        cur.execute(f"SELECT COUNT(*) FROM {tbl} WHERE STG_SEQUENCE_ID > :w", w=pre[tbl])
        delta = cur.fetchone()[0]
        ok = (delta == exp[tbl])
        all_pass = all_pass and ok
        print(f"  [{'PASS' if ok else 'FAIL'}] {tbl:32s} loaded={delta} "
              f"(expected {exp[tbl]}, format {fmt[tbl]})")

    skipped_ok = summary is not None and "SKIPPED" in str(summary) and "garbage_unmatched_file" in str(summary)
    print(f"\n  [{'PASS' if skipped_ok else 'FAIL'}] unmatched file reported as SKIPPED in summary")

    checks = {
        "proprietary + FBDI members both routed & loaded": all_pass,
        "unmatched file skipped (not silently dropped)": skipped_ok,
    }
    print("\nLeg 2 checks:")
    for k, v in checks.items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    return all(checks.values()), batch_id


def main():
    conn = oracledb.connect(user=USER, password=PWD, dsn=DSN)
    conn.autocommit = False
    cur = conn.cursor()

    leg1 = leg2 = False
    batch_ids = []
    residual = None
    try:
        leg1, b1 = run_leg1(cur, conn)
        batch_ids.append(b1)
        leg2, b2 = run_leg2(cur, conn)
        batch_ids.append(b2)
    finally:
        # Always clean up the fabricated rows, even if an assertion above failed,
        # so nothing is left NEW for a real pipeline run to sweep.
        print("\n" + "=" * 72)
        print("CLEANUP -- removing every row this test inserted")
        print("=" * 72)
        deleted = cleanup(cur, conn, batch_ids)
        residual = residual_count(cur)
        print(f"  rows deleted (staging + log + error) : {deleted}")
        print(f"  residual rows tagged by this test    : {residual}")
        print(f"  [{'PASS' if residual == 0 else 'FAIL'}] zero residual after cleanup")

    print("\n" + "=" * 72)
    print("OVERALL VERDICT -- Requirement A (multi-CSV zip upload)")
    print("=" * 72)
    print(f"  Leg 1 (UPLOAD_ZIP_BUNDLE-equivalent, all proprietary): {'PASS' if leg1 else 'FAIL'}")
    print(f"  Leg 2 (UPLOAD_ZIP_AUTO, mixed proprietary + FBDI)    : {'PASS' if leg2 else 'FAIL'}")
    print(f"  Cleanup left zero residual rows                      : {'PASS' if residual == 0 else 'FAIL'}")
    overall = leg1 and leg2 and (residual == 0)
    print(f"\n  REQUIREMENT A: {'PASS' if overall else 'FAIL'}")

    cur.close()
    conn.close()
    sys.exit(0 if overall else 1)


if __name__ == "__main__":
    main()
