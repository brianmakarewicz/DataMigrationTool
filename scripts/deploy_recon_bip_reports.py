#!/usr/bin/env python
"""
Deploy the Wave-1 BIP reconciliation reports (the five supplier-family objects
plus Customers) to THIS stack's Fusion catalog root /Custom/DMT2/{CEMLI}/
(never /Custom/DMT/ -- that is the frozen stack's catalog and is read-only to
DMT2).

Dev/test shim only (no pipeline logic): each report pair is deployed by the
DB's own DMT_BIP_DEPLOY_PKG.DEPLOY_RECON_REPORT -- login via SecurityService,
create the .xdm, then a generated XML-output .xdo wrapper linked to it. The
package enforces the /Custom/DMT2 folder guard (-20055) server-side.

Never overwrite, never delete (owner rule, backlog #757): the package first
asks the catalog whether the .xdm or the .xdo already exists and REFUSES
(ORA-20057) before creating anything if either does. A changed report is
deployed alongside the old one under a new versioned name (add a new REPORTS
row, e.g. ..._V3_DM / ..._V3_RPT) and the registry is pointed at it. So run
this with a dm=... filter for the new pair; an unfiltered run reports every
already-deployed pair as REFUSED (exists) and exits 1, touching nothing.

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
    # Supplier family V2 (2026-10-09, backlog #217): Contract v1 nine-column
    # reports, rows found only by the load job id. Deployed alongside the V1
    # SUP_*_DM models (never overwritten).
    ("Suppliers",               "DMT_SUP_RECON_V2_DM",           "DMT_SUP_RECON_V2_RPT"),
    ("SupplierAddresses",       "DMT_SUP_ADDR_RECON_V2_DM",      "DMT_SUP_ADDR_RECON_V2_RPT"),
    ("SupplierSites",           "DMT_SUP_SITE_RECON_V2_DM",      "DMT_SUP_SITE_RECON_V2_RPT"),
    ("SupplierSiteAssignments", "DMT_SUP_SITE_ASSN_RECON_V2_DM", "DMT_SUP_SITE_ASSN_RECON_V2_RPT"),
    ("SupplierContacts",        "DMT_SUP_CONT_RECON_V2_DM",      "DMT_SUP_CONT_RECON_V2_RPT"),
    ("PurchaseOrders",          "PO_DM",             "PO_RPT"),
    ("BlanketPOs",              "BLANKET_PO_DM",     "BLANKET_PO_RPT"),
    # BlanketPOs V2 (2026-10-07, backlog #258): rows found only by the work
    # item's Fusion job ids and the Blanket document style. Deployed alongside
    # DMT_BLANKET_PO_RECON_DM (never overwritten).
    ("BlanketPOs",              "DMT_BLANKET_PO_RECON_V2_DM", "DMT_BLANKET_PO_RECON_V2_RPT"),
    # BlanketPOs V3 (2026-10-09, backlog #683): alongside the earlier versions (never
    # overwritten); pages by header (the agreement document number) with PAGE_KEY.
    ("BlanketPOs", "DMT_BLANKET_PO_RECON_V3_DM", "DMT_BLANKET_PO_RECON_V3_RPT"),
    ("Contracts",               "CONTRACT_DM",       "CONTRACT_RPT"),
    # Contracts V2 (2026-10-07, backlog #259): rows found only by the work
    # item's Fusion job ids and the Contract document style. Deployed alongside
    # DMT_CONTRACT_RECON_DM (never overwritten).
    ("Contracts",               "DMT_CONTRACT_RECON_V2_DM", "DMT_CONTRACT_RECON_V2_RPT"),
    ("APInvoices",              "DMT_AP_RECON_DM",   "DMT_AP_RECON_RPT"),
    # APInvoices V2 (2026-10-07): deployed alongside V1 (never overwritten);
    # rows by Fusion job id only, real Payables rejection text only (#166).
    ("APInvoices",              "DMT_AP_RECON_V2_DM", "DMT_AP_RECON_V2_RPT"),
    # APInvoices V3 (2026-10-09, backlog #681): alongside the earlier versions (never
    # overwritten); pages by header (the prefixed invoice number) with PAGE_KEY.
    ("APInvoices", "DMT_AP_RECON_V3_DM", "DMT_AP_RECON_V3_RPT"),
    ("Customers",               "DMT_CUST_RECON_V5_DM", "DMT_CUST_RECON_V5_RPT"),
    # Customers V6 (2026-10-07, owner decision): alongside V5 (never overwritten);
    # base rows by REQUEST_ID = the Fusion import batch id the load sent
    # (P_FUSION_BATCH_ID), interface rows by LOAD_REQUEST_ID, never by the prefix.
    ("Customers",               "DMT_CUST_RECON_V6_DM", "DMT_CUST_RECON_V6_RPT"),
    # Customers V7 (2026-10-09, backlog #684): alongside the earlier versions (never
    # overwritten); pages by header (the party original system reference) with PAGE_KEY.
    ("Customers", "DMT_CUST_RECON_V7_DM", "DMT_CUST_RECON_V7_RPT"),
    ("ARInvoices",              "DMT_AR_RECON_DM",   "DMT_AR_RECON_RPT"),
    # ARInvoices V2 (2026-10-07): deployed alongside V1 (never overwritten);
    # interface error aggregation scoped to the load (V1 hit ORA-01489).
    ("ARInvoices",              "DMT_AR_RECON_V2_DM", "DMT_AR_RECON_V2_RPT"),
    # ARInvoices V3 (2026-10-07): alongside V1/V2; line RECORD_KEY attr1/attr2
    # (unique per line) so keyset paging never drops a row.
    ("ARInvoices",              "DMT_AR_RECON_V3_DM", "DMT_AR_RECON_V3_RPT"),
    # ARInvoices V4 (2026-10-07, owner decision): alongside V1-V3; rows found
    # only by the load's Fusion job ids (base lines by the AutoInvoice import
    # REQUEST_ID, interface rows by LOAD_REQUEST_ID), never by the run prefix.
    ("ARInvoices",              "DMT_AR_RECON_V4_DM", "DMT_AR_RECON_V4_RPT"),
    # ARInvoices V5 (2026-10-09, owner direction): alongside V1-V4; pages by
    # header (next N invoices + all their lines and distributions, PAGE_KEY,
    # backlog #224); loaded line FUSION_ID = trx id ~ line id (backlog #85).
    ("ARInvoices",              "DMT_AR_RECON_V5_DM", "DMT_AR_RECON_V5_RPT"),
    ("GLBalances",              "DMT_GL_BAL_RECON_DM", "DMT_GL_BAL_RECON_RPT"),
    # GLBalances V3 (backlog #173): alongside V1; real Journal Import error
    # (STATUS[: STATUS_DESCRIPTION]) only, rows selected by job id.
    ("GLBalances",              "DMT_GL_BAL_RECON_V3_DM", "DMT_GL_BAL_RECON_V3_RPT"),
    # GLBalances V4 (backlog #173): GROUP_ID = work queue id, never ALL; base rows
    # by the import job's own GroupID/LedgerID arguments.
    ("GLBalances",              "DMT_GL_BAL_RECON_V4_DM", "DMT_GL_BAL_RECON_V4_RPT"),
    # GLBalances V5 (2026-10-09, backlog #686): alongside the earlier versions (never
    # overwritten); pages by header (the journal) with PAGE_KEY.
    ("GLBalances", "DMT_GL_BAL_RECON_V5_DM", "DMT_GL_BAL_RECON_V5_RPT"),
    ("GLBudgets",               "GL_BUDGET_DM",      "GL_BUDGET_RPT"),
    # GLBudgets V2 (2026-10-09, backlog #687): alongside the earlier versions (never
    # overwritten); pages by header (the budget cell key) with PAGE_KEY.
    ("GLBudgets", "DMT_GL_BUDGET_RECON_V2_DM", "DMT_GL_BUDGET_RECON_V2_RPT"),
    # MiscReceipts V2 (2026-10-07, backlog #262): rows found only by the work
    # item's load job id (LOAD_REQUEST_ID). Deployed alongside
    # DMT_INV_TRX_RECON_DM (never overwritten).
    ("MiscReceipts",            "DMT_INV_TRX_RECON_V2_DM", "DMT_INV_TRX_RECON_V2_RPT"),
    # MiscReceipts V3 (2026-10-09, backlog #689): alongside the earlier versions (never
    # overwritten); pages by header (the receipt source line id) with PAGE_KEY.
    ("MiscReceipts", "DMT_INV_TRX_RECON_V3_DM", "DMT_INV_TRX_RECON_V3_RPT"),
    # Items V2 (2026-10-06): deployed alongside the original DMT_ITEM_RECON_DM
    # (never overwritten). Category tiers also match request_id = import ESS
    # id and carry MESSAGE_NAME + text from both EGP interface tables.
    ("Items",                   "DMT_ITEM_RECON_V2_DM", "DMT_ITEM_RECON_V2_RPT"),
    # Items V3 (2026-10-07, owner decision): alongside V1/V2; rows found only by
    # the work item's Fusion job ids (base by the Item Import REQUEST_ID,
    # interface and errors by LOAD_REQUEST_ID / REQUEST_ID), never by the prefix.
    ("Items",                   "DMT_ITEM_RECON_V3_DM", "DMT_ITEM_RECON_V3_RPT"),
    # Items V4 (2026-10-09, backlog #688): alongside the earlier versions (never
    # overwritten); pages by header (item number plus organization) with PAGE_KEY.
    ("Items", "DMT_ITEM_RECON_V4_DM", "DMT_ITEM_RECON_V4_RPT"),
    # ItemCategories ITEM_CAT_DM / ITEM_CAT_RPT: retired (backlog #480). Item
    # categories reconcile through the Items V3 report above (record type
    # ItemCategory); registry row 100000026 now names that report.
    ("Workers",                 "DMT_WORKERS_RECON_DM", "DMT_WORKERS_RECON_RPT"),
    # Workers V2 (2026-10-07, backlog #289): alongside V1 (never overwritten).
    # Rows selected by the HDL request id; every person component proven on its
    # own key-map row and base table.
    ("Workers",                 "DMT_WORKERS_RECON_V2_DM", "DMT_WORKERS_RECON_V2_RPT"),
    ("SalaryBases",             "DMT_SALARYBASES_RECON_DM", "DMT_SALARYBASES_RECON_RPT"),
    # SalaryBases V2 (2026-10-08, backlog #292): alongside V1 (never overwritten).
    # Rows selected by the HDL request id; salary basis confirmed in CMP_SALARY_BASES.
    ("SalaryBases",             "DMT_SALARYBASES_RECON_V2_DM", "DMT_SALARYBASES_RECON_V2_RPT"),
    ("Salaries",                "DMT_SALARIES_RECON_DM", "DMT_SALARIES_RECON_RPT"),
    # Salaries V2 (2026-10-07, backlog #291): alongside V1 (never overwritten).
    # Rows selected by the HDL request id; salary confirmed in CMP_SALARY.
    ("Salaries",                "DMT_SALARIES_RECON_V2_DM", "DMT_SALARIES_RECON_V2_RPT"),
    ("Absences",                "DMT_ABSENCES_RECON_DM", "DMT_ABSENCES_RECON_RPT"),
    # Absences V2 (2026-10-08, backlog #293): alongside V1 (never overwritten).
    # Rows selected by the HDL request id; absence confirmed in ANC_PER_ABS_ENTRIES.
    ("Absences",                "DMT_ABSENCES_RECON_V2_DM", "DMT_ABSENCES_RECON_V2_RPT"),
    ("WorkSchedules",            "DMT_WORKSCHEDULES_RECON_DM", "DMT_WORKSCHEDULES_RECON_RPT"),
    ("PayrollRelationships",     "DMT_PAYROLLRELATIONSHIPS_RECON_DM", "DMT_PAYROLLRELATIONSHIPS_RECON_RPT"),
    ("Assignments",              "DMT_ASSIGNMENTS_RECON_DM", "DMT_ASSIGNMENTS_RECON_RPT"),
    # Assignments V2 (2026-10-07, backlog #287/#290): alongside V1 (never
    # overwritten). Rows selected by the HDL request id; key map joined on each
    # row's own SourceSystemOwner (V1 filtered on 'HRC_SQLLOADER').
    ("Assignments",              "DMT_ASSIGNMENTS_RECON_V2_DM", "DMT_ASSIGNMENTS_RECON_V2_RPT"),
    ("BenParticipant",           "DMT_BENPARTICIPANT_RECON_DM", "DMT_BENPARTICIPANT_RECON_RPT"),
    ("BenDependent",            "DMT_BENDEPENDENT_RECON_DM", "DMT_BENDEPENDENT_RECON_RPT"),
    # BenParticipant / BenDependent V2 (2026-10-08, backlog #214): V1 header comments
    # held an illegal double hyphen (runReport HTTP 500). Deployed alongside V1.
    ("BenParticipant",           "DMT_BENPARTICIPANT_RECON_V2_DM", "DMT_BENPARTICIPANT_RECON_V2_RPT"),
    ("BenDependent",            "DMT_BENDEPENDENT_RECON_V2_DM", "DMT_BENDEPENDENT_RECON_V2_RPT"),
    ("BenBeneficiary",           "DMT_BENBENEFICIARY_RECON_DM", "DMT_BENBENEFICIARY_RECON_RPT"),
    ("W2Balances",              "DMT_W2_BAL_RECON_DM", "DMT_W2_BAL_RECON_RPT"),
    # W2Balances V2 (2026-10-08, backlog #413): alongside V1 (never overwritten);
    # the batch found by the exact BatchName (P_FUSION_BATCH_ID), never by prefix.
    ("W2Balances",              "DMT_W2_BAL_RECON_V2_DM", "DMT_W2_BAL_RECON_V2_RPT"),
    ("TalentProfiles",           "DMT_TALENTPROFILES_RECON_DM", "DMT_TALENTPROFILES_RECON_RPT"),
    # TalentProfiles V2 (2026-10-08, backlog #451): alongside V1; request-id selection.
    ("TalentProfiles",           "DMT_TALENTPROFILES_RECON_V3_DM", "DMT_TALENTPROFILES_RECON_V3_RPT"),
    ("PerfEvaluations",          "DMT_PERFEVALUATIONS_RECON_DM", "DMT_PERFEVALUATIONS_RECON_RPT"),
    ("Projects",                 "DMT_PROJECT_RECON_DM",       "DMT_PROJECT_RECON_RPT"),
    # Projects V2 (2026-10-07, owner-approved exception): base projects found by
    # PM_PROJECT_REFERENCE LIKE '<run_id>:<work_queue_id>:%' (no job id on the
    # project base tables), interface rows by LOAD_REQUEST_ID. Deployed alongside
    # DMT_PROJECT_RECON_DM (never overwritten).
    ("Projects",                 "DMT_PROJECT_RECON_V2_DM",    "DMT_PROJECT_RECON_V2_RPT"),
    # Projects V3 (2026-10-09, backlog #692): alongside the earlier versions (never
    # overwritten); pages by header (the project number) with PAGE_KEY.
    ("Projects", "DMT_PROJECT_RECON_V3_DM", "DMT_PROJECT_RECON_V3_RPT"),
    # ProjectBudgets recon V2 (2026-10-07, known-good fix): deployed alongside the
    # original PRJ_BUDGET_DM (never overwritten). Run scoped by the prefixed
    # PM_BUDGET_REFERENCE so budgets on EXISTING projects reconcile.
    ("ProjectBudgets",           "DMT_PRJ_BUDGET_RECON_V2_DM",           "DMT_PRJ_BUDGET_RECON_V2_RPT"),
    # ProjectBudgets V3 (2026-10-07, owner decision): rows found only by the work
    # item's Fusion job ids (import REQUEST_ID / load LOAD_REQUEST_ID), never by
    # the run prefix. Deployed alongside V1 and V2 (never overwritten).
    ("ProjectBudgets",           "DMT_PRJ_BUDGET_RECON_V3_DM",           "DMT_PRJ_BUDGET_RECON_V3_RPT"),
    # ProjectBudgets V4 (2026-10-09, backlog #691): alongside the earlier versions (never
    # overwritten); pages by header (project plus plan version) with PAGE_KEY.
    ("ProjectBudgets", "DMT_PRJ_BUDGET_RECON_V4_DM", "DMT_PRJ_BUDGET_RECON_V4_RPT"),
    # Grants V2 (2026-10-07, docs/findings/known_good_Grants.md): BASE tier keyed
    # on OKC_K_HEADERS_ALL_B.CONTRACT_NUMBER, prefix-scoped. Deployed alongside
    # the original DMT_GRANT_RECON_DM (never overwritten).
    ("Grants",                   "DMT_GRANT_RECON_V2_DM",      "DMT_GRANT_RECON_V2_RPT"),
    # Requisitions V2 (2026-10-07, owner decision): rows found only by the work
    # item's Fusion job ids (import REQUEST_ID / load LOAD_REQUEST_ID), never by
    # the run prefix or run id. Deployed alongside DMT_REQ_RECON_DM (never
    # overwritten).
    ("Requisitions",             "DMT_REQ_RECON_V2_DM",        "DMT_REQ_RECON_V2_RPT"),
    # Requisitions V3 (2026-10-09, backlog #621): alongside V1/V2 (never
    # overwritten). Same rows and columns as V2; tie-safe keyset paging (WITH
    # TIES) with an OBJECT_TYPE tiebreak, refreshed RECORD_KEY comments.
    ("Requisitions",             "DMT_REQ_RECON_V3_DM",        "DMT_REQ_RECON_V3_RPT"),
    # Requisitions V4 (2026-10-09, backlog #694): alongside the earlier versions (never
    # overwritten); pages by header (the requisition number) with PAGE_KEY.
    ("Requisitions", "DMT_REQ_RECON_V4_DM", "DMT_REQ_RECON_V4_RPT"),
    # BillingEvents V2 (2026-10-07, owner decision): base events by the import
    # job's REQUEST_ID, interface rows by LOAD_REQUEST_ID, never by the run prefix.
    # Alongside BILLING_EVENT_DM (never overwritten).
    ("BillingEvents",            "DMT_BILLING_EVENT_RECON_V2_DM", "DMT_BILLING_EVENT_RECON_V2_RPT"),
    # Assets V2 (2026-10-07, owner decision): base assets found through their
    # POSTED FA_MASS_ADDITIONS row by the load job's LOAD_REQUEST_ID (FA_ADDITIONS_B
    # has no request id), never by the run prefix. Alongside DMT_FA_ASSET_RECON_DM.
    ("Assets",                   "DMT_FA_ASSET_RECON_V2_DM",   "DMT_FA_ASSET_RECON_V2_RPT"),
    # Assets V3 (2026-10-09, backlog #682): alongside the earlier versions (never
    # overwritten); pages by header (the asset number) with PAGE_KEY.
    ("Assets", "DMT_FA_ASSET_RECON_V3_DM", "DMT_FA_ASSET_RECON_V3_RPT"),
    # PurchaseOrders V2 (2026-10-07, backlog #264): rows found only by the work
    # item's Fusion job ids and the Standard document style; the run-id LIKE on
    # the interface keys is gone. Deployed alongside DMT_PO_RECON_DM (never
    # overwritten).
    ("PurchaseOrders",           "DMT_PO_RECON_V2_DM",         "DMT_PO_RECON_V2_RPT"),
    # PurchaseOrders V3 (2026-10-09, backlog #693): alongside the earlier versions (never
    # overwritten); pages by header (the PO number) with PAGE_KEY.
    ("PurchaseOrders", "DMT_PO_RECON_V3_DM", "DMT_PO_RECON_V3_RPT"),
    # Expenditures V2 (2026-10-07, owner decision): rows found only by the work
    # item's Fusion job ids (import REQUEST_ID / load LOAD_REQUEST_ID), never by
    # the run prefix. Deployed alongside DMT_EXP_RECON_DM (never overwritten).
    ("Expenditures",             "DMT_EXP_RECON_V2_DM",        "DMT_EXP_RECON_V2_RPT"),
    # Expenditures V3 (2026-10-09, backlog #685): alongside the earlier versions (never
    # overwritten); pages by header (the original transaction reference) with PAGE_KEY.
    ("Expenditures", "DMT_EXP_RECON_V3_DM", "DMT_EXP_RECON_V3_RPT"),
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
    # GLBalances CMP V2 (backlog #173): reads the run's GROUP_ID range.
    ("GLBalances",               "GL_BAL_CMP_V2_DM",           "GL_BAL_CMP_V2_RPT"),
    ("GLBudgets",                "GL_BUDGET_CMP_DM",           "GL_BUDGET_CMP_RPT"),
    # Cache-off versions (2026-10-10, backlog #734): SQL identical to the version
    # before; released only because the report wrapper is now deployed with BIP
    # data caching off. Deployed alongside the earlier versions (never overwritten).
    ("APInvoices",              "DMT_AP_RECON_V4_DM",                    "DMT_AP_RECON_V4_RPT"),
    ("APPaymentTerms",          "DMT_APTERMS_RECON_V2_DM",               "DMT_APTERMS_RECON_V2_RPT"),
    ("ARInvoices",              "DMT_AR_RECON_V6_DM",                    "DMT_AR_RECON_V6_RPT"),
    ("Absences",                "DMT_ABSENCES_RECON_V3_DM",              "DMT_ABSENCES_RECON_V3_RPT"),
    ("Assets",                  "DMT_FA_ASSET_RECON_V4_DM",              "DMT_FA_ASSET_RECON_V4_RPT"),
    ("Assignments",             "DMT_ASSIGNMENTS_RECON_V3_DM",           "DMT_ASSIGNMENTS_RECON_V3_RPT"),
    ("BenBeneficiary",          "DMT_BENBENEFICIARY_RECON_V2_DM",        "DMT_BENBENEFICIARY_RECON_V2_RPT"),
    ("BenDependent",            "DMT_BENDEPENDENT_RECON_V3_DM",          "DMT_BENDEPENDENT_RECON_V3_RPT"),
    ("BenParticipant",          "DMT_BENPARTICIPANT_RECON_V3_DM",        "DMT_BENPARTICIPANT_RECON_V3_RPT"),
    ("BillingEvents",           "DMT_BILLING_EVENT_RECON_V3_DM",         "DMT_BILLING_EVENT_RECON_V3_RPT"),
    ("BlanketPOs",              "DMT_BLANKET_PO_RECON_V4_DM",            "DMT_BLANKET_PO_RECON_V4_RPT"),
    ("CashBanks",               "DMT_CEBANK_RECON_V2_DM",                "DMT_CEBANK_RECON_V2_RPT"),
    ("Contracts",               "DMT_CONTRACT_RECON_V3_DM",              "DMT_CONTRACT_RECON_V3_RPT"),
    ("Customers",               "DMT_CUST_RECON_V8_DM",                  "DMT_CUST_RECON_V8_RPT"),
    ("Expenditures",            "DMT_EXP_RECON_V4_DM",                   "DMT_EXP_RECON_V4_RPT"),
    ("GLBalances",              "DMT_GL_BAL_RECON_V6_DM",                "DMT_GL_BAL_RECON_V6_RPT"),
    ("GLBudgets",               "DMT_GL_BUDGET_RECON_V3_DM",             "DMT_GL_BUDGET_RECON_V3_RPT"),
    ("Grants",                  "DMT_GRANT_RECON_V3_DM",                 "DMT_GRANT_RECON_V3_RPT"),
    ("Items",                   "DMT_ITEM_RECON_V5_DM",                  "DMT_ITEM_RECON_V5_RPT"),
    ("Lookups",                 "DMT_LOOKUP_RECON_V2_DM",                "DMT_LOOKUP_RECON_V2_RPT"),
    ("MiscReceipts",            "DMT_INV_TRX_RECON_V4_DM",               "DMT_INV_TRX_RECON_V4_RPT"),
    ("PayrollRelationships",    "DMT_PAYROLLRELATIONSHIPS_RECON_V2_DM",  "DMT_PAYROLLRELATIONSHIPS_RECON_V2_RPT"),
    ("ProjectBudgets",          "DMT_PRJ_BUDGET_RECON_V5_DM",            "DMT_PRJ_BUDGET_RECON_V5_RPT"),
    ("Projects",                "DMT_PROJECT_RECON_V4_DM",               "DMT_PROJECT_RECON_V4_RPT"),
    ("PurchaseOrders",          "DMT_PO_RECON_V4_DM",                    "DMT_PO_RECON_V4_RPT"),
    ("PurchaseOrders",          "PO_V2_DM",                              "PO_V2_RPT"),
    ("Requisitions",            "DMT_REQ_RECON_V5_DM",                   "DMT_REQ_RECON_V5_RPT"),
    ("Salaries",                "DMT_SALARIES_RECON_V3_DM",              "DMT_SALARIES_RECON_V3_RPT"),
    ("SalaryBases",             "DMT_SALARYBASES_RECON_V3_DM",           "DMT_SALARYBASES_RECON_V3_RPT"),
    ("SupplierAddresses",       "DMT_SUP_ADDR_RECON_V3_DM",              "DMT_SUP_ADDR_RECON_V3_RPT"),
    ("SupplierContacts",        "DMT_SUP_CONT_RECON_V3_DM",              "DMT_SUP_CONT_RECON_V3_RPT"),
    ("SupplierSiteAssignments", "DMT_SUP_SITE_ASSN_RECON_V3_DM",         "DMT_SUP_SITE_ASSN_RECON_V3_RPT"),
    ("SupplierSites",           "DMT_SUP_SITE_RECON_V3_DM",              "DMT_SUP_SITE_RECON_V3_RPT"),
    ("Suppliers",               "DMT_SUP_RECON_V3_DM",                   "DMT_SUP_RECON_V3_RPT"),
    ("TalentProfiles",          "DMT_TALENTPROFILES_RECON_V4_DM",        "DMT_TALENTPROFILES_RECON_V4_RPT"),
    ("UnitsOfMeasure",          "DMT_UOM_RECON_V2_DM",                   "DMT_UOM_RECON_V2_RPT"),
    ("W2Balances",              "DMT_W2_BAL_RECON_V3_DM",                "DMT_W2_BAL_RECON_V3_RPT"),
    ("WorkSchedules",           "DMT_WORKSCHEDULES_RECON_V2_DM",         "DMT_WORKSCHEDULES_RECON_V2_RPT"),
    ("Workers",                 "DMT_WORKERS_RECON_V3_DM",               "DMT_WORKERS_RECON_V3_RPT"),
    ("common",                  "DMT_FBDI_LOOKUPS_V2_DM",                "DMT_FBDI_LOOKUPS_V2_RPT"),
    ("common",                  "DMT_ESS_HIERARCHY_V2_DM",               "DMT_ESS_HIERARCHY_V2_RPT"),
    ("common",                  "DMT_ESS_CHILD_JOB_V6_DM",               "DMT_ESS_CHILD_JOB_V6_RPT"),
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
            if "ORA-20057" in str(e):
                print(f"  REFUSED (exists, left untouched -- deploy a new version name): {e}")
            else:
                print(f"  ERR  {e}")
            fail += 1
    conn.commit()  # DMT_UTIL_PKG.LOG rows
    cur.close()
    conn.close()
    print(f"=== DONE: {ok} deployed, {fail} failed ===")
    sys.exit(1 if fail else 0)


if __name__ == "__main__":
    main()
