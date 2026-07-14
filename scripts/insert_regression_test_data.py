"""
Insert known-good AND known-bad test data into ALL FBDI staging tables
for the "RegressionTest" scenario.

Each table gets:
  - 2 GOOD records (should flow through pipeline to LOADED)
  - 1-2 BAD records (should fail at predictable stages with known errors)

Bad record failure modes:
  [BAD-REQ]   Missing required field → validation failure
  [BAD-LKP]   Invalid lookup value → Fusion rejection
  [BAD-AMT]   Invalid amount/date → data quality failure
  [BAD-UPS]   Missing upstream parent → cascade failure

GOOD record values are derived from proven E2E LOADED runs on the demo instance.
See objects/{Name}/README.md "Valid Test Data" and "History" sections.

Proven runs (source of truth for GOOD data):
  Suppliers:      int=100000087, prefix=9224 — 10 LOADED (objects/Suppliers/README.md)
  Customers:      int=100000091, prefix=9228 — 19 LOADED (objects/Customers/README.md)
  PurchaseOrders: int=100000089, prefix=9226 —  8 LOADED (objects/PurchaseOrders/README.md)
  APInvoices:     E2E LOADED (objects/APInvoices/README.md)
  ARInvoices:     E2E LOADED (objects/ARInvoices/README.md)
  GLBalances:     int=100000005             —  2 LOADED, Cat=Adjustment, Src=Spreadsheet, Period=04-26
  Projects:       int=100000034, prefix=9179 —  9 LOADED, Org=Maintenance Prg US, SrcAppCode=NULL
  Expenditures:   int=100000040, prefix=9184 —  3 LOADED, Type=LABOR, Person=7/10
  BillingEvents:  int=100000044, prefix=9188 —  3 LOADED, Contract=C10028/C10001
  Requisitions:   int=100000024, prefix=9169 —  6 LOADED (objects/Requisitions/README.md)

  GLBudgetBalances: run 112, prefix 9623 — 4 LOADED / 1 FAILED (objects/GLBudget/README.md)
  ProjectBudgets:  int=100000027, prefix=9123 — 3 LOADED (objects/ProjectBudgets/README.md;
                   regression rows target the RT projects, prefixed at transform)

Not yet E2E tested (data is speculative):
  PlanningBudgets  — missing DMT_ERP_INTERFACE_OPTIONS_TBL config
  Items            — code built, org 001 (Seattle), standard items (no lot/serial)
  ItemCategories   — bundled with Items in one FBDI ZIP
  MiscReceipts     — code built, references Items (must LOAD items first)
  Assets           — int=100000002, prefix=9014, 2 LOADED (but data here is simplified)

Run as:  python -u scripts/insert_regression_test_data.py

After inserting, run the full pipeline with:
  scripts/run_regression.py
"""

import oracledb
from datetime import date
import sys; sys.path.insert(0, r'C:\Users\Monroe\workspace')
from conn_helper import connect_atp

# ── Connection ──────────────────────────────────────────────────────────────


SCENARIO_NAME = "RegressionTest"

# ── Reference data (valid on Fusion demo instance) ─────────────────────────
BU           = "US1 Business Unit"
LEDGER       = "US Primary Ledger"
LEDGER_ID    = 300000116270105
EXISTING_SUP = "Allied Manufacturing"        # segment1 = 1265
EXISTING_SUP_NUM = "1265"
EXISTING_SUP_SITE = "Allied US1"
CUST_ACCT_NO = "10060"                       # Computer Service and Rentals
GL_ACCT_FMT  = "101-10-{acct}-120-000-000"
ORG_CODE     = "V1"                          # inventory org


# ── Helpers ─────────────────────────────────────────────────────────────────

def connect():
    # DMT2 is Docker-only (no ATP). Target the local instance, honoring
    # DMT2_CONN like dmt_deploy.py / dmt_regression_run.py so the whole toolchain
    # points at the same database. (The old connect_atp('queryapp') target was
    # the FROZEN stack's ATP -- wrong for DMT2, and it silently loaded regression
    # data to the wrong database.)
    import os, re
    conn_str = os.environ.get('DMT2_CONN',
                              'dmt_owner/DmtLocal#2026@localhost:1523/FREEPDB1')
    m = re.match(r'^([^/]+)/(.+)@(?://)?(.+)$', conn_str)
    if not m:
        sys.exit(f"Cannot parse DMT2_CONN: {conn_str!r}")
    user, password, dsn = m.groups()
    return oracledb.connect(user=user, password=password, dsn=dsn)

ok_count = 0
err_count = 0

def run_sql(cur, sql, params=None, label=""):
    global ok_count, err_count
    try:
        cur.execute(sql, params or {})
        print(f"  OK  {label}")
        ok_count += 1
        return True
    except Exception as e:
        print(f"  ERR {label}: {e}")
        err_count += 1
        return False


def tag_scenario(cur, table, scenario_id, status_col="STG_STATUS"):
    """Update rows with no SCENARIO_ID and status NEW to the given scenario."""
    sql = f"""UPDATE DMT_OWNER.{table}
              SET SCENARIO_ID = :sid
              WHERE {status_col} = 'NEW' AND SCENARIO_ID IS NULL"""
    try:
        cur.execute(sql, {"sid": scenario_id})
        n = cur.rowcount
        print(f"  TAG {table}: {n} rows tagged with scenario {scenario_id}")
    except Exception as e:
        print(f"  ERR tagging {table}: {e}")


# ── Main ────────────────────────────────────────────────────────────────────

def main():
    print(f"Connecting to ATP...")
    conn = connect()
    cur  = conn.cursor()
    print("Connected.\n")

    # ── Get or create scenario ──────────────────────────────────────────────
    print(f"=== Scenario: {SCENARIO_NAME} ===")
    scenario_id_var = cur.var(oracledb.NUMBER)
    err_var = cur.var(oracledb.NUMBER)
    cur.execute("""
        BEGIN
            DMT_UTIL_PKG.GET_OR_CREATE_SCENARIO(
                p_scenario_name => :n,
                x_scenario_id   => :sid,
                x_error_code    => :err);
        END;
    """, sid=scenario_id_var, n=SCENARIO_NAME, err=err_var)
    err = err_var.getvalue()
    err = err[0] if isinstance(err, list) else err
    if err is None or int(err) != 0:
        sys.exit(f"GET_OR_CREATE_SCENARIO failed (x_error_code={err}); see DMT_LOG_TBL")
    val = scenario_id_var.getvalue()
    scenario_id = int(val[0]) if isinstance(val, list) else int(val)
    print(f"  Scenario ID: {scenario_id}\n")

    # ── Clean up existing scenario rows (idempotency) ──────────────────────
    # TFM tables have FK → STG, so TFM must be deleted first.
    # We delete ALL TFM rows whose STG_SEQUENCE_ID points to a scenario/RT- STG row.
    # Then delete STG rows.
    cleanup_tables = [
        # --- TFM tables first (FK children of STG) ---
        # Items (were missing from this list -- caused 15x STG-row accumulation
        #  across reloads because they were inserted+tagged but never cleaned)
        "DMT_EGP_ITEM_CAT_TFM_TBL",
        "DMT_EGP_ITEM_TFM_TBL",
        "DMT_EGP_ITEM_CAT_STG_TBL",
        "DMT_EGP_ITEM_STG_TBL",
        # Grants
        "DMT_GMS_AWD_PERSONNEL_TFM_TBL",
        "DMT_GMS_AWD_HDR_TFM_TBL",
        # Requisitions
        "DMT_POR_REQ_DISTS_TFM_TBL",
        "DMT_POR_REQ_LINES_TFM_TBL",
        "DMT_POR_REQ_HEADERS_TFM_TBL",
        # RCV
        "DMT_RCV_TRANSACTIONS_TFM_TBL",
        "DMT_RCV_HEADERS_TFM_TBL",
        # MiscReceipts (INV_TRX -- the pipeline's REAL tables; the RCV pair above are
        #  orphans). Were missing here, so INV_TRX STG accumulated across reloads
        #  (92 rows / 0 distinct source_ids observed), causing stale-duplicate
        #  failures on MiscReceipts runs -- same bug class as the Items 15x accumulation.
        "DMT_INV_TRX_SERIALS_TFM_TBL",
        "DMT_INV_TRX_LOTS_TFM_TBL",
        "DMT_INV_TRX_TFM_TBL",
        "DMT_INV_TRX_SERIALS_STG_TBL",
        "DMT_INV_TRX_LOTS_STG_TBL",
        "DMT_INV_TRX_STG_TBL",
        # Assets
        "DMT_FA_ASSET_ASSIGN_TFM_TBL",
        "DMT_FA_ASSET_BOOK_TFM_TBL",
        "DMT_FA_ASSET_HDR_TFM_TBL",
        # Projects
        "DMT_PJB_BILL_EVENTS_TFM_TBL",
        "DMT_PJC_EXPENDITURES_TFM_TBL",
        "DMT_PJC_TXN_CONTROLS_TFM_TBL",
        "DMT_PJF_TEAM_MEMBERS_TFM_TBL",
        "DMT_PJF_TASKS_TFM_TBL",
        "DMT_PJF_PROJECTS_TFM_TBL",
        # GL
        "DMT_PLAN_BUDGET_TFM_TBL",
        "DMT_GL_BUDGET_INT_TFM_TBL",
        "DMT_GL_INTERFACE_TFM_TBL",
        # Project Budgets
        "DMT_PRJ_BUDGET_TFM_TBL",
        # AR
        "DMT_RA_DISTS_TFM_TBL",
        "DMT_RA_LINES_TFM_TBL",
        # AP
        "DMT_AP_INVOICE_LINES_INT_TFM_TBL",
        "DMT_AP_INVOICES_INT_TFM_TBL",
        # PO
        "DMT_PO_DISTS_INT_TFM_TBL",
        "DMT_PO_LINE_LOCS_INT_TFM_TBL",
        "DMT_PO_LINES_INT_TFM_TBL",
        "DMT_PO_HEADERS_INT_TFM_TBL",
        # Customers
        "DMT_HZ_ACCT_SITE_USES_TFM_TBL",
        "DMT_HZ_ACCT_SITES_TFM_TBL",
        "DMT_HZ_ACCOUNTS_TFM_TBL",
        "DMT_HZ_PARTY_SITE_USES_TFM_TBL",
        "DMT_HZ_PARTY_SITES_TFM_TBL",
        "DMT_HZ_LOCATIONS_TFM_TBL",
        "DMT_HZ_PARTIES_TFM_TBL",
        # Suppliers
        "DMT_POZ_SUP_CONTACTS_TFM_TBL",
        "DMT_POZ_SUP_SITE_ASSN_TFM_TBL",
        "DMT_POZ_SUP_SITE_TFM_TBL",
        "DMT_POZ_SUP_ADDR_TFM_TBL",
        "DMT_POZ_SUPPLIERS_TFM_TBL",
        # --- STG tables (now safe to delete) ---
        # Grants personnel
        "DMT_GMS_AWD_PERSONNEL_STG_TBL",
        # Requisition dists → lines → headers
        "DMT_POR_REQ_DISTS_STG_TBL",
        "DMT_POR_REQ_LINES_STG_TBL",
        "DMT_POR_REQ_HEADERS_STG_TBL",
        # RCV transactions → headers
        "DMT_RCV_TRANSACTIONS_STG_TBL",
        "DMT_RCV_HEADERS_STG_TBL",
        # Asset assignments → books → headers
        "DMT_FA_ASSET_ASSIGN_STG_TBL",
        "DMT_FA_ASSET_BOOK_STG_TBL",
        "DMT_FA_ASSET_HDR_STG_TBL",
        # Grants
        "DMT_GMS_AWD_HEADERS_STG_TBL",
        # Project billing/expenditures/controls/members/tasks/projects
        "DMT_PJB_BILL_EVENTS_STG_TBL",
        "DMT_PJC_EXPENDITURES_STG_TBL",
        "DMT_PJC_TXN_CONTROLS_STG_TBL",
        "DMT_PJF_TEAM_MEMBERS_STG_TBL",
        "DMT_PJF_TASKS_STG_TBL",
        "DMT_PJF_PROJECTS_STG_TBL",
        # GL
        "DMT_PLAN_BUDGET_STG_TBL",
        "DMT_GL_BUDGET_INT_STG_TBL",
        "DMT_GL_INTERFACE_STG_TBL",
        # Project Budgets
        "DMT_PRJ_BUDGET_STG_TBL",
        # AR
        "DMT_RA_LINES_STG_TBL",
        # AP lines → invoices
        "DMT_AP_INVOICE_LINES_INT_STG_TBL",
        "DMT_AP_INVOICES_INT_STG_TBL",
        # PO dists → locs → lines → headers
        "DMT_PO_DISTS_INT_STG_TBL",
        "DMT_PO_LINE_LOCS_INT_STG_TBL",
        "DMT_PO_LINES_INT_STG_TBL",
        "DMT_PO_HEADERS_INT_STG_TBL",
        # Customer site uses → sites → accounts → party sites → party site uses → locations → parties
        "DMT_HZ_ACCT_SITE_USES_STG_TBL",
        "DMT_HZ_ACCT_SITES_STG_TBL",
        "DMT_HZ_ACCOUNTS_STG_TBL",
        "DMT_HZ_PARTY_SITE_USES_STG_TBL",
        "DMT_HZ_PARTY_SITES_STG_TBL",
        "DMT_HZ_LOCATIONS_STG_TBL",
        "DMT_HZ_PARTIES_STG_TBL",
        # Supplier contacts → site assns → sites → addresses → suppliers
        "DMT_POZ_SUP_CONTACTS_STG_TBL",
        "DMT_POZ_SUP_SITE_ASSN_STG_TBL",
        "DMT_POZ_SUP_SITE_STG_TBL",
        "DMT_POZ_SUP_ADDR_STG_TBL",
        "DMT_POZ_SUPPLIERS_STG_TBL",
    ]
    print("=== Cleaning up existing scenario rows ===")
    total_deleted = 0
    for tbl in cleanup_tables:
        is_tfm = "_TFM_" in tbl
        try:
            if is_tfm:
                # TFM tables don't have SCENARIO_ID/SOURCE_ID — delete by
                # joining to STG parent via STG_SEQUENCE_ID.
                # Derive STG table name: replace _TFM_ with _STG_
                stg_tbl = tbl.replace("_TFM_", "_STG_")
                cur.execute(
                    f"""DELETE FROM DMT_OWNER.{tbl}
                        WHERE STG_SEQUENCE_ID IN (
                            SELECT STG_SEQUENCE_ID FROM DMT_OWNER.{stg_tbl}
                            WHERE SCENARIO_ID = :sid OR SOURCE_ID LIKE 'RT-%'
                        )""",
                    {"sid": scenario_id})
            else:
                cur.execute(
                    f"DELETE FROM DMT_OWNER.{tbl} WHERE SCENARIO_ID = :sid OR SOURCE_ID LIKE 'RT-%'",
                    {"sid": scenario_id})
            n = cur.rowcount
            if n > 0:
                print(f"  DEL {tbl}: {n} rows")
                total_deleted += n
        except Exception as e:
            # Table might not exist or column mismatch — skip silently
            pass
    conn.commit()
    print(f"  Total deleted: {total_deleted}\n")

    # ====================================================================
    # 1. SUPPLIERS (DMT_POZ_SUPPLIERS_STG_TBL)
    #    GOOD: 2 valid suppliers
    #    BAD:  1 missing VENDOR_NAME (required)
    # ====================================================================
    print("=== 1. Suppliers ===")
    for vname, seg in [
        ("RT Supplier Good-1", "RT-SUP-G1"),
        ("RT Supplier Good-2", "RT-SUP-G2"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL (
                IMPORT_ACTION, VENDOR_NAME, SEGMENT1,
                ORGANIZATION_TYPE_LOOKUP_CODE, BUSINESS_RELATIONSHIP,
                VENDOR_TYPE_LOOKUP_CODE, SOURCE_ID
            ) VALUES (
                'CREATE', :vname, :seg,
                'CORPORATION', 'SPEND_AUTHORIZED',
                'SUPPLIER', :src
            )
        """, {"vname": vname, "seg": seg, "src": f"RT-{seg}"},
        label=f"GOOD Supplier: {vname}")

    # BAD: invalid ORGANIZATION_TYPE (should fail Fusion validation)
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL (
            IMPORT_ACTION, VENDOR_NAME, SEGMENT1,
            ORGANIZATION_TYPE_LOOKUP_CODE, BUSINESS_RELATIONSHIP,
            VENDOR_TYPE_LOOKUP_CODE, SOURCE_ID
        ) VALUES (
            'CREATE', 'RT Supplier Bad-1', 'RT-SUP-BAD1',
            'INVALID_ORG_TYPE', 'SPEND_AUTHORIZED',
            'SUPPLIER', 'RT-SUP-BAD1'
        )
    """, label="BAD Supplier: invalid ORGANIZATION_TYPE [BAD-LKP]")

    # Pre-existing Fusion supplier — exists in Fusion, not migrated by DMT.
    # Marked LOADED so BPA/CPA pre-validation passes.
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL (
            VENDOR_NAME, SEGMENT1, STG_STATUS, SOURCE_ID
        ) VALUES (
            :vname, :vnum, 'LOADED', 'FUSION_PREEXISTING'
        )
    """, {"vname": EXISTING_SUP, "vnum": EXISTING_SUP_NUM},
    label=f"PRE-EXISTING Supplier: {EXISTING_SUP} (LOADED)")
    tag_scenario(cur, "DMT_POZ_SUPPLIERS_STG_TBL", scenario_id)

    # ====================================================================
    # 2. SUPPLIER ADDRESSES (DMT_POZ_SUP_ADDR_STG_TBL)
    #    GOOD: 2 addresses for good suppliers
    #    BAD:  1 address for non-existent supplier [BAD-UPS]
    # ====================================================================
    print("\n=== 2. Supplier Addresses ===")
    for vname, site_name, addr, city, state, zipcode in [
        ("RT Supplier Good-1", "RT Good-1 HQ", "100 Good St",   "New York",    "NY", "10001"),
        ("RT Supplier Good-2", "RT Good-2 HQ", "200 Good Ave",  "Los Angeles", "CA", "90001"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_POZ_SUP_ADDR_STG_TBL (
                IMPORT_ACTION, VENDOR_NAME, PARTY_SITE_NAME,
                COUNTRY, ADDRESS_LINE1, CITY, STATE, POSTAL_CODE,
                RFQ_OR_BIDDING_PURPOSE_FLAG, SOURCE_ID
            ) VALUES (
                'CREATE', :vname, :psname,
                'US', :addr, :city, :st, :zip,
                'Y', :src
            )
        """, {"vname": vname, "psname": site_name, "addr": addr,
              "city": city, "st": state, "zip": zipcode,
              "src": f"RT-ADDR-{site_name}"},
        label=f"GOOD Address: {vname} / {site_name}")

    # BAD: address for non-existent supplier
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_POZ_SUP_ADDR_STG_TBL (
            IMPORT_ACTION, VENDOR_NAME, PARTY_SITE_NAME,
            COUNTRY, ADDRESS_LINE1, CITY, STATE, POSTAL_CODE,
            RFQ_OR_BIDDING_PURPOSE_FLAG, SOURCE_ID
        ) VALUES (
            'CREATE', 'DOES NOT EXIST SUPPLIER', 'Ghost HQ',
            'US', '999 Nowhere', 'Void', 'XX', '00000',
            'Y', 'RT-ADDR-BAD1'
        )
    """, label="BAD Address: non-existent supplier [BAD-UPS]")
    tag_scenario(cur, "DMT_POZ_SUP_ADDR_STG_TBL", scenario_id)

    # ====================================================================
    # 3. SUPPLIER SITES (DMT_POZ_SUP_SITE_STG_TBL)
    #    GOOD: 2 sites for good suppliers
    #    BAD:  1 site for non-existent supplier [BAD-UPS]
    # ====================================================================
    print("\n=== 3. Supplier Sites ===")
    for vname, psname, site_code in [
        ("RT Supplier Good-1", "RT Good-1 HQ", "RT-SITE-G1"),
        ("RT Supplier Good-2", "RT Good-2 HQ", "RT-SITE-G2"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_POZ_SUP_SITE_STG_TBL (
                IMPORT_ACTION, VENDOR_NAME,
                PROCUREMENT_BUSINESS_UNIT_NAME, PARTY_SITE_NAME,
                VENDOR_SITE_CODE, PURCHASING_SITE_FLAG, PAY_SITE_FLAG,
                SOURCE_ID
            ) VALUES (
                'CREATE', :vname,
                :bu, :psname,
                :scode, 'Y', 'Y', :src
            )
        """, {"vname": vname, "bu": BU, "psname": psname,
              "scode": site_code, "src": f"RT-SITE-{site_code}"},
        label=f"GOOD Site: {vname} / {site_code}")

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_POZ_SUP_SITE_STG_TBL (
            IMPORT_ACTION, VENDOR_NAME,
            PROCUREMENT_BUSINESS_UNIT_NAME, PARTY_SITE_NAME,
            VENDOR_SITE_CODE, PURCHASING_SITE_FLAG, PAY_SITE_FLAG,
            SOURCE_ID
        ) VALUES (
            'CREATE', 'DOES NOT EXIST SUPPLIER',
            :bu, 'Ghost HQ',
            'RT-SITE-BAD1', 'Y', 'Y', 'RT-SITE-BAD1'
        )
    """, {"bu": BU}, label="BAD Site: non-existent supplier [BAD-UPS]")

    # Pre-existing site for Allied Manufacturing
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_POZ_SUP_SITE_STG_TBL (
            VENDOR_NAME, VENDOR_SITE_CODE, PROCUREMENT_BUSINESS_UNIT_NAME,
            PARTY_SITE_NAME, STG_STATUS, SOURCE_ID
        ) VALUES (
            :vname, :vsite, :bu, :vsite, 'LOADED', 'FUSION_PREEXISTING'
        )
    """, {"vname": EXISTING_SUP, "vsite": EXISTING_SUP_SITE, "bu": BU},
    label=f"PRE-EXISTING Site: {EXISTING_SUP} / {EXISTING_SUP_SITE} (LOADED)")
    tag_scenario(cur, "DMT_POZ_SUP_SITE_STG_TBL", scenario_id)

    # ====================================================================
    # 4. SUPPLIER SITE ASSIGNMENTS (DMT_POZ_SUP_SITE_ASSN_STG_TBL)
    #    GOOD: 2 assignments for good sites
    #    BAD:  1 missing BUSINESS_UNIT_NAME [BAD-REQ]
    # ====================================================================
    print("\n=== 4. Supplier Site Assignments ===")
    for vname, site_code in [
        ("RT Supplier Good-1", "RT-SITE-G1"),
        ("RT Supplier Good-2", "RT-SITE-G2"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_STG_TBL (
                IMPORT_ACTION, VENDOR_NAME, VENDOR_SITE_CODE,
                PROCUREMENT_BUSINESS_UNIT_NAME, BUSINESS_UNIT_NAME,
                SOURCE_ID
            ) VALUES (
                'CREATE', :vname, :scode,
                :bu, :bu, :src
            )
        """, {"vname": vname, "scode": site_code, "bu": BU,
              "src": f"RT-ASSN-{site_code}"},
        label=f"GOOD Assignment: {vname} / {site_code}")

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_STG_TBL (
            IMPORT_ACTION, VENDOR_NAME, VENDOR_SITE_CODE,
            PROCUREMENT_BUSINESS_UNIT_NAME, BUSINESS_UNIT_NAME,
            SOURCE_ID
        ) VALUES (
            'CREATE', 'RT Supplier Good-1', 'RT-SITE-G1',
            :bu, 'NONEXISTENT BU', 'RT-ASSN-BAD1'
        )
    """, {"bu": BU}, label="BAD Assignment: invalid BUSINESS_UNIT_NAME [BAD-LKP]")

    # Pre-existing site assignment for Allied Manufacturing
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_STG_TBL (
            VENDOR_NAME, VENDOR_SITE_CODE,
            PROCUREMENT_BUSINESS_UNIT_NAME, BUSINESS_UNIT_NAME,
            STG_STATUS, SOURCE_ID
        ) VALUES (
            :vname, :vsite, :bu, :bu, 'LOADED', 'FUSION_PREEXISTING'
        )
    """, {"vname": EXISTING_SUP, "vsite": EXISTING_SUP_SITE, "bu": BU},
    label=f"PRE-EXISTING Site Assignment: {EXISTING_SUP} / {EXISTING_SUP_SITE} (LOADED)")
    tag_scenario(cur, "DMT_POZ_SUP_SITE_ASSN_STG_TBL", scenario_id)

    # ====================================================================
    # 5. SUPPLIER CONTACTS (DMT_POZ_SUP_CONTACTS_STG_TBL)
    #    GOOD: 2 contacts
    #    BAD:  1 contact for non-existent supplier [BAD-UPS]
    # ====================================================================
    print("\n=== 5. Supplier Contacts ===")
    for vname, fname, lname, email in [
        ("RT Supplier Good-1", "Alice", "Good",  "alice@good1.test"),
        ("RT Supplier Good-2", "Bob",   "Good",  "bob@good2.test"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_POZ_SUP_CONTACTS_STG_TBL (
                IMPORT_ACTION, VENDOR_NAME,
                FIRST_NAME, LAST_NAME, EMAIL_ADDRESS,
                PRIMARY_ADMIN_CONTACT, SOURCE_ID
            ) VALUES (
                'CREATE', :vname,
                :fn, :ln, :email,
                'Y', :src
            )
        """, {"vname": vname, "fn": fname, "ln": lname,
              "email": email, "src": f"RT-CON-{fname}{lname}"},
        label=f"GOOD Contact: {fname} {lname}")

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_POZ_SUP_CONTACTS_STG_TBL (
            IMPORT_ACTION, VENDOR_NAME,
            FIRST_NAME, LAST_NAME, EMAIL_ADDRESS,
            PRIMARY_ADMIN_CONTACT, SOURCE_ID
        ) VALUES (
            'CREATE', 'DOES NOT EXIST SUPPLIER',
            'Ghost', 'Contact', 'ghost@nowhere.test',
            'Y', 'RT-CON-BAD1'
        )
    """, label="BAD Contact: non-existent supplier [BAD-UPS]")
    tag_scenario(cur, "DMT_POZ_SUP_CONTACTS_STG_TBL", scenario_id)

    # ====================================================================
    # 6. CUSTOMER PARTIES (DMT_HZ_PARTIES_STG_TBL)
    #    GOOD: 2 customers
    #    BAD:  1 invalid PARTY_TYPE [BAD-LKP]
    # ====================================================================
    print("\n=== 6. Customer Parties ===")
    # Synthetic, self-unique organization names. Fusion's duplicate detection
    # fuzzy-matches on name against ALL existing parties (the demo instance is
    # full of real-looking names -- e.g. dozens of "*Anderson*"), and holds a
    # potential match as a warning instead of creating it. Embedding the unique
    # ORIG_SYSTEM_REFERENCE in the name (plus the run prefix the transform adds)
    # guarantees it matches nothing and loads cleanly. Distinct per row too.
    for org_name, ref in [
        ("Blorptech Widgets", "RT-CUST-G1"),
        ("Fnargle Systems", "RT-CUST-G2"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_HZ_PARTIES_STG_TBL (
                PARTY_ORIG_SYSTEM, PARTY_ORIG_SYSTEM_REFERENCE,
                INSERT_UPDATE_FLAG, PARTY_TYPE,
                ORGANIZATION_NAME, SOURCE_ID
            ) VALUES (
                'LEG1', :ref, 'I', 'ORGANIZATION',
                :oname, :src
            )
        """, {"ref": ref, "oname": org_name, "src": f"RT-PTY-{ref}"},
        label=f"GOOD Party: {org_name}")

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_HZ_PARTIES_STG_TBL (
            PARTY_ORIG_SYSTEM, PARTY_ORIG_SYSTEM_REFERENCE,
            INSERT_UPDATE_FLAG, PARTY_TYPE,
            ORGANIZATION_NAME, SOURCE_ID
        ) VALUES (
            'LEG1', 'RT-CUST-BAD1', 'I', 'INVALID_TYPE',
            'RT Customer Bad-1', 'RT-PTY-BAD1'
        )
    """, label="BAD Party: invalid PARTY_TYPE [BAD-LKP]")
    tag_scenario(cur, "DMT_HZ_PARTIES_STG_TBL", scenario_id)

    # ====================================================================
    # 7. CUSTOMER LOCATIONS (DMT_HZ_LOCATIONS_STG_TBL)
    # ====================================================================
    print("\n=== 7. Customer Locations ===")
    for loc_ref, addr, city, state, zipcode in [
        ("RT-LOC-G1", "100 Good Blvd",  "New York",    "NY", "10001"),
        ("RT-LOC-G2", "200 Good Lane",  "Los Angeles", "CA", "90001"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_HZ_LOCATIONS_STG_TBL (
                LOCATION_ORIG_SYSTEM, LOCATION_ORIG_SYSTEM_REFERENCE,
                INSERT_UPDATE_FLAG, COUNTRY,
                ADDRESS1, CITY, STATE, POSTAL_CODE, SOURCE_ID
            ) VALUES (
                'LEG1', :lref, 'I', 'US',
                :addr, :city, :st, :zip, :src
            )
        """, {"lref": loc_ref, "addr": addr, "city": city,
              "st": state, "zip": zipcode, "src": f"RT-LOC-{loc_ref}"},
        label=f"GOOD Location: {loc_ref}")

    # BAD: missing COUNTRY (required)
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_HZ_LOCATIONS_STG_TBL (
            LOCATION_ORIG_SYSTEM, LOCATION_ORIG_SYSTEM_REFERENCE,
            INSERT_UPDATE_FLAG, COUNTRY,
            ADDRESS1, CITY, STATE, POSTAL_CODE, SOURCE_ID
        ) VALUES (
            'LEG1', 'RT-LOC-BAD1', 'I', NULL,
            '999 Bad Ave', 'Nowhere', 'XX', '00000', 'RT-LOC-BAD1'
        )
    """, label="BAD Location: missing COUNTRY [BAD-REQ]")
    tag_scenario(cur, "DMT_HZ_LOCATIONS_STG_TBL", scenario_id)

    # ====================================================================
    # 8. CUSTOMER PARTY SITES (DMT_HZ_PARTY_SITES_STG_TBL)
    #    GOOD: 2 party sites
    #    BAD:  1 referencing non-existent party [BAD-UPS]
    # ====================================================================
    print("\n=== 8. Customer Party Sites ===")
    for pty_ref, site_ref, loc_ref, site_name in [
        ("RT-CUST-G1", "RT-PSITE-G1", "RT-LOC-G1", "RT Good-1 Office"),
        ("RT-CUST-G2", "RT-PSITE-G2", "RT-LOC-G2", "RT Good-2 Office"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_HZ_PARTY_SITES_STG_TBL (
                PARTY_ORIG_SYSTEM, PARTY_ORIG_SYSTEM_REFERENCE,
                SITE_ORIG_SYSTEM, SITE_ORIG_SYSTEM_REFERENCE,
                LOCATION_ORIG_SYSTEM, LOCATION_ORIG_SYSTEM_REFERENCE,
                INSERT_UPDATE_FLAG, PARTY_SITE_NAME, SOURCE_ID
            ) VALUES (
                'LEG1', :pty_ref,
                'LEG1', :site_ref,
                'LEG1', :loc_ref,
                'I', :sname, :src
            )
        """, {"pty_ref": pty_ref, "site_ref": site_ref, "loc_ref": loc_ref,
              "sname": site_name, "src": f"RT-PSITE-{site_ref}"},
        label=f"GOOD Party Site: {site_name}")

    # BAD: party site referencing non-existent party
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_HZ_PARTY_SITES_STG_TBL (
            PARTY_ORIG_SYSTEM, PARTY_ORIG_SYSTEM_REFERENCE,
            SITE_ORIG_SYSTEM, SITE_ORIG_SYSTEM_REFERENCE,
            LOCATION_ORIG_SYSTEM, LOCATION_ORIG_SYSTEM_REFERENCE,
            INSERT_UPDATE_FLAG, PARTY_SITE_NAME, SOURCE_ID
        ) VALUES (
            'LEG1', 'RT-CUST-NONEXIST',
            'LEG1', 'RT-PSITE-BAD1',
            'LEG1', 'RT-LOC-G1',
            'I', 'RT Bad-1 Office', 'RT-PSITE-BAD1'
        )
    """, label="BAD Party Site: non-existent party [BAD-UPS]")
    tag_scenario(cur, "DMT_HZ_PARTY_SITES_STG_TBL", scenario_id)

    # ====================================================================
    # 9. CUSTOMER PARTY SITE USES (DMT_HZ_PARTY_SITE_USES_STG_TBL)
    #    GOOD: 2 party site uses
    #    BAD:  1 invalid SITE_USE_TYPE [BAD-LKP]
    # ====================================================================
    print("\n=== 9. Customer Party Site Uses ===")
    for pty_ref, site_ref, use_type in [
        ("RT-CUST-G1", "RT-PSITE-G1", "BILL_TO"),
        ("RT-CUST-G2", "RT-PSITE-G2", "BILL_TO"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_HZ_PARTY_SITE_USES_STG_TBL (
                PARTY_ORIG_SYSTEM, PARTY_ORIG_SYSTEM_REFERENCE,
                SITE_ORIG_SYSTEM, SITE_ORIG_SYSTEM_REFERENCE,
                SITE_USE_TYPE, PRIMARY_FLAG,
                INSERT_UPDATE_FLAG, SOURCE_ID
            ) VALUES (
                'LEG1', :pty_ref,
                'LEG1', :site_ref,
                :use_type, 'Y', 'I', :src
            )
        """, {"pty_ref": pty_ref, "site_ref": site_ref,
              "use_type": use_type, "src": f"RT-PSUSE-{site_ref}"},
        label=f"GOOD Party Site Use: {site_ref} ({use_type})")

    # BAD: invalid site use type
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_HZ_PARTY_SITE_USES_STG_TBL (
            PARTY_ORIG_SYSTEM, PARTY_ORIG_SYSTEM_REFERENCE,
            SITE_ORIG_SYSTEM, SITE_ORIG_SYSTEM_REFERENCE,
            SITE_USE_TYPE, PRIMARY_FLAG,
            INSERT_UPDATE_FLAG, SOURCE_ID
        ) VALUES (
            'LEG1', 'RT-CUST-G1',
            'LEG1', 'RT-PSITE-G1',
            'INVALID_USE', 'Y', 'I', 'RT-PSUSE-BAD1'
        )
    """, label="BAD Party Site Use: invalid SITE_USE_TYPE [BAD-LKP]")
    tag_scenario(cur, "DMT_HZ_PARTY_SITE_USES_STG_TBL", scenario_id)

    # ====================================================================
    # 10. CUSTOMER ACCOUNTS (DMT_HZ_ACCOUNTS_STG_TBL)
    #     GOOD: 2 accounts
    #     BAD:  1 referencing non-existent party [BAD-UPS]
    # ====================================================================
    print("\n=== 10. Customer Accounts ===")
    for acct_ref, pty_ref, acct_num, acct_name in [
        ("RT-ACCT-G1", "RT-CUST-G1", "RTG001", "RT Customer Good-1"),
        ("RT-ACCT-G2", "RT-CUST-G2", "RTG002", "RT Customer Good-2"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_HZ_ACCOUNTS_STG_TBL (
                CUST_ORIG_SYSTEM, CUST_ORIG_SYSTEM_REFERENCE,
                PARTY_ORIG_SYSTEM, PARTY_ORIG_SYSTEM_REFERENCE,
                ACCOUNT_NUMBER, INSERT_UPDATE_FLAG,
                CUSTOMER_TYPE, ACCOUNT_NAME, SOURCE_ID
            ) VALUES (
                'LEG1', :acct_ref,
                'LEG1', :pty_ref,
                :anum, 'I', 'R', :aname, :src
            )
        """, {"acct_ref": acct_ref, "pty_ref": pty_ref,
              "anum": acct_num, "aname": acct_name,
              "src": f"RT-ACCT-{acct_ref}"},
        label=f"GOOD Account: {acct_name}")

    # BAD: account referencing non-existent party
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_HZ_ACCOUNTS_STG_TBL (
            CUST_ORIG_SYSTEM, CUST_ORIG_SYSTEM_REFERENCE,
            PARTY_ORIG_SYSTEM, PARTY_ORIG_SYSTEM_REFERENCE,
            ACCOUNT_NUMBER, INSERT_UPDATE_FLAG,
            CUSTOMER_TYPE, ACCOUNT_NAME, SOURCE_ID
        ) VALUES (
            'LEG1', 'RT-ACCT-BAD1',
            'LEG1', 'RT-CUST-NONEXIST',
            'RTBAD01', 'I', 'R', 'RT Customer Bad-1', 'RT-ACCT-BAD1'
        )
    """, label="BAD Account: non-existent party [BAD-UPS]")
    tag_scenario(cur, "DMT_HZ_ACCOUNTS_STG_TBL", scenario_id)

    # ====================================================================
    # 11. CUSTOMER ACCOUNT SITES (DMT_HZ_ACCT_SITES_STG_TBL)
    #     GOOD: 2 account sites
    #     BAD:  1 referencing non-existent account [BAD-UPS]
    # ====================================================================
    print("\n=== 11. Customer Account Sites ===")
    for asite_ref, acct_ref, site_ref in [
        ("RT-ASITE-G1", "RT-ACCT-G1", "RT-PSITE-G1"),
        ("RT-ASITE-G2", "RT-ACCT-G2", "RT-PSITE-G2"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_HZ_ACCT_SITES_STG_TBL (
                CUST_ORIG_SYSTEM, CUST_ORIG_SYSTEM_REFERENCE,
                CUST_SITE_ORIG_SYSTEM, CUST_SITE_ORIG_SYS_REF,
                SITE_ORIG_SYSTEM, SITE_ORIG_SYSTEM_REFERENCE,
                INSERT_UPDATE_FLAG, SET_CODE, SOURCE_ID
            ) VALUES (
                'LEG1', :acct_ref,
                'LEG1', :asite_ref,
                'LEG1', :site_ref,
                'I', :bu, :src
            )
        """, {"acct_ref": acct_ref, "asite_ref": asite_ref,
              "site_ref": site_ref, "bu": BU,
              "src": f"RT-ASITE-{asite_ref}"},
        label=f"GOOD Account Site: {asite_ref}")

    # BAD: account site referencing non-existent account
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_HZ_ACCT_SITES_STG_TBL (
            CUST_ORIG_SYSTEM, CUST_ORIG_SYSTEM_REFERENCE,
            CUST_SITE_ORIG_SYSTEM, CUST_SITE_ORIG_SYS_REF,
            SITE_ORIG_SYSTEM, SITE_ORIG_SYSTEM_REFERENCE,
            INSERT_UPDATE_FLAG, SET_CODE, SOURCE_ID
        ) VALUES (
            'LEG1', 'RT-ACCT-NONEXIST',
            'LEG1', 'RT-ASITE-BAD1',
            'LEG1', 'RT-PSITE-G1',
            'I', :bu, 'RT-ASITE-BAD1'
        )
    """, {"bu": BU}, label="BAD Account Site: non-existent account [BAD-UPS]")
    tag_scenario(cur, "DMT_HZ_ACCT_SITES_STG_TBL", scenario_id)

    # ====================================================================
    # 12. CUSTOMER ACCOUNT SITE USES (DMT_HZ_ACCT_SITE_USES_STG_TBL)
    #     GOOD: 2 account site uses
    #     BAD:  1 invalid SITE_USE_CODE [BAD-LKP]
    # ====================================================================
    print("\n=== 12. Customer Account Site Uses ===")
    for use_ref, asite_ref, use_code in [
        ("RT-SITEUSE-G1", "RT-ASITE-G1", "BILL_TO"),
        ("RT-SITEUSE-G2", "RT-ASITE-G2", "BILL_TO"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_HZ_ACCT_SITE_USES_STG_TBL (
                CUST_SITE_ORIG_SYSTEM, CUST_SITE_ORIG_SYS_REF,
                CUST_SITEUSE_ORIG_SYSTEM, CUST_SITEUSE_ORIG_SYS_REF,
                SITE_USE_CODE, PRIMARY_FLAG,
                INSERT_UPDATE_FLAG, SET_CODE, SOURCE_ID
            ) VALUES (
                'LEG1', :asite_ref,
                'LEG1', :use_ref,
                :use_code, 'Y', 'I', :bu, :src
            )
        """, {"asite_ref": asite_ref, "use_ref": use_ref,
              "use_code": use_code, "bu": BU,
              "src": f"RT-SUSE-{use_ref}"},
        label=f"GOOD Account Site Use: {use_ref}")

    # BAD: invalid site use code
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_HZ_ACCT_SITE_USES_STG_TBL (
            CUST_SITE_ORIG_SYSTEM, CUST_SITE_ORIG_SYS_REF,
            CUST_SITEUSE_ORIG_SYSTEM, CUST_SITEUSE_ORIG_SYS_REF,
            SITE_USE_CODE, PRIMARY_FLAG,
            INSERT_UPDATE_FLAG, SET_CODE, SOURCE_ID
        ) VALUES (
            'LEG1', 'RT-ASITE-G1',
            'LEG1', 'RT-SITEUSE-BAD1',
            'INVALID_USE', 'Y', 'I', :bu, 'RT-SUSE-BAD1'
        )
    """, {"bu": BU}, label="BAD Account Site Use: invalid SITE_USE_CODE [BAD-LKP]")
    tag_scenario(cur, "DMT_HZ_ACCT_SITE_USES_STG_TBL", scenario_id)

    # ====================================================================
    # Customers: stamp the batch id (partition key).
    # BulkImportJob auto-creates the import batch from a 4-value ParameterList
    # whose first value is a Batch ID, so every customer staging row must carry
    # a BATCH_ID. Stamp one batch id across the 7 customer staging tables for
    # this scenario. Source system was set to LEG1 above (a source registered in
    # Fusion Trading Community Source Systems, so the bulk import accepts it).
    # ====================================================================
    CUST_BATCH_ID = 5001
    for _cust_tbl in (
        "DMT_HZ_PARTIES_STG_TBL", "DMT_HZ_LOCATIONS_STG_TBL",
        "DMT_HZ_PARTY_SITES_STG_TBL", "DMT_HZ_PARTY_SITE_USES_STG_TBL",
        "DMT_HZ_ACCOUNTS_STG_TBL", "DMT_HZ_ACCT_SITES_STG_TBL",
        "DMT_HZ_ACCT_SITE_USES_STG_TBL",
    ):
        run_sql(cur, f"""
            UPDATE DMT_OWNER.{_cust_tbl}
            SET    BATCH_ID = :bid
            WHERE  SCENARIO_ID = :sid AND BATCH_ID IS NULL
        """, {"bid": CUST_BATCH_ID, "sid": scenario_id},
        label=f"Stamp BATCH_ID {CUST_BATCH_ID} on {_cust_tbl}")

    # ====================================================================
    # 13. PO HEADERS (DMT_PO_HEADERS_INT_STG_TBL) — Standard POs
    #     GOOD: 2 POs against pre-existing supplier (Allied Mfg / 1265)
    #     BAD:  1 PO with non-existent supplier [BAD-UPS]
    # ====================================================================
    print("\n=== 13. PO Headers (Standard) ===")
    # Good POs reference the RT suppliers + sites that the Suppliers -> SupplierSites
    # chain loads in this SAME run (matching run prefix). PurchaseOrders therefore
    # only loads to the base tables as part of the P2P pipeline (after suppliers),
    # never standalone -- no supplier exists yet in a PO-only run.
    for hkey, po_num, vname, vnum, vsite in [
        ("RT-PO-G1", "RT-PO-001", "RT Supplier Good-1", "RT-SUP-G1", "RT-SITE-G1"),
        ("RT-PO-G2", "RT-PO-002", "RT Supplier Good-2", "RT-SUP-G2", "RT-SITE-G2"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL (
                INTERFACE_HEADER_KEY, ACTION, DOCUMENT_TYPE_CODE,
                BATCH_ID,
                STYLE_DISPLAY_NAME, PRC_BU_NAME, REQ_BU_NAME,
                SOLDTO_LE_NAME, BILLTO_BU_NAME,
                AGENT_NAME, CURRENCY_CODE,
                VENDOR_NAME, VENDOR_NUM, VENDOR_SITE_CODE,
                DOCUMENT_NUM, SOURCE_ID
            ) VALUES (
                :hkey, 'ORIGINAL', 'STANDARD',
                8001,
                'Purchase Order', :bu, :bu,
                'US1 Legal Entity', :bu,
                'Roth, Calvin', 'USD',
                :vname, :vnum, :vsite,
                :po_num, :src
            )
        """, {"hkey": hkey, "bu": BU, "vname": vname, "vnum": vnum,
              "vsite": vsite, "po_num": po_num,
              "src": f"RT-{hkey}"},
        label=f"GOOD PO Header: {po_num} (user BATCH_ID 8001)")

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL (
            INTERFACE_HEADER_KEY, ACTION, DOCUMENT_TYPE_CODE,
            STYLE_DISPLAY_NAME, PRC_BU_NAME, REQ_BU_NAME,
            SOLDTO_LE_NAME, BILLTO_BU_NAME,
            AGENT_NAME, CURRENCY_CODE,
            VENDOR_NAME, VENDOR_NUM, VENDOR_SITE_CODE,
            DOCUMENT_NUM, SOURCE_ID
        ) VALUES (
            'RT-PO-BAD1', 'ORIGINAL', 'STANDARD',
            'Purchase Order', :bu, :bu,
            'US1 Legal Entity', :bu,
            'Roth, Calvin', 'USD',
            'DOES NOT EXIST SUPPLIER', '99999', 'FAKE-SITE',
            'RT-PO-BAD1', 'RT-PO-BAD1'
        )
    """, {"bu": BU}, label="BAD PO Header: non-existent supplier [BAD-UPS]")
    tag_scenario(cur, "DMT_PO_HEADERS_INT_STG_TBL", scenario_id)

    # ====================================================================
    # 14. PO LINES (DMT_PO_LINES_INT_STG_TBL)
    # ====================================================================
    print("\n=== 14. PO Lines ===")
    for lkey, hkey, line_num, qty, price, desc in [
        ("RT-POL-G1", "RT-PO-G1", 1, 10, 100.00, "RT Test Item Line 1"),
        ("RT-POL-G2", "RT-PO-G2", 1, 5,  250.00, "RT Test Item Line 2"),
        ("RT-POL-BAD1", "RT-PO-BAD1", 1, 1, 50.00, "BAD: orphan line"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_PO_LINES_INT_STG_TBL (
                INTERFACE_LINE_KEY, INTERFACE_HEADER_KEY,
                ACTION, LINE_NUM, LINE_TYPE,
                ITEM_DESCRIPTION, QUANTITY, UNIT_OF_MEASURE, UNIT_PRICE,
                CATEGORY, SOURCE_ID
            ) VALUES (
                :lkey, :hkey,
                'ADD', :lnum, 'Goods',
                :descr, :qty, 'Each', :price,
                'Miscellaneous', :src
            )
        """, {"lkey": lkey, "hkey": hkey, "lnum": line_num,
              "descr": desc, "qty": qty, "price": price,
              "src": f"RT-{lkey}"},
        label=f"{'GOOD' if 'BAD' not in lkey else 'BAD'} PO Line: {lkey}")
    tag_scenario(cur, "DMT_PO_LINES_INT_STG_TBL", scenario_id)

    # ====================================================================
    # 15. PO LINE LOCATIONS (DMT_PO_LINE_LOCS_INT_STG_TBL)
    # ====================================================================
    print("\n=== 15. PO Line Locations ===")
    for llkey, lkey, ship_num, qty in [
        ("RT-POLL-G1", "RT-POL-G1", 1, 10),
        ("RT-POLL-G2", "RT-POL-G2", 1, 5),
        ("RT-POLL-BAD1", "RT-POL-BAD1", 1, 1),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_PO_LINE_LOCS_INT_STG_TBL (
                INTERFACE_LINE_LOCATION_KEY, INTERFACE_LINE_KEY,
                SHIPMENT_NUM, QUANTITY,
                DESTINATION_TYPE_CODE,
                NEED_BY_DATE, SOURCE_ID
            ) VALUES (
                :llkey, :lkey,
                :snum, :qty,
                'EXPENSE',
                DATE '2025-12-31', :src
            )
        """, {"llkey": llkey, "lkey": lkey, "snum": ship_num,
              "qty": qty, "src": f"RT-{llkey}"},
        label=f"{'GOOD' if 'BAD' not in llkey else 'BAD'} PO LL: {llkey}")
    tag_scenario(cur, "DMT_PO_LINE_LOCS_INT_STG_TBL", scenario_id)

    # ====================================================================
    # 16. PO DISTRIBUTIONS (DMT_PO_DISTS_INT_STG_TBL)
    # ====================================================================
    print("\n=== 16. PO Distributions ===")
    for dkey, llkey, dist_num, qty in [
        ("RT-POD-G1", "RT-POLL-G1", 1, 10),
        ("RT-POD-G2", "RT-POLL-G2", 1, 5),
        ("RT-POD-BAD1", "RT-POLL-BAD1", 1, 1),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_PO_DISTS_INT_STG_TBL (
                INTERFACE_DISTRIBUTION_KEY, INTERFACE_LINE_LOCATION_KEY,
                DISTRIBUTION_NUM, QUANTITY_ORDERED,
                CHARGE_ACCOUNT_SEGMENT1, CHARGE_ACCOUNT_SEGMENT2,
                CHARGE_ACCOUNT_SEGMENT3, CHARGE_ACCOUNT_SEGMENT4,
                CHARGE_ACCOUNT_SEGMENT5, CHARGE_ACCOUNT_SEGMENT6,
                SOURCE_ID
            ) VALUES (
                :dkey, :llkey,
                :dnum, :qty,
                '101', '10', '68010', '120', '000', '000',
                :src
            )
        """, {"dkey": dkey, "llkey": llkey, "dnum": dist_num,
              "qty": qty, "src": f"RT-{dkey}"},
        label=f"{'GOOD' if 'BAD' not in dkey else 'BAD'} PO Dist: {dkey}")
    tag_scenario(cur, "DMT_PO_DISTS_INT_STG_TBL", scenario_id)

    # ====================================================================
    # 17. AP INVOICES (DMT_AP_INVOICES_INT_STG_TBL)
    #     GOOD: 2 invoices against pre-existing Fusion supplier (JGA / 1254 / JGA US1)
    #           Proven valid from Fusion REST query on invoice JGA 2012155.
    #           Using pre-existing supplier avoids prefix mismatch issues.
    #     BAD:  1 with zero amount + non-existent supplier [BAD-AMT + BAD-UPS]
    # ====================================================================
    print("\n=== 17. AP Invoices ===")
    for inv_id, inv_num, amount in [
        (800001, "RT-APINV-G1", 1500.00),
        (800002, "RT-APINV-G2", 2750.00),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_AP_INVOICES_INT_STG_TBL (
                INVOICE_ID, OPERATING_UNIT, SOURCE,
                INVOICE_NUM, INVOICE_AMOUNT, INVOICE_DATE,
                VENDOR_NAME, VENDOR_NUM, VENDOR_SITE_CODE,
                INVOICE_CURRENCY_CODE, INVOICE_TYPE_LOOKUP_CODE,
                TERMS_NAME, GL_DATE, CALC_TAX_DURING_IMPORT_FLAG, SOURCE_ID
            ) VALUES (
                :iid, :bu, 'Manual Invoice Entry',
                :inum, :amt, SYSDATE,
                'JGA', '1254', 'JGA US1',
                'USD', 'STANDARD',
                'Immediate', SYSDATE, 'Y', :src
            )
        """, {"iid": inv_id, "bu": BU, "inum": inv_num, "amt": amount,
              "src": f"RT-{inv_num}"},
        label=f"GOOD AP Invoice: {inv_num} (${amount})")

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_AP_INVOICES_INT_STG_TBL (
            INVOICE_ID, OPERATING_UNIT, SOURCE,
            INVOICE_NUM, INVOICE_AMOUNT, INVOICE_DATE,
            VENDOR_NAME, VENDOR_NUM, VENDOR_SITE_CODE,
            INVOICE_CURRENCY_CODE, INVOICE_TYPE_LOOKUP_CODE,
            TERMS_NAME, GL_DATE, CALC_TAX_DURING_IMPORT_FLAG, SOURCE_ID
        ) VALUES (
            800099, :bu, 'Manual Invoice Entry',
            'RT-APINV-BAD1', 0, SYSDATE,
            'DOES NOT EXIST VENDOR', '99999', 'FAKE-SITE',
            'USD', 'STANDARD',
            'Immediate', SYSDATE, 'Y', 'RT-APINV-BAD1'
        )
    """, {"bu": BU},
    label="BAD AP Invoice: zero amount + bad vendor [BAD-AMT + BAD-UPS]")
    tag_scenario(cur, "DMT_AP_INVOICES_INT_STG_TBL", scenario_id)

    # ====================================================================
    # 18. AP INVOICE LINES (DMT_AP_INVOICE_LINES_INT_STG_TBL)
    # ====================================================================
    print("\n=== 18. AP Invoice Lines ===")
    # Dist account 101.10.65110.110.000.000 proven valid from Fusion invoice JGA 2012155
    for inv_id, line_num, amount, desc, dist_acct in [
        (800001, 1, 1500.00, "RT consulting services", "101.10.65110.110.000.000"),
        (800002, 1, 2750.00, "RT equipment purchase",  "101.10.65110.120.000.000"),
        (800099, 1, 0,       "BAD: zero amount line",  "101.10.65110.110.000.000"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_AP_INVOICE_LINES_INT_STG_TBL (
                INVOICE_ID, LINE_NUMBER, LINE_TYPE_LOOKUP_CODE,
                AMOUNT, DESCRIPTION,
                DIST_CODE_CONCATENATED, ACCOUNTING_DATE, SOURCE_ID
            ) VALUES (
                :iid, :lnum, 'ITEM',
                :amt, :descr,
                :dist, SYSDATE, :src
            )
        """, {"iid": inv_id, "lnum": line_num, "amt": amount,
              "descr": desc, "dist": dist_acct,
              "src": f"RT-APLN-{inv_id}-{line_num}"},
        label=f"{'GOOD' if inv_id < 800099 else 'BAD'} AP Line: Inv {inv_id}")
    tag_scenario(cur, "DMT_AP_INVOICE_LINES_INT_STG_TBL", scenario_id)

    # ====================================================================
    # 19. AR INVOICES (DMT_RA_LINES_STG_TBL)
    #     GOOD: 2 AR transactions against existing customer
    #     BAD:  1 with invalid customer account [BAD-LKP]
    # ====================================================================
    print("\n=== 19. AR Invoices ===")
    for trx_num, bill_acct, amount, desc in [
        ("RT-AR-G1", CUST_ACCT_NO, 3200.00, "RT professional services"),
        ("RT-AR-G2", CUST_ACCT_NO, 1800.00, "RT maintenance contract"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_RA_LINES_STG_TBL (
                BU_NAME, BATCH_SOURCE_NAME, CUST_TRX_TYPE_NAME,
                TERM_NAME, TRX_DATE, GL_DATE,
                TRX_NUMBER, BILL_CUSTOMER_ACCOUNT_NUMBER,
                LINE_TYPE, DESCRIPTION,
                CURRENCY_CODE, AMOUNT,
                INTERFACE_LINE_CONTEXT, INTERFACE_LINE_ATTRIBUTE1,
                INTERFACE_LINE_ATTRIBUTE2, SOURCE_ID
            ) VALUES (
                :bu, 'Manual-Other', 'Invoice',
                'Net 30', DATE '2025-06-15', DATE '2025-06-15',
                :trx, :bill_acct,
                'LINE', :descr,
                'USD', :amt,
                'LEGACY', :trx, '1', :src
            )
        """, {"bu": BU, "trx": trx_num, "bill_acct": bill_acct,
              "amt": amount, "descr": desc, "src": f"RT-{trx_num}"},
        label=f"GOOD AR Invoice: {trx_num}")

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_RA_LINES_STG_TBL (
            BU_NAME, BATCH_SOURCE_NAME, CUST_TRX_TYPE_NAME,
            TERM_NAME, TRX_DATE, GL_DATE,
            TRX_NUMBER, BILL_CUSTOMER_ACCOUNT_NUMBER,
            LINE_TYPE, DESCRIPTION,
            CURRENCY_CODE, AMOUNT,
            INTERFACE_LINE_CONTEXT, INTERFACE_LINE_ATTRIBUTE1,
            INTERFACE_LINE_ATTRIBUTE2, SOURCE_ID
        ) VALUES (
            :bu, 'Manual-Other', 'Invoice',
            'Net 30', DATE '2025-06-15', DATE '2025-06-15',
            'RT-AR-BAD1', '99999',
            'LINE', 'BAD: invalid customer account',
            'USD', 500.00,
            'LEGACY', 'RT-AR-BAD1', '1', 'RT-AR-BAD1'
        )
    """, {"bu": BU}, label="BAD AR Invoice: invalid customer acct [BAD-LKP]")
    tag_scenario(cur, "DMT_RA_LINES_STG_TBL", scenario_id)

    # ====================================================================
    # 20. GL JOURNALS (DMT_GL_INTERFACE_STG_TBL)
    #     GOOD: 1 balanced journal (2 lines: DR/CR)
    #     BAD:  1 unbalanced journal (DR only, no CR) [BAD-AMT]
    # ====================================================================
    print("\n=== 20. GL Journals ===")
    gl_lines = [
        # GOOD: balanced journal — proven LOADED in int=100000005
        # See objects/GLBalances/README.md: Category=Adjustment, Source=Spreadsheet,
        # Period=04-26, valid COA accounts: 78630, 77600
        ("NEW", LEDGER, date(2026, 4, 1), "Adjustment", "Spreadsheet",
         "78630", 5000.00, None,    "RT-JNL-G1", "RT good journal - debit",  "04-26"),
        ("NEW", LEDGER, date(2026, 4, 1), "Adjustment", "Spreadsheet",
         "77600", None,    5000.00, "RT-JNL-G1", "RT good journal - credit", "04-26"),
        # BAD: unbalanced (debit only)
        ("NEW", LEDGER, date(2026, 4, 1), "Adjustment", "Spreadsheet",
         "78630", 9999.99, None,    "RT-JNL-BAD1", "BAD: unbalanced debit only", "04-26"),
    ]
    for gl_status, ledger, acct_dt, cat, source, seg3, dr, cr, ref4, ref10, period in gl_lines:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_GL_INTERFACE_STG_TBL (
                JOURNAL_STATUS, LEDGER_NAME, ACCOUNTING_DATE,
                CURRENCY_CODE, ACTUAL_FLAG,
                USER_JE_CATEGORY_NAME, USER_JE_SOURCE_NAME,
                SEGMENT1, SEGMENT2, SEGMENT3,
                SEGMENT4, SEGMENT5, SEGMENT6,
                ENTERED_DR, ENTERED_CR,
                REFERENCE1, REFERENCE4, REFERENCE10,
                PERIOD_NAME, SOURCE_ID
            ) VALUES (
                :st, :ledger, :adt,
                'USD', 'A',
                :cat, :src_name,
                '101', '10', :seg3,
                '120', '000', '000',
                :dr, :cr,
                :ref4, :ref4, :ref10,
                :period, :sid
            )
        """, {"st": gl_status, "ledger": ledger, "adt": acct_dt,
              "cat": cat, "src_name": source, "seg3": seg3,
              "dr": dr, "cr": cr, "ref4": ref4, "ref10": ref10,
              "period": period, "sid": f"RT-GL-{ref4}-{seg3}"},
        label=f"{'GOOD' if 'BAD' not in ref4 else 'BAD'} GL: {ref4} seg3={seg3}")
    tag_scenario(cur, "DMT_GL_INTERFACE_STG_TBL", scenario_id)

    # ====================================================================
    # 21. GL BUDGET (DMT_GL_BUDGET_INT_STG_TBL)
    #     GOOD: 2 budget cells under Run Name 'Budget_EO_1' -> LOADED to GL_BUDGET_BALANCES
    #     BAD:  1 invalid budget name under 'Budget_EO_BAD' -> FAILED [BAD-LKP]
    #     Proven E2E in run 112 (2026-06-30): 4 LOADED / 1 FAILED, 0 unaccounted.
    #     Key facts: BUDGET_NAME must match an Accounting Scenario value ('Budget');
    #     period MM-YY ('06-26', open); LEDGER_ID populated (US Primary Ledger);
    #     the second ESS job (ValidateAndLoadBudgets) is submitted per distinct RUN_NAME.
    # ====================================================================
    print("\n=== 21. GL Budget ===")
    for seg3, seg4, amount in [
        ("77600", "120", 1000.00),
        ("60540", "120", 1000.00),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_GL_BUDGET_INT_STG_TBL (
                RUN_NAME, LEDGER_ID, BUDGET_NAME, PERIOD_NAME,
                CURRENCY_CODE, JOURNAL_STATUS,
                SEGMENT1, SEGMENT2, SEGMENT3,
                SEGMENT4, SEGMENT5, SEGMENT6,
                BUDGET_AMOUNT, LEDGER_NAME, SOURCE_ID
            ) VALUES (
                'Budget_EO_1', 300000046975971, 'Budget', '06-26',
                'USD', 'NEW',
                '101', '10', :seg3,
                :seg4, '000', '000',
                :amt, 'US Primary Ledger', :src
            )
        """, {"seg3": seg3, "seg4": seg4, "amt": amount,
              "src": f"RT-BUD-{seg3}"},
        label=f"GOOD GL Budget: 06-26/{seg3}")

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_GL_BUDGET_INT_STG_TBL (
            RUN_NAME, LEDGER_ID, BUDGET_NAME, PERIOD_NAME,
            CURRENCY_CODE, JOURNAL_STATUS,
            SEGMENT1, SEGMENT2, SEGMENT3,
            SEGMENT4, SEGMENT5, SEGMENT6,
            BUDGET_AMOUNT, LEDGER_NAME, SOURCE_ID
        ) VALUES (
            'Budget_EO_BAD', 300000046975971, 'NONEXISTENT BUDGET', '06-26',
            'USD', 'NEW',
            '101', '10', '77600',
            '120', '000', '000',
            500, 'US Primary Ledger', 'RT-BUD-BAD1'
        )
    """, label="BAD GL Budget: invalid budget name [BAD-LKP]")
    tag_scenario(cur, "DMT_GL_BUDGET_INT_STG_TBL", scenario_id)

    # ====================================================================
    # 22. PLANNING BUDGET (DMT_PLAN_BUDGET_STG_TBL)
    #     GOOD: 2 planning entries
    #     BAD:  1 missing ENTITY [BAD-REQ]
    # ====================================================================
    print("\n=== 22. Planning Budget ===")
    for scenario, version, entity, account, period, amount in [
        ("Forecast", "Version 1", "US1 Entity", "62010", "Jun-25", 45000.00),
        ("Forecast", "Version 1", "US1 Entity", "68010", "Jul-25", 60000.00),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_PLAN_BUDGET_STG_TBL (
                SCENARIO, VERSION, ENTITY, ACCOUNT,
                PERIOD, AMOUNT, CURRENCY, SOURCE_ID
            ) VALUES (
                :scn, :ver, :ent, :acct,
                :period, :amt, 'USD', :src
            )
        """, {"scn": scenario, "ver": version, "ent": entity,
              "acct": account, "period": period, "amt": amount,
              "src": f"RT-PLAN-{period}-{account}"},
        label=f"GOOD Planning: {period}/{account}")

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_PLAN_BUDGET_STG_TBL (
            SCENARIO, VERSION, ENTITY, ACCOUNT,
            PERIOD, AMOUNT, CURRENCY, SOURCE_ID
        ) VALUES (
            'Forecast', 'Version 1', NULL, '62010',
            'Jun-25', 10000, 'USD', 'RT-PLAN-BAD1'
        )
    """, label="BAD Planning: missing ENTITY [BAD-REQ]")
    tag_scenario(cur, "DMT_PLAN_BUDGET_STG_TBL", scenario_id)

    # ====================================================================
    # 23. PROJECTS (DMT_PJF_PROJECTS_STG_TBL)
    #     GOOD: 2 projects
    #     BAD:  1 missing ORGANIZATION_NAME [BAD-REQ]
    # ====================================================================
    print("\n=== 23. Projects ===")
    PRJ_ORG = "Maintenance Prg US"
    # Proven LOADED in int=100000034, prefix=9179 (all 9 rows).
    # See objects/Projects/README.md "Valid Test Data":
    #   SOURCE_APPLICATION_CODE must be NULL (not registered on demo instance)
    #   ORGANIZATION_NAME = 'Maintenance Prg US' (matches template PRGUS Sponsored)
    for pname, pnum, pdesc in [
        ("RT Project Good-1", "RTPRJ001", "RT test project one"),
        ("RT Project Good-2", "RTPRJ002", "RT test project two"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_PJF_PROJECTS_STG_TBL (
                PROJECT_NAME, PROJECT_NUMBER,
                SOURCE_TEMPLATE_NUMBER,
                ORGANIZATION_NAME, DESCRIPTION,
                PROJECT_START_DATE, PROJECT_FINISH_DATE,
                PROJECT_STATUS_NAME, PROJECT_CURRENCY_CODE, SOURCE_ID
            ) VALUES (
                :pname, :pnum,
                'PRGUS Sponsored',
                :org, :pdesc,
                DATE '2025-01-01', DATE '2025-12-31',
                'Active', 'USD', :src
            )
        """, {"pname": pname, "pnum": pnum, "org": PRJ_ORG,
              "pdesc": pdesc, "src": f"RT-PRJ-{pnum}"},
        label=f"GOOD Project: {pname}")

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_PJF_PROJECTS_STG_TBL (
            PROJECT_NAME, PROJECT_NUMBER,
            SOURCE_TEMPLATE_NUMBER,
            ORGANIZATION_NAME, DESCRIPTION,
            PROJECT_START_DATE, PROJECT_FINISH_DATE,
            PROJECT_STATUS_NAME, PROJECT_CURRENCY_CODE, SOURCE_ID
        ) VALUES (
            'RT Project Bad-1', 'RTPRJ-BAD1',
            'PRGUS Sponsored',
            NULL, 'BAD: missing org name',
            DATE '2025-01-01', DATE '2025-12-31',
            'Active', 'USD', 'RT-PRJ-BAD1'
        )
    """, label="BAD Project: missing ORGANIZATION_NAME [BAD-REQ]")
    tag_scenario(cur, "DMT_PJF_PROJECTS_STG_TBL", scenario_id)

    # ====================================================================
    # 24. PROJECT TASKS (DMT_PJF_TASKS_STG_TBL)
    #     GOOD: 2 tasks (1 per good project)
    #     BAD:  1 task for non-existent project [BAD-UPS]
    # ====================================================================
    print("\n=== 24. Project Tasks ===")
    for pname, pnum, tname, tnum in [
        ("RT Project Good-1", "RTPRJ001", "RT Design Phase",  "RTPRJ001.1"),
        ("RT Project Good-2", "RTPRJ002", "RT Build Phase",   "RTPRJ002.1"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_PJF_TASKS_STG_TBL (
                PROJECT_NAME, PROJECT_NUMBER,
                TASK_NAME, TASK_NUMBER,
                PLANNING_START_DATE, PLANNING_END_DATE,
                CHARGEABLE_FLAG, BILLABLE_FLAG,
                SOURCE_TASK_REFERENCE, SOURCE_ID
            ) VALUES (
                :pname, :pnum,
                :tname, :tnum,
                DATE '2025-01-01', DATE '2025-12-31',
                'Y', 'Y', :tnum, :src
            )
        """, {"pname": pname, "pnum": pnum, "tname": tname,
              "tnum": tnum, "src": f"RT-TSK-{tnum}"},
        label=f"GOOD Task: {tnum}")

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_PJF_TASKS_STG_TBL (
            PROJECT_NAME, PROJECT_NUMBER,
            TASK_NAME, TASK_NUMBER,
            PLANNING_START_DATE, PLANNING_END_DATE,
            CHARGEABLE_FLAG, BILLABLE_FLAG,
            SOURCE_TASK_REFERENCE, SOURCE_ID
        ) VALUES (
            'NONEXISTENT PROJECT', 'NOPROJ999',
            'Orphan Task', 'NOPROJ999.1',
            DATE '2025-01-01', DATE '2025-12-31',
            'Y', 'Y', 'NOPROJ999.1', 'RT-TSK-BAD1'
        )
    """, label="BAD Task: non-existent project [BAD-UPS]")
    tag_scenario(cur, "DMT_PJF_TASKS_STG_TBL", scenario_id)

    # ====================================================================
    # 25. PROJECT TEAM MEMBERS (DMT_PJF_TEAM_MEMBERS_STG_TBL)
    # ====================================================================
    print("\n=== 25. Project Team Members ===")
    # Persons must exist in Fusion — proven in int=100000034:
    # #7 Alan Cook, #10 Mandy Steward (objects/Projects/README.md "Valid Test Data")
    for pname, member_name, member_email, role in [
        ("RT Project Good-1", "Alan Cook",     "alan.cook_esew-dev28@oraclepdemos.com",    "Project Manager"),
        ("RT Project Good-2", "Mandy Steward", "mandy.steward_esew-dev28@oraclepdemos.com", "Project Manager"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_PJF_TEAM_MEMBERS_STG_TBL (
                PROJECT_NAME, TEAM_MEMBER_NAME, TEAM_MEMBER_EMAIL,
                PROJECT_ROLE_NAME, START_DATE_ACTIVE,
                TRACK_TIME_FLAG, SOURCE_ID
            ) VALUES (
                :pname, :mname, :memail,
                :role, DATE '2025-01-01',
                'Y', :src
            )
        """, {"pname": pname, "mname": member_name, "memail": member_email,
              "role": role, "src": f"RT-TM-{pname[:10]}-{member_name[:10]}"},
        label=f"GOOD Team Member: {member_name} on {pname}")
    tag_scenario(cur, "DMT_PJF_TEAM_MEMBERS_STG_TBL", scenario_id)

    # ====================================================================
    # 26. PROJECT TXN CONTROLS (DMT_PJC_TXN_CONTROLS_STG_TBL)
    # ====================================================================
    print("\n=== 26. Project Txn Controls ===")
    # Expenditure type proven in int=100000034 (objects/Projects/README.md)
    for pname, pnum, exp_type in [
        ("RT Project Good-1", "RTPRJ001", "Professional Services"),
        ("RT Project Good-2", "RTPRJ002", "Professional Services"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_PJC_TXN_CONTROLS_STG_TBL (
                TXN_CTRL_REFERENCE, PROJECT_NAME, PROJECT_NUMBER,
                EXPENDITURE_TYPE, CHARGEABLE_FLAG,
                START_DATE_ACTIVE, SOURCE_ID
            ) VALUES (
                :ref, :pname, :pnum,
                :etype, 'Y',
                DATE '2025-01-01', :src
            )
        """, {"ref": f"RT-TXC-{pnum}", "pname": pname, "pnum": pnum,
              "etype": exp_type, "src": f"RT-TXC-{pnum}"},
        label=f"GOOD Txn Control: {pnum}/{exp_type}")
    tag_scenario(cur, "DMT_PJC_TXN_CONTROLS_STG_TBL", scenario_id)

    # ====================================================================
    # 27. EXPENDITURES (DMT_PJC_EXPENDITURES_STG_TBL)
    #     GOOD: 2 expenditures — proven LOADED in int=100000040, prefix=9184
    #           See objects/Expenditures/README.md: LABOR, Person=7/10, Administrative
    #     BAD:  1 for non-existent project [BAD-UPS]
    # ====================================================================
    print("\n=== 27. Expenditures ===")
    for proj_num, task_num, person_num, qty, amount in [
        ("RTPRJ001", "RTPRJ001.1", "7",  8,  1500.00),
        ("RTPRJ002", "RTPRJ002.1", "10", 16, 2500.00),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_PJC_EXPENDITURES_STG_TBL (
                TRANSACTION_TYPE, BUSINESS_UNIT,
                PROJECT_NUMBER, TASK_NUMBER,
                EXPENDITURE_TYPE, EXPENDITURE_ITEM_DATE,
                ORGANIZATION_NAME, PERSON_NUMBER, QUANTITY,
                DENOM_CURRENCY_CODE, DENOM_RAW_COST,
                ORIG_TRANSACTION_REFERENCE, SOURCE_ID
            ) VALUES (
                'LABOR', :bu,
                :pnum, :tnum,
                'Administrative', DATE '2025-06-15',
                :bu, :pnum2, :qty,
                'USD', :amt,
                :ref, :src
            )
        """, {"bu": BU, "pnum": proj_num, "tnum": task_num,
              "pnum2": person_num, "qty": qty, "amt": amount,
              "ref": f"RT-EXP-{proj_num}", "src": f"RT-EXP-{proj_num}"},
        label=f"GOOD Expenditure: {proj_num}/{task_num}")

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_PJC_EXPENDITURES_STG_TBL (
            TRANSACTION_TYPE, BUSINESS_UNIT,
            PROJECT_NUMBER, TASK_NUMBER,
            EXPENDITURE_TYPE, EXPENDITURE_ITEM_DATE,
            ORGANIZATION_NAME, PERSON_NUMBER, QUANTITY,
            DENOM_CURRENCY_CODE, DENOM_RAW_COST,
            ORIG_TRANSACTION_REFERENCE, SOURCE_ID
        ) VALUES (
            'LABOR', :bu,
            'NOPROJ999', 'NOPROJ999.1',
            'Administrative', DATE '2025-06-15',
            :bu, '7', 8,
            'USD', 999.99,
            'RT-EXP-BAD1', 'RT-EXP-BAD1'
        )
    """, {"bu": BU}, label="BAD Expenditure: non-existent project [BAD-UPS]")
    tag_scenario(cur, "DMT_PJC_EXPENDITURES_STG_TBL", scenario_id)

    # ====================================================================
    # 28. BILLING EVENTS (DMT_PJB_BILL_EVENTS_STG_TBL)
    #     GOOD: 2 billing events — contracts C10028/C10001 with their ACTUAL
    #           linked projects (PCS10028/PCS10001) from pjb_cntrct_proj_links.
    #           Project numbers are NOT prefixed — they're pre-existing Fusion projects.
    #     BAD:  1 missing CONTRACT_NUMBER [BAD-REQ]
    # ====================================================================
    print("\n=== 28. Billing Events ===")
    # EVENT_TYPE_NAME must match PJB_EVENT_TYPES on the instance.
    # Valid values (from REST projectBillingEvents): 'Percent Complete Billing', 'Percent Spent Billing'
    # 'Manual' does NOT exist on this instance — causes PJB_EVT_INVALID_TYPE.
    # TaskNumber is NULL on all existing billing events — omit or pass NULL.
    for src_ref, contract_num, contract_line, proj_num, task_num, evt_type, amount in [
        ("RT-BE-G1", "C10028", "1", "PCS10028", None, "Percent Complete Billing", 5000.00),
        ("RT-BE-G2", "C10001", "1", "PCS10001", None, "Percent Spent Billing", 7500.00),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_PJB_BILL_EVENTS_STG_TBL (
                SOURCENAME, SOURCEREF, ORGANIZATION_NAME,
                CONTRACT_TYPE_NAME, CONTRACT_NUMBER, CONTRACT_LINE_NUMBER,
                EVENT_TYPE_NAME, EVENT_DESC,
                COMPLETION_DATE, BILL_TRNS_CURRENCY_CODE, BILL_TRNS_AMOUNT,
                PROJECT_NUMBER, TASK_NUMBER, SOURCE_ID
            ) VALUES (
                'Manual Invoice Entry', :ref, :bu,
                'Sell: Project Lines Soft Limit', :cnum, :cline,
                :etype, 'RT billing event',
                DATE '2025-06-15', 'USD', :amt,
                :pnum, :tnum, :src
            )
        """, {"ref": src_ref, "bu": BU, "cnum": contract_num,
              "cline": contract_line, "etype": evt_type, "pnum": proj_num,
              "tnum": task_num, "amt": amount, "src": f"RT-{src_ref}"},
        label=f"GOOD Billing Event: {src_ref}")

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_PJB_BILL_EVENTS_STG_TBL (
            SOURCENAME, SOURCEREF, ORGANIZATION_NAME,
            CONTRACT_TYPE_NAME, CONTRACT_NUMBER, CONTRACT_LINE_NUMBER,
            EVENT_TYPE_NAME, EVENT_DESC,
            COMPLETION_DATE, BILL_TRNS_CURRENCY_CODE, BILL_TRNS_AMOUNT,
            PROJECT_NUMBER, TASK_NUMBER, SOURCE_ID
        ) VALUES (
            'Manual Invoice Entry', 'RT-BE-BAD1', :bu,
            'Sell: Project Lines Soft Limit', NULL, '1',
            'Percent Complete Billing', 'BAD: missing contract number',
            DATE '2025-06-15', 'USD', 1000.00,
            'PCS10028', '2', 'RT-BE-BAD1'
        )
    """, {"bu": BU}, label="BAD Billing Event: missing CONTRACT_NUMBER [BAD-REQ]")
    tag_scenario(cur, "DMT_PJB_BILL_EVENTS_STG_TBL", scenario_id)

    # ====================================================================
    # 28a. PROJECT BUDGETS (DMT_PRJ_BUDGET_STG_TBL)
    #     GOOD: 2 budget lines against the RT projects loaded earlier in
    #           the same run. Plan type / period format / currency proven
    #           E2E LOADED 2026-04-01 (int=100000027, prefix=9123,
    #           objects/ProjectBudgets/README.md). Transform applies the
    #           run prefix to PROJECT_NUMBER/NAME to match the migrated
    #           Fusion projects.
    #     BAD:  1 for non-existent project [BAD-UPS] — fails
    #           pre-validation (PROJECT_NAME not LOADED in projects STG).
    # ====================================================================
    print("\n=== 28a. Project Budgets ===")
    for pnum, pname, period, amount in [
        ("RTPRJ001", "RT Project Good-1", "01-25", 50000.00),
        ("RTPRJ002", "RT Project Good-2", "02-25", 75000.00),
    ]:
        # PLAN_VERSION_STATUS is mandatory on the refreshed instance
        # (PJO_XFACE_NO_VER_STATUS rejection in run 115, import job 9697704).
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_PRJ_BUDGET_STG_TBL (
                FINANCIAL_PLAN_TYPE, PROJECT_NUMBER, PROJECT_NAME,
                PLAN_VERSION_NAME, PLAN_VERSION_STATUS, PERIOD_NAME, PLANNING_CURRENCY,
                TOTAL_TC_RAW_COST, SRC_BUDGET_LINE_REFERENCE, SOURCE_ID
            ) VALUES (
                'Approved Cost Budget', :pnum, :pname,
                'Version 1', 'Working', :period, 'USD',
                :amt, :ref, :src
            )
        """, {"pnum": pnum, "pname": pname, "period": period,
              "amt": amount, "ref": f"RT-PJB-{pnum}", "src": f"RT-PJB-{pnum}"},
        label=f"GOOD Project Budget: {pnum}/{period}")

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_PRJ_BUDGET_STG_TBL (
            FINANCIAL_PLAN_TYPE, PROJECT_NUMBER, PROJECT_NAME,
            PLAN_VERSION_NAME, PLAN_VERSION_STATUS, PERIOD_NAME, PLANNING_CURRENCY,
            TOTAL_TC_RAW_COST, SRC_BUDGET_LINE_REFERENCE, SOURCE_ID
        ) VALUES (
            'Approved Cost Budget', 'NOPROJ999', 'RT NoSuch Project',
            'Version 1', 'Working', '01-25', 'USD',
            999.99, 'RT-PJB-BAD1', 'RT-PJB-BAD1'
        )
    """, label="BAD Project Budget: non-existent project [BAD-UPS]")
    tag_scenario(cur, "DMT_PRJ_BUDGET_STG_TBL", scenario_id)

    # ====================================================================
    # 29. GRANTS (DMT_GMS_AWD_HEADERS_STG_TBL)
    #     GOOD: 2 grant awards
    #     BAD:  1 missing BUSINESS_UNIT [BAD-REQ]
    # ====================================================================
    print("\n=== 29. Grants ===")
    GRANTS_BU = "Progress US Business Unit"
    GRANTS_LE = "Progress US Legal Entity"
    GRANTS_TEMPLATE = "1 Year Award"
    GRANTS_CONTRACT_TYPE = "Sell: Project Award Hard Limit"
    for awd_name, awd_num, sponsor in [
        ("RT Grant Good-1", "RTGNT001", "Department of Homeland Security"),
        ("RT Grant Good-2", "RTGNT002", "Environmental Protection Agency"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_GMS_AWD_HEADERS_STG_TBL (
                AWARD_NAME, AWARD_NUMBER,
                SOURCE_TEMPLATE_NUMBER,
                BUSINESS_UNIT, LEGAL_ENTITY,
                CONTRACT_TYPE, PRIMARY_SPONSOR,
                AWARD_START_DATE, AWARD_END_DATE,
                AWARD_DESCRIPTION, CURRENCY_CODE, SOURCE_ID
            ) VALUES (
                :aname, :anum,
                :tmpl,
                :bu, :le,
                :ctype, :sponsor,
                DATE '2025-01-01', DATE '2025-12-31',
                'RT test grant award', 'USD', :src
            )
        """, {"aname": awd_name, "anum": awd_num, "tmpl": GRANTS_TEMPLATE,
              "bu": GRANTS_BU, "le": GRANTS_LE, "ctype": GRANTS_CONTRACT_TYPE,
              "sponsor": sponsor, "src": f"RT-GNT-{awd_num}"},
        label=f"GOOD Grant: {awd_name}")

    # Insert personnel (PI required for each award)
    for awd_num in ("RTGNT001", "RTGNT002"):
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_GMS_AWD_PERSONNEL_STG_TBL (
                AWARD_NUMBER, INTERNAL, PERSON_EMAIL,
                PERSON_NAME, PERSON_NUMBER, ROLE,
                START_DATE, CREDIT_PERCENTAGE, SOURCE_ID
            ) VALUES (
                :anum, 'Y', 'sean.murphy_esew-dev28@oraclepdemos.com',
                'Sean Murphy', '1171', 'Principal Investigator',
                DATE '2025-01-01', 100, :src
            )
        """, {"anum": awd_num, "src": f"RT-GNT-PERS-{awd_num}"},
        label=f"GOOD Grant Personnel (PI): {awd_num}")
    tag_scenario(cur, "DMT_GMS_AWD_PERSONNEL_STG_TBL", scenario_id)

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_GMS_AWD_HEADERS_STG_TBL (
            AWARD_NAME, AWARD_NUMBER,
            SOURCE_TEMPLATE_NUMBER,
            BUSINESS_UNIT, LEGAL_ENTITY,
            CONTRACT_TYPE, PRIMARY_SPONSOR,
            AWARD_START_DATE, AWARD_END_DATE,
            AWARD_DESCRIPTION, CURRENCY_CODE, SOURCE_ID
        ) VALUES (
            'RT Grant Bad-1', 'RTGNT-BAD1',
            :tmpl,
            NULL, :le,
            :ctype, 'Department of Homeland Security',
            DATE '2025-01-01', DATE '2025-12-31',
            'BAD: missing business unit', 'USD', 'RT-GNT-BAD1'
        )
    """, {"tmpl": GRANTS_TEMPLATE, "le": GRANTS_LE,
          "ctype": GRANTS_CONTRACT_TYPE},
    label="BAD Grant: missing BUSINESS_UNIT [BAD-REQ]")
    tag_scenario(cur, "DMT_GMS_AWD_HEADERS_STG_TBL", scenario_id)

    # ====================================================================
    # 30. ASSETS (DMT_FA_ASSET_HDR_STG_TBL)
    #     GOOD: 2 assets (E2E LOADED — run 105/106, 2026-06-29)
    #     BAD:  1 with an invalid (balance-sheet) expense account [BAD-FUSION]
    #     Proven values (validated against fa_additions_b):
    #       category EQUIPMENT/MANUFACTURING, prorate CAL MONTH, US CORP book,
    #       expense acct 101.10.68130.000.000.000, location USA/NEW YORK/NEW YORK,
    #       DPIS 2025-06-01. Fusion HONORS the supplied (prefixed) ASSET_NUMBER.
    #     BAD row uses natural account 15160 (balance sheet) -> PrepareMassAdditions
    #       rejects it per-record: "You must enter a valid expense account ID."
    #       (Oracle does PER-RECORD accounting, not all-or-nothing per FBDI.)
    # ====================================================================
    print("\n=== 30. Assets (Headers) ===")
    for asset_num, desc in [
        ("RT-ASSET-G1", "RT Test Equipment 1"),
        ("RT-ASSET-G2", "RT Test Equipment 2"),
        ("RT-ASSET-BAD1", "BAD: invalid expense account"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_FA_ASSET_HDR_STG_TBL (
                ASSET_NUMBER, DESCRIPTION,
                ASSET_CATEGORY_SEGMENT1, ASSET_CATEGORY_SEGMENT2,
                ASSET_TYPE, MANUFACTURER_NAME, SERIAL_NUMBER, MODEL_NUMBER,
                IN_USE_FLAG, OWNED_LEASED, NEW_USED,
                DATE_PLACED_IN_SERVICE, SOURCE_ID
            ) VALUES (
                :anum, :descr,
                'EQUIPMENT', 'MANUFACTURING',
                'CAPITALIZED', 'TUA', :serial, 'Exclusive',
                'YES', 'OWNED', 'NEW',
                DATE '2025-06-01', :src
            )
        """, {"anum": asset_num, "descr": desc, "serial": f"{asset_num}-SN",
              "src": f"RT-FA-{asset_num}"},
        label=("BAD" if "BAD" in asset_num else "GOOD") + f" Asset: {asset_num}")
    tag_scenario(cur, "DMT_FA_ASSET_HDR_STG_TBL", scenario_id)

    # ====================================================================
    # 31. ASSET BOOKS (DMT_FA_ASSET_BOOK_STG_TBL)
    # ====================================================================
    print("\n=== 31. Asset Books ===")
    for asset_num, book, cost, life in [
        ("RT-ASSET-G1", "US CORP", 120000.00, 120),
        ("RT-ASSET-G2", "US CORP", 35000.00, 60),
        ("RT-ASSET-BAD1", "US CORP", 1000.00, 36),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_FA_ASSET_BOOK_STG_TBL (
                ASSET_NUMBER, BOOK_TYPE_CODE,
                COST, ORIGINAL_COST, SALVAGE_VALUE,
                LIFE_IN_MONTHS, DEPRECIATION_METHOD,
                DATE_PLACED_IN_SERVICE, PRORATE_CONVENTION_CODE,
                CURRENT_UNITS, SOURCE_ID
            ) VALUES (
                :anum, :book,
                :cost, :cost, 0,
                :life, 'STL',
                DATE '2025-06-01', 'CAL MONTH',
                1, :src
            )
        """, {"anum": asset_num, "book": book, "cost": cost,
              "life": life, "src": f"RT-FABK-{asset_num}"},
        label=f"Asset Book: {asset_num}/{book}")
    tag_scenario(cur, "DMT_FA_ASSET_BOOK_STG_TBL", scenario_id)

    # ====================================================================
    # 32. ASSET ASSIGNMENTS (DMT_FA_ASSET_ASSIGN_STG_TBL)
    # ====================================================================
    print("\n=== 32. Asset Assignments ===")
    # exp3 = natural account. 68130 = valid expense (GOOD). 15160 = balance-sheet
    # account -> PrepareMassAdditions rejects per-record (BAD). Location NEW YORK.
    for asset_num, exp3, loc1, loc2, loc3 in [
        ("RT-ASSET-G1", "68130", "USA", "NEW YORK", "NEW YORK"),
        ("RT-ASSET-G2", "68130", "USA", "NEW YORK", "NEW YORK"),
        ("RT-ASSET-BAD1", "15160", "USA", "NEW YORK", "NEW YORK"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_FA_ASSET_ASSIGN_STG_TBL (
                ASSET_NUMBER, UNITS_ASSIGNED,
                LOCATION_SEGMENT1, LOCATION_SEGMENT2, LOCATION_SEGMENT3,
                EXPENSE_ACCOUNT_SEGMENT1, EXPENSE_ACCOUNT_SEGMENT2,
                EXPENSE_ACCOUNT_SEGMENT3, EXPENSE_ACCOUNT_SEGMENT4,
                EXPENSE_ACCOUNT_SEGMENT5, EXPENSE_ACCOUNT_SEGMENT6,
                SOURCE_ID
            ) VALUES (
                :anum, 1,
                :loc1, :loc2, :loc3,
                '101', '10', :exp3, '000', '000', '000',
                :src
            )
        """, {"anum": asset_num, "exp3": exp3, "loc1": loc1, "loc2": loc2,
              "loc3": loc3, "src": f"RT-FAASGN-{asset_num}"},
        label=f"Asset Assignment: {asset_num}")
    tag_scenario(cur, "DMT_FA_ASSET_ASSIGN_STG_TBL", scenario_id)

    # ====================================================================
    # 32a. ITEMS (DMT_EGP_ITEM_STG_TBL)
    #      GOOD: 3 items — plain, serial-controlled, lot-controlled — in org 000 (master)
    #      BAD:  1 item with invalid org code [BAD-LKP]
    #      Item class: Root Item Class (proven E2E LOADED)
    #      UOM: Each (ECH) — not Ea/zzu
    #      Attributes copied from LOADED DMT-PLAIN-G1, DMT-SERIAL-G1, DMT-LOT-G1
    # ====================================================================
    MASTER_ORG = "000"  # Operations master org (items must be created here first)
    INV_ORG = "001"    # Seattle inventory org (used by MiscReceipts below)
    print("\n=== 32a. Items ===")
    # Two user batch ids (8101, 8102) prove the batch passthrough + partition:
    # each batch generates its own FBDI zip and its own Item Import ESS run, and
    # each batch carries a GOOD item that must reach the base tables.
    for item_num, descr, org, uom, lot_code, serial_code, batch, label in [
        ("DMT-RT-PLAIN-001",  "DMT Regression Plain Item",   MASTER_ORG, "Each", 1, 1, 8101, "GOOD: plain item (no lot/serial) batch 8101"),
        ("DMT-RT-SERIAL-001", "DMT Regression Serial Item",  MASTER_ORG, "Each", 1, 5, 8102, "GOOD: serial-controlled item batch 8102"),
        ("DMT-RT-LOT-001",    "DMT Regression Lot Item",     MASTER_ORG, "Each", 2, 1, 8102, "GOOD: lot-controlled item batch 8102"),
        ("DMT-RT-BAD-001",    "DMT Bad Item Invalid Org",    "ZZZ",      "Each", 1, 1, 8101, "BAD: invalid org code [BAD-LKP] batch 8101"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_EGP_ITEM_STG_TBL (
                TRANSACTION_TYPE, ORGANIZATION_CODE, ITEM_NUMBER, BATCH_ID,
                DESCRIPTION, PRIMARY_UOM_CODE, ITEM_CLASS_NAME,
                INVENTORY_ITEM_STATUS_CODE, CURRENT_PHASE_CODE, ITEM_TYPE,
                INVENTORY_ITEM_FLAG, STOCK_ENABLED_FLAG,
                MTL_TRANSACTIONS_ENABLED_FLAG, PURCHASING_ENABLED_FLAG,
                PURCHASING_ITEM_FLAG, CUSTOMER_ORDER_FLAG,
                CUSTOMER_ORDER_ENABLED_FLAG, SHIPPABLE_ITEM_FLAG,
                RETURNABLE_FLAG, INTERNAL_ORDER_FLAG, INTERNAL_ORDER_ENABLED_FLAG,
                COSTING_ENABLED_FLAG, BUILD_IN_WIP_FLAG,
                LOT_CONTROL_CODE, SERIAL_NUMBER_CONTROL_CODE,
                PLANNING_MAKE_BUY_CODE,
                SOURCE_SYSTEM_CODE, SOURCE_SYSTEM_REFERENCE,
                SOURCE_ID
            ) VALUES (
                'CREATE', :org, :item, :batch,
                :descr, :uom, 'Root Item Class',
                'Active', 'Production', 'FG',
                'Y', 'Y',
                'Y', 'Y',
                'Y', 'Y',
                'Y', 'Y',
                'Y', 'Y', 'Y',
                'Y', 'Y',
                :lot_code, :serial_code,
                2,
                'DMT', :item || '_' || :org,
                :src
            )
        """, {"org": org, "item": item_num, "batch": batch, "descr": descr, "uom": uom,
              "lot_code": lot_code, "serial_code": serial_code,
              "src": f"RT-ITEM-{item_num}"},
        label=f"{label}: {item_num}")
    tag_scenario(cur, "DMT_EGP_ITEM_STG_TBL", scenario_id)

    # ====================================================================
    # 32b. ITEM CATEGORIES (DMT_EGP_ITEM_CAT_STG_TBL)
    #      GOOD: 3 category assignments — one per GOOD item (all 3 types)
    #      BAD:  1 assignment referencing nonexistent item + fake category set [BAD-UPS]
    #      Bundled with Items in same FBDI ZIP under ItemImportJobDef.
    #      Category set "Purchasing" (ID 10000), code "999.99" verified on demo instance.
    # ====================================================================
    print("\n=== 32b. Item Categories ===")
    # Category BATCH_ID matches its item's batch so an item and its category land
    # in the same batch group (both transforms use NVL(s.BATCH_ID, run_id)).
    for item_num, org, cat_set, cat_code, cat_name, batch, label in [
        ("DMT-RT-PLAIN-001",  MASTER_ORG, "Purchasing", "999.99",    "999.99 Miscellaneous", 8101,
         "GOOD: Purchasing category for plain item"),
        ("DMT-RT-SERIAL-001", MASTER_ORG, "Purchasing", "204.54",    "204.54 Laptops", 8102,
         "GOOD: Purchasing category for serial item"),
        ("DMT-RT-LOT-001",    MASTER_ORG, "Purchasing", "206.61",    "206.61 Monitors", 8102,
         "GOOD: Purchasing category for lot item"),
        ("NONEXISTENT-DMT-ITEM", MASTER_ORG, "FAKE_SET", "ZZZ", "BAD Category", 8101,
         "BAD: nonexistent item + fake category set [BAD-UPS]"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_EGP_ITEM_CAT_STG_TBL (
                TRANSACTION_TYPE, ORGANIZATION_CODE, ITEM_NUMBER, BATCH_ID,
                CATEGORY_SET_NAME, CATEGORY_CODE, CATEGORY_NAME,
                SOURCE_SYSTEM_CODE, SOURCE_SYSTEM_REFERENCE,
                SOURCE_ID
            ) VALUES (
                'CREATE', :org, :item, :batch,
                :cat_set, :cat_code, :cat_name,
                'DMT', :item || '_' || :org || '_' || :cat_set,
                :src
            )
        """, {"org": org, "item": item_num, "batch": batch, "cat_set": cat_set,
              "cat_code": cat_code, "cat_name": cat_name,
              "src": f"RT-ITEMCAT-{item_num}"},
        label=f"{label}")
    tag_scenario(cur, "DMT_EGP_ITEM_CAT_STG_TBL", scenario_id)

    # ====================================================================
    # 33. MISC RECEIPTS / RCV HEADERS (DMT_RCV_HEADERS_STG_TBL)
    #     GOOD: 2 receipt headers — org 001 (Seattle)
    #     BAD:  1 missing SHIP_TO_ORGANIZATION_CODE [BAD-REQ]
    #     Items must be LOADED before receipts can run.
    # ====================================================================
    # ====================================================================
    # 33. INV TRANSACTIONS (DMT_INV_TRX_STG_TBL) — MiscReceipts
    #     Miscellaneous Receipt via INV_TRANSACTIONS_INTERFACE.
    #     GOOD rows use Vision demo items (AS55001, AS15000) already in org 001.
    #     Transformer defaults: Miscellaneous Receipt, Inventory, USE_CURRENT_COST=Y.
    #     TRANSACTION_UNIT_OF_MEASURE must be 'Each' (not UOM code 'Ea').
    #     Verified E2E 2026-05-26: GOOD=LOADED with FUSION_ID, BAD=FAILED INV_INVALID_ITEM.
    # ====================================================================
    print("\n=== 33. Inventory Transactions (MiscReceipts) ===")
    # Plain items (no lot/serial)
    for item_num, qty, label in [
        ("AS55001", 5, "GOOD: 5 Each of AS55001 (plain, no lot/serial)"),
        ("FAKE-ITEM-REGRESSION-BAD", 1, "BAD: nonexistent item [BAD-REQ]"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_INV_TRX_STG_TBL (
                ORGANIZATION_NAME, ITEM_NUMBER, SUBINVENTORY_CODE,
                TRANSACTION_QUANTITY, TRANSACTION_UNIT_OF_MEASURE,
                TRANSACTION_DATE,
                STAGE_DATE, STG_STATUS
            ) VALUES (
                'Seattle', :item, 'Stores',
                :qty, 'Each',
                SYSDATE,
                SYSDATE, 'NEW'
            )
        """, {"item": item_num, "qty": qty},
        label=label)

    # Lot-controlled item: RA-100-4935-LOT in Seattle
    # Parent txn needs INV_LOTSERIAL_INTERFACE_NUM to link to child lot row
    # Get STG sequence for the parent so we can reference it from the lot child
    cur.execute("SELECT DMT_OWNER.DMT_INV_TRX_STG_SEQ.NEXTVAL FROM DUAL")
    lot_parent_seq = cur.fetchone()[0]
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_INV_TRX_STG_TBL (
            STG_SEQUENCE_ID,
            ORGANIZATION_NAME, ITEM_NUMBER, SUBINVENTORY_CODE,
            TRANSACTION_QUANTITY, TRANSACTION_UNIT_OF_MEASURE,
            TRANSACTION_DATE,
            INV_LOTSERIAL_INTERFACE_NUM,
            STAGE_DATE, STG_STATUS
        ) VALUES (
            :seq,
            'Seattle', 'RA-100-4935-LOT', 'Stores',
            3, 'Each',
            SYSDATE,
            TO_CHAR(:seq),
            SYSDATE, 'NEW'
        )
    """, {"seq": lot_parent_seq},
    label="GOOD: 3 Each of RA-100-4935-LOT (lot-controlled)")

    # Lot child row — INVENTORY_LOT_INTERFACE_NUMBER must match parent's INV_LOTSERIAL_INTERFACE_NUM
    # SOURCE_ID = parent STG_SEQUENCE_ID (for generator join)
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_INV_TRX_LOTS_STG_TBL (
            INVENTORY_LOT_INTERFACE_NUMBER, SOURCE_CODE, SOURCE_LINE_ID,
            LOT_NUMBER, TRANSACTION_QUANTITY,
            SOURCE_ID, STAGE_DATE, STG_STATUS
        ) VALUES (
            TO_CHAR(:pseq), 'DMT', :pseq,
            'DMT-REG-LOT-001', 3,
            TO_CHAR(:pseq), SYSDATE, 'NEW'
        )
    """, {"pseq": lot_parent_seq},
    label="  -> Lot child: DMT-REG-LOT-001, qty 3")

    # Serial-controlled item: AS88000 in Seattle (serial_number_control_code=5, at receipt)
    cur.execute("SELECT DMT_OWNER.DMT_INV_TRX_STG_SEQ.NEXTVAL FROM DUAL")
    ser_parent_seq = cur.fetchone()[0]
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_INV_TRX_STG_TBL (
            STG_SEQUENCE_ID,
            ORGANIZATION_NAME, ITEM_NUMBER, SUBINVENTORY_CODE,
            TRANSACTION_QUANTITY, TRANSACTION_UNIT_OF_MEASURE,
            TRANSACTION_DATE,
            INV_LOTSERIAL_INTERFACE_NUM,
            STAGE_DATE, STG_STATUS
        ) VALUES (
            :seq,
            'Seattle', 'AS88000', 'Stores',
            2, 'Each',
            SYSDATE,
            TO_CHAR(:seq),
            SYSDATE, 'NEW'
        )
    """, {"seq": ser_parent_seq},
    label="GOOD: 2 Each of AS88000 (serial-controlled)")

    # Serial child row — SOURCE_ID = parent STG_SEQUENCE_ID (for generator join)
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_INV_TRX_SERIALS_STG_TBL (
            FM_SERIAL_NUMBER, TO_SERIAL_NUMBER,
            SOURCE_ID, STAGE_DATE, STG_STATUS
        ) VALUES (
            'DMT-REG-SER-001', 'DMT-REG-SER-002',
            TO_CHAR(:pseq), SYSDATE, 'NEW'
        )
    """, {"pseq": ser_parent_seq},
    label="  -> Serial child: DMT-REG-SER-001 to 002")

    tag_scenario(cur, "DMT_INV_TRX_STG_TBL", scenario_id)
    tag_scenario(cur, "DMT_INV_TRX_LOTS_STG_TBL", scenario_id)
    tag_scenario(cur, "DMT_INV_TRX_SERIALS_STG_TBL", scenario_id)

    # ====================================================================
    # 35. REQUISITIONS HEADERS (DMT_POR_REQ_HEADERS_STG_TBL)
    #     Verified 2026-04-16: 1 GOOD + 3 BAD (header/line/dist errors)
    #     All values proven on demo instance.
    # ====================================================================
    print("\n=== 35. Requisition Headers ===")
    REQ_PREPARER = "CALVIN.ROTH_esew-dev28@oraclepdemos.com"
    # Two user-supplied batch ids prove the batch passthrough + partition:
    # each batch generates its own FBDI and its own Import Requisitions ESS run,
    # and each batch carries a GOOD requisition that must reach the base tables.
    REQ_BATCH_A = 7001
    REQ_BATCH_B = 7002
    for hkey, batch, req_num, preparer, descr, label in [
        ("RT-REQ-G1",      REQ_BATCH_A, "RT-REQ-001", REQ_PREPARER,
         "GOOD: should load successfully", "GOOD Requisition [LOADED] batch 7001"),
        ("RT-REQ-BADHDR",  REQ_BATCH_A, "RT-REQ-BADHDR", "NONEXISTENT_USER@fake.com",
         "BAD HDR: invalid preparer email", "BAD Requisition: [HDR] error batch 7001"),
        ("RT-REQ-G2",      REQ_BATCH_B, "RT-REQ-002", REQ_PREPARER,
         "GOOD: second batch, should load successfully", "GOOD Requisition [LOADED] batch 7002"),
        ("RT-REQ-BADLINE", REQ_BATCH_B, "RT-REQ-BADLINE", REQ_PREPARER,
         "BAD LINE: valid hdr, bad UOM on line", "BAD Requisition: [LINE] error batch 7002"),
        ("RT-REQ-BADDIST", REQ_BATCH_B, "RT-REQ-BADDIST", REQ_PREPARER,
         "BAD DIST: valid hdr+line, bad charge acct", "BAD Requisition: [DIST] error batch 7002"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_POR_REQ_HEADERS_STG_TBL (
                INTERFACE_HEADER_KEY, INTERFACE_SOURCE_CODE,
                BATCH_ID,
                REQ_BU_NAME, PRC_BU_NAME,
                REQUISITION_NUMBER, DOCUMENT_STATUS,
                PREPARER_EMAIL_ADDR,
                DESCRIPTION, SOURCE_ID
            ) VALUES (
                :hkey, 'Manual Invoice Entry',
                :batch,
                :bu, :bu,
                :rnum, 'APPROVED',
                :prep,
                :descr, :src
            )
        """, {"hkey": hkey, "batch": batch, "bu": BU, "rnum": req_num,
              "prep": preparer, "descr": descr, "src": f"RT-{hkey}"},
        label=label)
    tag_scenario(cur, "DMT_POR_REQ_HEADERS_STG_TBL", scenario_id)

    # ====================================================================
    # 36. REQUISITION LINES (DMT_POR_REQ_LINES_STG_TBL)
    #     Verified 2026-04-16: UOM=ECH, location=Louisville
    # ====================================================================
    print("\n=== 36. Requisition Lines ===")
    for lkey, hkey, qty, price, desc, uom in [
        ("RT-REQL-G1",      "RT-REQ-G1",      10, 25.00,  "Office supplies",    "ECH"),
        ("RT-REQL-BADHDR",  "RT-REQ-BADHDR",   5, 50.00,  "Office supplies",    "ECH"),
        ("RT-REQL-G2",      "RT-REQ-G2",       8, 30.00,  "Office supplies",    "ECH"),
        ("RT-REQL-BADLINE", "RT-REQ-BADLINE",   3, 100.00, "Bad UOM item",       "ZZZ"),
        ("RT-REQL-BADDIST", "RT-REQ-BADDIST",   2, 75.00,  "Good line bad dist", "ECH"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_POR_REQ_LINES_STG_TBL (
                INTERFACE_LINE_KEY, INTERFACE_HEADER_KEY,
                DESTINATION_TYPE_CODE, DELIVER_TO_LOCATION_CODE,
                ITEM_DESCRIPTION, CATEGORY_NAME,
                NEED_BY_DATE, LINE_TYPE,
                QUANTITY, CURRENCY_CODE, CURRENCY_UNIT_PRICE,
                UOM_CODE,
                REQUESTER_EMAIL_ADDR, SOURCE_ID
            ) VALUES (
                :lkey, :hkey,
                'EXPENSE', 'Louisville',
                :descr, 'Miscellaneous',
                '2026/12/31', 'Goods',
                :qty, 'USD', :price,
                :uom,
                :prep, :src
            )
        """, {"lkey": lkey, "hkey": hkey, "descr": desc,
              "qty": qty, "price": price, "uom": uom,
              "prep": REQ_PREPARER, "src": f"RT-{lkey}"},
        label=f"Req Line: {lkey}")
    tag_scenario(cur, "DMT_POR_REQ_LINES_STG_TBL", scenario_id)

    # ====================================================================
    # 37. REQUISITION DISTRIBUTIONS (DMT_POR_REQ_DISTS_STG_TBL)
    #     Verified 2026-04-16: charge acct 101/10/68010/120/000/000
    #     BADDIST uses 999/99/99999/999/999/999 to trigger [DIST] error
    # ====================================================================
    print("\n=== 37. Requisition Distributions ===")
    for dkey, lkey, seg1, seg2, seg3, seg4, seg5, seg6 in [
        ("RT-REQD-G1",      "RT-REQL-G1",      "101", "10", "68010", "120", "000", "000"),
        ("RT-REQD-BADHDR",  "RT-REQL-BADHDR",  "101", "10", "68010", "120", "000", "000"),
        ("RT-REQD-G2",      "RT-REQL-G2",      "101", "10", "68010", "120", "000", "000"),
        ("RT-REQD-BADLINE", "RT-REQL-BADLINE", "101", "10", "68010", "120", "000", "000"),
        ("RT-REQD-BADDIST", "RT-REQL-BADDIST", "999", "99", "99999", "999", "999", "999"),
    ]:
        run_sql(cur, """
            INSERT INTO DMT_OWNER.DMT_POR_REQ_DISTS_STG_TBL (
                INTERFACE_DISTRIBUTION_KEY, INTERFACE_LINE_KEY,
                DISTRIBUTION_NUMBER, PERCENT,
                CHARGE_ACCOUNT_SEGMENT1, CHARGE_ACCOUNT_SEGMENT2,
                CHARGE_ACCOUNT_SEGMENT3, CHARGE_ACCOUNT_SEGMENT4,
                CHARGE_ACCOUNT_SEGMENT5, CHARGE_ACCOUNT_SEGMENT6,
                SOURCE_ID
            ) VALUES (
                :dkey, :lkey,
                1, 100,
                :s1, :s2, :s3, :s4, :s5, :s6,
                :src
            )
        """, {"dkey": dkey, "lkey": lkey,
              "s1": seg1, "s2": seg2, "s3": seg3, "s4": seg4, "s5": seg5, "s6": seg6,
              "src": f"RT-{dkey}"},
        label=f"Req Dist: {dkey}")
    tag_scenario(cur, "DMT_POR_REQ_DISTS_STG_TBL", scenario_id)

    # ====================================================================
    # 38. 1099 INVOICES — use PO headers with DOCUMENT_TYPE_CODE='STANDARD'
    #     and AP invoice tables. 1099 shares AP tables but with TYPE_1099.
    #     (Already covered by AP Invoice inserts above — 1099 is an AP
    #      invoice with TYPE_1099 set on the line. Adding explicit 1099.)
    # ====================================================================
    print("\n=== 38. 1099 Invoices (AP with TYPE_1099) ===")
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_AP_INVOICES_INT_STG_TBL (
            INVOICE_ID, OPERATING_UNIT, SOURCE,
            INVOICE_NUM, INVOICE_AMOUNT, INVOICE_DATE,
            VENDOR_NAME, VENDOR_NUM, VENDOR_SITE_CODE,
            INVOICE_CURRENCY_CODE, INVOICE_TYPE_LOOKUP_CODE,
            GL_DATE, CALC_TAX_DURING_IMPORT_FLAG, SOURCE_ID
        ) VALUES (
            800010, :bu, 'Manual Invoice Entry',
            'RT-1099-G1', 5000.00, DATE '2025-06-15',
            :vname, :vnum, :vsite,
            'USD', 'STANDARD',
            DATE '2025-06-15', 'Y', 'RT-1099-G1'
        )
    """, {"bu": BU, "vname": "RT Supplier Good-1", "vnum": "RT-SUP-G1",
          "vsite": "RT-SITE-G1"},
    label="GOOD 1099 Invoice Header: RT-1099-G1")

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_AP_INVOICE_LINES_INT_STG_TBL (
            INVOICE_ID, LINE_NUMBER, LINE_TYPE_LOOKUP_CODE,
            AMOUNT, DESCRIPTION,
            DIST_CODE_CONCATENATED, ACCOUNTING_DATE,
            TYPE_1099, INCOME_TAX_REGION, SOURCE_ID
        ) VALUES (
            800010, 1, 'ITEM',
            5000.00, 'RT 1099 reportable payment',
            '101-10-68010-120-000-000', DATE '2025-06-15',
            '07', 'CA', 'RT-1099LN-G1'
        )
    """, label="GOOD 1099 Invoice Line: 800010")
    tag_scenario(cur, "DMT_AP_INVOICES_INT_STG_TBL", scenario_id)
    tag_scenario(cur, "DMT_AP_INVOICE_LINES_INT_STG_TBL", scenario_id)

    # ====================================================================
    # 39. BLANKET POs (reuse PO headers with DOCUMENT_TYPE_CODE='BLANKET')
    # ====================================================================
    print("\n=== 39. Blanket POs ===")
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL (
            INTERFACE_HEADER_KEY, ACTION, DOCUMENT_TYPE_CODE,
            STYLE_DISPLAY_NAME, PRC_BU_NAME, REQ_BU_NAME,
            SOLDTO_LE_NAME, BILLTO_BU_NAME,
            AGENT_NAME, CURRENCY_CODE,
            VENDOR_NAME, VENDOR_NUM, VENDOR_SITE_CODE,
            DOCUMENT_NUM, SOURCE_ID
        ) VALUES (
            'RT-BPA-G1', 'ORIGINAL', 'BLANKET',
            'Blanket Purchase Agreement', :bu, :bu,
            'US1 Legal Entity', :bu,
            'Roth, Calvin', 'USD',
            'RT Supplier Good-1', 'RT-SUP-G1', 'RT-SITE-G1',
            'RT-BPA-001', 'RT-BPA-G1'
        )
    """, {"bu": BU},
    label="GOOD Blanket PO: RT-BPA-001")
    tag_scenario(cur, "DMT_PO_HEADERS_INT_STG_TBL", scenario_id)

    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_PO_LINES_INT_STG_TBL (
            INTERFACE_LINE_KEY, INTERFACE_HEADER_KEY,
            ACTION, LINE_NUM, LINE_TYPE,
            ITEM_DESCRIPTION, AMOUNT, UNIT_OF_MEASURE, UNIT_PRICE,
            CATEGORY, SOURCE_ID
        ) VALUES (
            'RT-BPAL-G1', 'RT-BPA-G1',
            'ADD', 1, 'Goods',
            'RT blanket line - office supplies', 50000.00, 'Each', 25,
            'Miscellaneous', 'RT-BPAL-G1'
        )
    """, label="GOOD Blanket PO Line: RT-BPAL-G1")
    tag_scenario(cur, "DMT_PO_LINES_INT_STG_TBL", scenario_id)

    # BAD Blanket PO: nonexistent supplier [BAD-UPS]
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL (
            INTERFACE_HEADER_KEY, ACTION, DOCUMENT_TYPE_CODE,
            STYLE_DISPLAY_NAME, PRC_BU_NAME, REQ_BU_NAME,
            SOLDTO_LE_NAME, BILLTO_BU_NAME,
            AGENT_NAME, CURRENCY_CODE,
            VENDOR_NAME, VENDOR_NUM, VENDOR_SITE_CODE,
            DOCUMENT_NUM, SOURCE_ID
        ) VALUES (
            'RT-BPA-BAD1', 'ORIGINAL', 'BLANKET',
            'Blanket Purchase Agreement', :bu, :bu,
            'US1 Legal Entity', :bu,
            'Roth, Calvin', 'USD',
            'DOES NOT EXIST SUPPLIER', 'NOSUP-999', 'NOSITE-999',
            'RT-BPA-BAD1', 'RT-BPA-BAD1'
        )
    """, {"bu": BU},
    label="BAD Blanket PO: nonexistent supplier [BAD-UPS]")
    tag_scenario(cur, "DMT_PO_HEADERS_INT_STG_TBL", scenario_id)

    # ====================================================================
    # 40. CONTRACTS (reuse PO headers with DOCUMENT_TYPE_CODE='CONTRACT')
    # ====================================================================
    print("\n=== 40. Contracts ===")
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL (
            INTERFACE_HEADER_KEY, ACTION, DOCUMENT_TYPE_CODE,
            STYLE_DISPLAY_NAME, PRC_BU_NAME, REQ_BU_NAME,
            SOLDTO_LE_NAME, BILLTO_BU_NAME,
            AGENT_NAME, CURRENCY_CODE,
            VENDOR_NAME, VENDOR_NUM, VENDOR_SITE_CODE,
            DOCUMENT_NUM, COMMENTS, SOURCE_ID
        ) VALUES (
            'RT-CPA-G1', 'ORIGINAL', 'CONTRACT',
            'Contract Purchase Agreement', :bu, :bu,
            'US1 Legal Entity', :bu,
            'Roth, Calvin', 'USD',
            'RT Supplier Good-1', 'RT-SUP-G1', 'RT-SITE-G1',
            'RT-CPA-001', 'RT contract agreement', 'RT-CPA-G1'
        )
    """, {"bu": BU},
    label="GOOD Contract: RT-CPA-001")
    tag_scenario(cur, "DMT_PO_HEADERS_INT_STG_TBL", scenario_id)

    # BAD Contract: nonexistent supplier [BAD-UPS]
    run_sql(cur, """
        INSERT INTO DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL (
            INTERFACE_HEADER_KEY, ACTION, DOCUMENT_TYPE_CODE,
            STYLE_DISPLAY_NAME, PRC_BU_NAME, REQ_BU_NAME,
            SOLDTO_LE_NAME, BILLTO_BU_NAME,
            AGENT_NAME, CURRENCY_CODE,
            VENDOR_NAME, VENDOR_NUM, VENDOR_SITE_CODE,
            DOCUMENT_NUM, COMMENTS, SOURCE_ID
        ) VALUES (
            'RT-CPA-BAD1', 'ORIGINAL', 'CONTRACT',
            'Contract Purchase Agreement', :bu, :bu,
            'US1 Legal Entity', :bu,
            'Roth, Calvin', 'USD',
            'DOES NOT EXIST SUPPLIER', 'NOSUP-999', 'NOSITE-999',
            'RT-CPA-BAD1', 'BAD: nonexistent supplier', 'RT-CPA-BAD1'
        )
    """, {"bu": BU},
    label="BAD Contract: nonexistent supplier [BAD-UPS]")
    tag_scenario(cur, "DMT_PO_HEADERS_INT_STG_TBL", scenario_id)

    # ── Commit everything ───────────────────────────────────────────────────
    conn.commit()
    print("\n" + "=" * 60)
    print("COMMITTED.")

    # ── Summary ─────────────────────────────────────────────────────────────
    print(f"\n{'=' * 60}")
    print(f"REGRESSION TEST DATA INSERTION SUMMARY")
    print(f"{'=' * 60}")
    print(f"  Scenario:   {SCENARIO_NAME} (ID={scenario_id})")
    print(f"  Succeeded:  {ok_count}")
    print(f"  Failed:     {err_count}")
    print(f"  Total:      {ok_count + err_count}")
    print()

    # ── Verify counts per table ─────────────────────────────────────────────
    tables = [
        # Suppliers
        ("DMT_POZ_SUPPLIERS_STG_TBL",           "STG_STATUS"),
        ("DMT_POZ_SUP_ADDR_STG_TBL",            "STG_STATUS"),
        ("DMT_POZ_SUP_SITE_STG_TBL",            "STG_STATUS"),
        ("DMT_POZ_SUP_SITE_ASSN_STG_TBL",       "STG_STATUS"),
        ("DMT_POZ_SUP_CONTACTS_STG_TBL",        "STG_STATUS"),
        # Customers
        ("DMT_HZ_PARTIES_STG_TBL",              "STG_STATUS"),
        ("DMT_HZ_LOCATIONS_STG_TBL",            "STG_STATUS"),
        ("DMT_HZ_PARTY_SITES_STG_TBL",          "STG_STATUS"),
        ("DMT_HZ_PARTY_SITE_USES_STG_TBL",      "STG_STATUS"),
        ("DMT_HZ_ACCOUNTS_STG_TBL",             "STG_STATUS"),
        ("DMT_HZ_ACCT_SITES_STG_TBL",           "STG_STATUS"),
        ("DMT_HZ_ACCT_SITE_USES_STG_TBL",       "STG_STATUS"),
        # POs (Standard + Blanket + Contract)
        ("DMT_PO_HEADERS_INT_STG_TBL",           "STG_STATUS"),
        ("DMT_PO_LINES_INT_STG_TBL",             "STG_STATUS"),
        ("DMT_PO_LINE_LOCS_INT_STG_TBL",         "STG_STATUS"),
        ("DMT_PO_DISTS_INT_STG_TBL",             "STG_STATUS"),
        # AP Invoices (+ 1099)
        ("DMT_AP_INVOICES_INT_STG_TBL",           "STG_STATUS"),
        ("DMT_AP_INVOICE_LINES_INT_STG_TBL",      "STG_STATUS"),
        # AR Invoices
        ("DMT_RA_LINES_STG_TBL",                "STG_STATUS"),
        # GL
        ("DMT_GL_INTERFACE_STG_TBL",             "STG_STATUS"),
        ("DMT_GL_BUDGET_INT_STG_TBL",            "STG_STATUS"),
        ("DMT_PLAN_BUDGET_STG_TBL",              "STG_STATUS"),
        ("DMT_PRJ_BUDGET_STG_TBL",               "STG_STATUS"),
        # Projects
        ("DMT_PJF_PROJECTS_STG_TBL",            "STG_STATUS"),
        ("DMT_PJF_TASKS_STG_TBL",               "STG_STATUS"),
        ("DMT_PJF_TEAM_MEMBERS_STG_TBL",         "STG_STATUS"),
        ("DMT_PJC_TXN_CONTROLS_STG_TBL",         "STG_STATUS"),
        ("DMT_PJC_EXPENDITURES_STG_TBL",         "STG_STATUS"),
        ("DMT_PJB_BILL_EVENTS_STG_TBL",          "STG_STATUS"),
        # Grants
        ("DMT_GMS_AWD_HEADERS_STG_TBL",          "STG_STATUS"),
        # Assets
        ("DMT_FA_ASSET_HDR_STG_TBL",             "STG_STATUS"),
        ("DMT_FA_ASSET_BOOK_STG_TBL",            "STG_STATUS"),
        ("DMT_FA_ASSET_ASSIGN_STG_TBL",          "STG_STATUS"),
        # MiscReceipts
        ("DMT_INV_TRX_STG_TBL",                  "STG_STATUS"),
        ("DMT_INV_TRX_LOTS_STG_TBL",             "STG_STATUS"),
        ("DMT_INV_TRX_SERIALS_STG_TBL",          "STG_STATUS"),
        # Requisitions
        ("DMT_POR_REQ_HEADERS_STG_TBL",           "STG_STATUS"),
        ("DMT_POR_REQ_LINES_STG_TBL",             "STG_STATUS"),
        ("DMT_POR_REQ_DISTS_STG_TBL",             "STG_STATUS"),
    ]
    print("Verification — rows tagged with this scenario:")
    total_good = 0
    total_bad = 0
    total = 0
    for tbl, stcol in tables:
        try:
            cur.execute(
                f"SELECT COUNT(*) FROM DMT_OWNER.{tbl} WHERE SCENARIO_ID = :sid",
                {"sid": scenario_id})
            cnt = cur.fetchone()[0]
            total += cnt
            print(f"  {tbl:45s}  {cnt:>4d}")
        except Exception as e:
            print(f"  {tbl:45s}  ERR: {e}")
    print(f"  {'TOTAL':45s}  {total:>4d}")

    cur.close()
    conn.close()
    print("\nDone.")


if __name__ == "__main__":
    main()
