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

Run as:  python scripts/deploy_recon_bip_reports.py [CemliFilter ...] [dm=DM_NAME ...]
         (dm=... deploys only the named data model(s), e.g. dm=DMT_GRANT_RECON_V2_DM,
          so a new version can be pushed without re-pushing its CEMLI's other pairs)
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
    ("APInvoices",              "DMT_AP_RECON_DM",   "DMT_AP_RECON_RPT"),
    ("Customers",               "DMT_CUST_RECON_V5_DM", "DMT_CUST_RECON_V5_RPT"),
    ("ARInvoices",              "DMT_AR_RECON_DM",   "DMT_AR_RECON_RPT"),
    ("GLBalances",              "DMT_GL_BAL_RECON_DM", "DMT_GL_BAL_RECON_RPT"),
    ("GLBudgets",               "GL_BUDGET_DM",      "GL_BUDGET_RPT"),
    # Items V2 (2026-10-06): deployed alongside the original DMT_ITEM_RECON_DM
    # (never overwritten). Category tiers also match request_id = import ESS
    # id and carry MESSAGE_NAME + text from both EGP interface tables.
    ("Items",                   "DMT_ITEM_RECON_V2_DM", "DMT_ITEM_RECON_V2_RPT"),
    ("ItemCategories",          "ITEM_CAT_DM",       "ITEM_CAT_RPT"),
    ("Workers",                 "DMT_WORKERS_RECON_DM", "DMT_WORKERS_RECON_RPT"),
    ("SalaryBases",             "DMT_SALARYBASES_RECON_DM", "DMT_SALARYBASES_RECON_RPT"),
    ("Salaries",                "DMT_SALARIES_RECON_DM", "DMT_SALARIES_RECON_RPT"),
    ("Absences",                "DMT_ABSENCES_RECON_DM", "DMT_ABSENCES_RECON_RPT"),
    ("WorkSchedules",            "DMT_WORKSCHEDULES_RECON_DM", "DMT_WORKSCHEDULES_RECON_RPT"),
    ("PayrollRelationships",     "DMT_PAYROLLRELATIONSHIPS_RECON_DM", "DMT_PAYROLLRELATIONSHIPS_RECON_RPT"),
    ("Assignments",              "DMT_ASSIGNMENTS_RECON_DM", "DMT_ASSIGNMENTS_RECON_RPT"),
    ("BenParticipant",           "DMT_BENPARTICIPANT_RECON_DM", "DMT_BENPARTICIPANT_RECON_RPT"),
    ("BenDependent",            "DMT_BENDEPENDENT_RECON_DM", "DMT_BENDEPENDENT_RECON_RPT"),
    ("BenBeneficiary",           "DMT_BENBENEFICIARY_RECON_DM", "DMT_BENBENEFICIARY_RECON_RPT"),
    ("W2Balances",              "DMT_W2_BAL_RECON_DM", "DMT_W2_BAL_RECON_RPT"),
    ("TalentProfiles",           "DMT_TALENTPROFILES_RECON_DM", "DMT_TALENTPROFILES_RECON_RPT"),
    ("PerfEvaluations",          "DMT_PERFEVALUATIONS_RECON_DM", "DMT_PERFEVALUATIONS_RECON_RPT"),
    ("Projects",                 "DMT_PROJECT_RECON_DM",       "DMT_PROJECT_RECON_RPT"),
    # ProjectBudgets recon V2 (2026-10-07, known-good fix): deployed alongside the
    # original PRJ_BUDGET_DM (never overwritten). Run scoped by the prefixed
    # PM_BUDGET_REFERENCE so budgets on EXISTING projects reconcile.
    ("ProjectBudgets",           "DMT_PRJ_BUDGET_RECON_V2_DM",           "DMT_PRJ_BUDGET_RECON_V2_RPT"),
    # Grants V2 (2026-10-07, docs/findings/known_good_Grants.md): BASE tier keyed
    # on OKC_K_HEADERS_ALL_B.CONTRACT_NUMBER, prefix-scoped. Deployed alongside
    # the original DMT_GRANT_RECON_DM (never overwritten).
    ("Grants",                   "DMT_GRANT_RECON_V2_DM",      "DMT_GRANT_RECON_V2_RPT"),
    # CashBanks (backlog #136) -- three-tier base-table recon DM/report was
    # committed (bip/CashBanks/) and registered (dmt_bip_report_tbl.sql) but was
    # never added to this deploy manifest, so the live /Custom/DMT2/CashBanks/
    # report was a stale generic model that emitted SOURCE_TYPE=BASE and ignored
    # P_BANK_NAMES. PARSE_BANKS requires SOURCE_TYPE=BASE_BANK, so a genuinely
    # loaded bank reconciled to 0 and was wrongly FAILED. Deploy the real pair.
    ("CashBanks",                "DMT_CEBANK_RECON_DM",        "DMT_CEBANK_RECON_RPT"),
    # REST config base-table recon reports (backlog #135) -- natural-key
    # match on the run's code list (P_UOM_CODES / P_TYPE_CODES+P_VALUE_KEYS),
    # replacing the non-persisting ATTRIBUTE1 DFF run-scope filter.
    ("UnitsOfMeasure",           "DMT_UOM_RECON_DM",           "DMT_UOM_RECON_RPT"),
    ("Lookups",                  "DMT_LOOKUP_RECON_DM",        "DMT_LOOKUP_RECON_RPT"),
    # PPM family (2026-09-28) -- post-run comparison reports, family E.
    ("Projects",                 "PROJECT_CMP_DM",             "PROJECT_CMP_RPT"),
    ("ProjectBudgets",           "PRJ_BUDGET_CMP_DM",          "PRJ_BUDGET_CMP_RPT"),
    ("Expenditures",             "EXP_CMP_DM",                 "EXP_CMP_RPT"),
    ("BillingEvents",            "BE_CMP_DM",                  "BE_CMP_RPT"),
    ("Grants",                   "GRANTS_CMP_DM",              "GRANTS_CMP_RPT"),
    # Assets + Requisitions family (2026-09-28) -- post-run comparison reports, family F.
    ("Assets",                   "FA_CMP_DM",                  "FA_CMP_RPT"),
    ("Requisitions",             "REQ_CMP_DM",                 "REQ_CMP_RPT"),
    # HCM family (2026-09-28) -- post-run comparison reports, family G (FINAL).
    ("Workers",                  "WORKERS_CMP_DM",             "WORKERS_CMP_RPT"),
    ("Salaries",                 "SALARIES_CMP_DM",            "SALARIES_CMP_RPT"),
    ("TalentProfiles",           "TALENTPROFILES_CMP_DM",      "TALENTPROFILES_CMP_RPT"),
    # Suppliers + Procurement + AR/AP/Customers family (2026-09-28, whole-branch
    # review fix) -- post-run comparison reports that were missed from this
    # manifest during the rollout. Names/paths cross-checked against
    # db/seed/dmt_bip_report_tbl.sql CMP_DM_CATALOG_PATH / CMP_REPORT_CATALOG_PATH.
    ("Suppliers",                "SUP_CMP_DM",                 "SUP_CMP_RPT"),
    ("SupplierAddresses",        "SUP_ADDR_CMP_DM",            "SUP_ADDR_CMP_RPT"),
    ("SupplierSites",            "SUP_SITE_CMP_DM",            "SUP_SITE_CMP_RPT"),
    ("SupplierSiteAssignments",  "SUP_SITE_ASSN_CMP_DM",       "SUP_SITE_ASSN_CMP_RPT"),
    ("SupplierContacts",         "SUP_CONT_CMP_DM",            "SUP_CONT_CMP_RPT"),
    ("BlanketPOs",               "PO_CMP_DM",                  "PO_CMP_RPT"),
    ("Contracts",                "PO_CMP_DM",                  "PO_CMP_RPT"),
    ("APInvoices",               "AP_CMP_DM",                  "AP_CMP_RPT"),
    ("Customers",                "CUST_CMP_DM",                "CUST_CMP_RPT"),
    ("ARInvoices",               "AR_CMP_DM",                  "AR_CMP_RPT"),
    ("PurchaseOrders",           "PO_CMP_DM",                  "PO_CMP_RPT"),
    ("GLBalances",               "GL_BAL_CMP_DM",              "GL_BAL_CMP_RPT"),
    ("GLBudgets",                "GL_BUDGET_CMP_DM",           "GL_BUDGET_CMP_RPT"),
]

DEFAULT_CONN = "dmt_owner/DmtLocal#2026@localhost:1523/FREEPDB1"


def connect():
    conn_str = os.environ.get("DMT2_CONN", DEFAULT_CONN)
    m = re.match(r"^([^/]+)/(.+)@(?://)?(.+)$", conn_str)
    if not m:
        sys.exit(f"Cannot parse DMT2_CONN: {conn_str!r}")
    user, password, dsn = m.groups()
    import os as _os
    _w = _os.environ.get('DMT2_WALLET')
    _kw = dict(config_dir=_w, wallet_location=_w, wallet_password=_os.environ.get('DMT2_WALLET_PW')) if _w else {}
    return oracledb.connect(user=user, password=password, dsn=dsn, **_kw)


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
    args = sys.argv[1:]
    dm_filter = [a[3:].lower() for a in args if a.lower().startswith("dm=")]
    cemli_filter = [a.lower() for a in args if not a.lower().startswith("dm=")]
    reports = [r for r in REPORTS
               if not cemli_filter or r[0].lower() in cemli_filter]
    reports = [r for r in reports
               if not dm_filter or r[1].lower() in dm_filter]

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
