#!/usr/bin/env python
"""
Deploy the Wave-1 BIP reconciliation reports (the five supplier-family objects
plus Customers) to THIS stack's Fusion catalog root /Custom/DMT2/{CEMLI}/
(never /Custom/DMT/ -- that is the frozen stack's catalog and is read-only to
DMT2).

Dev/test shim only (no pipeline logic): each report pair is deployed by the
DB's own DMT_BIP_DEPLOY_PKG.DEPLOY_RECON_REPORT -- login via SecurityService,
delete any prior versions, createObjectInSession for the .xdm, then a
generated XML-output .xdo wrapper linked to it. The package enforces the
/Custom/DMT2 folder guard (-20055) server-side.

The registry rows in DMT_BIP_REPORT_TBL are NOT touched here -- they are
seeded by db/seed/dmt_bip_report_tbl.sql (supplier MERGE block).

Run as:  python scripts/deploy_supplier_bip_reports.py [CemliFilter ...]
Env:     DMT2_CONN  user/password@host:port/service
         (default: the local Docker instance dmt2-local)
"""
import os
import re
import sys

import oracledb

REPO = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
CATALOG_ROOT = "/Custom/DMT2"

# (cemli_code, dm_name, rpt_name) -- .xdm lives at bip/{cemli}/{dm_name}.xdm
REPORTS = [
    ("Suppliers",               "SUP_DM",           "SUP_RPT"),
    ("SupplierAddresses",       "SUP_ADDR_DM",      "SUP_ADDR_RPT"),
    ("SupplierSites",           "SUP_SITE_DM",      "SUP_SITE_RPT"),
    ("SupplierSiteAssignments", "SUP_SITE_ASSN_DM", "SUP_SITE_ASSN_RPT"),
    ("SupplierContacts",        "SUP_CONT_DM",      "SUP_CONT_RPT"),
    ("PurchaseOrders",          "PO_DM",             "PO_RPT"),
    ("BlanketPOs",              "BLANKET_PO_DM",     "BLANKET_PO_RPT"),
    ("Contracts",               "CONTRACT_DM",       "CONTRACT_RPT"),
    ("Customers",               "DMT_CUST_RECON_DM", "DMT_CUST_RECON_RPT"),
    ("ARInvoices",              "AR_DM",             "AR_RPT"),
    ("GLBalances",              "GL_BAL_DM",         "GL_BAL_RPT"),
    ("Items",                   "ITEM_DM",           "ITEM_RPT"),
    ("ItemCategories",          "ITEM_CAT_DM",       "ITEM_CAT_RPT"),
]

DEFAULT_CONN = "dmt_owner/DmtLocal#2026@localhost:1523/FREEPDB1"


def connect():
    conn_str = os.environ.get("DMT2_CONN", DEFAULT_CONN)
    m = re.match(r"^([^/]+)/(.+)@(?://)?(.+)$", conn_str)
    if not m:
        sys.exit(f"Cannot parse DMT2_CONN: {conn_str!r}")
    user, password, dsn = m.groups()
    return oracledb.connect(user=user, password=password, dsn=dsn)


def get_dbms_output(cur):
    status_var = cur.var(oracledb.NUMBER)
    line_var = cur.var(oracledb.STRING)
    lines = []
    while True:
        cur.callproc("dbms_output.get_line", (line_var, status_var))
        if status_var.getvalue() != 0:
            break
        if line_var.getvalue():
            lines.append(line_var.getvalue())
    return lines


def main():
    cemli_filter = [a.lower() for a in sys.argv[1:]]
    reports = [r for r in REPORTS
               if not cemli_filter or r[0].lower() in cemli_filter]

    conn = connect()
    cur = conn.cursor()
    cur.callproc("dbms_output.enable", [None])

    ok = fail = 0
    for cemli, dm_name, rpt_name in reports:
        folder = f"{CATALOG_ROOT}/{cemli}"
        xdm_path = os.path.join(REPO, "bip", cemli, f"{dm_name}.xdm")
        print(f"=== {cemli} -> {folder} ===")
        if not os.path.exists(xdm_path):
            print(f"  ERR  missing {xdm_path}")
            fail += 1
            continue
        with open(xdm_path, encoding="utf-8") as f:
            xdm_xml = f.read()

        xdm_var = cur.var(oracledb.DB_TYPE_CLOB)
        xdm_var.setvalue(0, xdm_xml)
        try:
            cur.execute(
                """
                BEGIN
                    DMT_BIP_DEPLOY_PKG.DEPLOY_RECON_REPORT(
                        p_folder   => :folder,
                        p_dm_name  => :dm_name,
                        p_rpt_name => :rpt_name,
                        p_xdm_xml  => :xdm);
                END;
                """,
                folder=folder, dm_name=dm_name, rpt_name=rpt_name, xdm=xdm_var)
            for ln in get_dbms_output(cur):
                print(f"  [PL/SQL] {ln}")
            print(f"  OK   {folder}/{dm_name}.xdm + {rpt_name}.xdo")
            ok += 1
        except Exception as e:
            for ln in get_dbms_output(cur):
                print(f"  [PL/SQL] {ln}")
            print(f"  ERR  {e}")
            fail += 1
    conn.commit()  # DMT_UTIL_PKG.LOG rows
    cur.close()
    conn.close()
    print(f"=== DONE: {ok} deployed, {fail} failed ===")
    sys.exit(1 if fail else 0)


if __name__ == "__main__":
    main()
