-- DMT_RUN_RECORDS_V  (backlog #66 — post-run base-table reporting)
-- ============================================================
-- Normalized per-record view: ONE row per TFM record across every object,
-- in a single common shape, so the reporting package can roll up and drill
-- without knowing each object's table. It is the record-grain sibling of the
-- per-object DMT_RUN_STATUS_V (which stays untouched — folding the two is a
-- deferred change to avoid touching many screens). The object list (which TFM
-- tables, and how the grouped objects split by discriminator) is kept in step
-- with DMT_RUN_STATUS_V.
--
-- Common columns every arm returns, in this order:
--   RUN_ID          the pipeline run (the batch)
--   WORK_QUEUE_ID   provenance of the record's work item
--   CEMLI_CODE      the registry CEMLI code (used to look the object up in
--                   DMT_BIP_REPORT_TBL) — always the base object, never split
--   OBJECT_TYPE     the same label DMT_RUN_STATUS_V uses (base object or, for
--                   grouped objects, base object plus its discriminator)
--   SUB_OBJECT      the grouping discriminator (BU / OU / batch source /
--                   document type) for objects DMT_RUN_STATUS_V splits; NULL
--                   for single-table objects
--   TFM_SEQUENCE_ID the per-record TFM row id
--   RECON_KEY       the record's reconciliation business key
--   TFM_STATUS      LOADED / FAILED / UNACCOUNTED / GENERATED (raw stored value)
--   FUSION_ID       the object's FUSION_*_ID column, aliased — the real Fusion
--                   base-table id when LOADED, NULL otherwise
--   ERROR_TEXT      the accumulated error text (real Fusion error when FAILED)
--   DMT_REFERENCE   DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID,
--                   TFM_SEQUENCE_ID) — the run-scoped reference string
--                   ('DMT:run:wq:tfm') stamped onto the record; the live
--                   prove-in-Fusion audit joins base rows back by its tfm slot.
--
-- The CEMLI_CODE for the three PO document types is 'PurchaseOrders',
-- 'BlanketPOs' and 'Contracts' respectively so each resolves to its own
-- registry row (they share one TFM table, split by DOCUMENT_TYPE_CODE).
-- ============================================================
CREATE OR REPLACE EDITIONABLE VIEW "DMT_RUN_RECORDS_V" (
    "RUN_ID", "WORK_QUEUE_ID", "CEMLI_CODE", "OBJECT_TYPE", "SUB_OBJECT",
    "TFM_SEQUENCE_ID", "RECON_KEY", "TFM_STATUS", "FUSION_ID", "ERROR_TEXT",
    "DMT_REFERENCE"
) AS
    -- ---- Suppliers (C001) — 5 separate objects ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'Suppliers', 'Suppliers', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_VENDOR_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_POZ_SUPPLIERS_TFM_TBL
    UNION ALL
    SELECT RUN_ID, WORK_QUEUE_ID, 'SupplierAddresses', 'SupplierAddresses', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_PARTY_SITE_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_POZ_SUP_ADDR_TFM_TBL
    UNION ALL
    SELECT RUN_ID, WORK_QUEUE_ID, 'SupplierSites', 'SupplierSites', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_VENDOR_SITE_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_POZ_SUP_SITE_TFM_TBL
    UNION ALL
    SELECT RUN_ID, WORK_QUEUE_ID, 'SupplierSiteAssignments', 'SupplierSiteAssignments', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_ASSIGNMENT_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_POZ_SUP_SITE_ASSN_TFM_TBL
    UNION ALL
    SELECT RUN_ID, WORK_QUEUE_ID, 'SupplierContacts', 'SupplierContacts', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_CONTACT_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_POZ_SUP_CONTACTS_TFM_TBL
    UNION ALL
    -- ---- Purchase Orders (C004) — STANDARD, grouped by BU ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'PurchaseOrders',
           'PurchaseOrders:' || PRC_BU_NAME, PRC_BU_NAME,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_PO_HEADER_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_PO_HEADERS_INT_TFM_TBL
    WHERE  NVL(DOCUMENT_TYPE_CODE, 'STANDARD') = 'STANDARD'
    UNION ALL
    -- ---- Blanket POs — grouped by BU ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'BlanketPOs',
           'BlanketPOs' || CASE WHEN PRC_BU_NAME IS NOT NULL THEN ':' || PRC_BU_NAME END,
           PRC_BU_NAME,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_PO_HEADER_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_PO_HEADERS_INT_TFM_TBL
    WHERE  DOCUMENT_TYPE_CODE = 'BLANKET'
    UNION ALL
    -- ---- Contracts — grouped by BU ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'Contracts',
           'Contracts' || CASE WHEN PRC_BU_NAME IS NOT NULL THEN ':' || PRC_BU_NAME END,
           PRC_BU_NAME,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_PO_HEADER_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_PO_HEADERS_INT_TFM_TBL
    WHERE  DOCUMENT_TYPE_CODE = 'CONTRACT'
    UNION ALL
    -- ---- AP Invoices (C003) — optionally grouped by OU ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'APInvoices',
           'APInvoices' || CASE WHEN OPERATING_UNIT IS NOT NULL THEN ':' || OPERATING_UNIT END,
           OPERATING_UNIT,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_INVOICE_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_AP_INVOICES_INT_TFM_TBL
    UNION ALL
    -- ---- Customers (C005) ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'Customers', 'Customers', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_CUST_ACCOUNT_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_HZ_ACCOUNTS_TFM_TBL
    UNION ALL
    -- ---- AR Invoices (C006) — grouped by BU + BatchSource ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'ARInvoices',
           'ARInvoices' || CASE WHEN BU_NAME IS NOT NULL
               THEN ':' || BU_NAME || CASE WHEN BATCH_SOURCE_NAME IS NOT NULL
                   THEN ':' || BATCH_SOURCE_NAME END
               END,
           CASE WHEN BU_NAME IS NOT NULL
               THEN BU_NAME || CASE WHEN BATCH_SOURCE_NAME IS NOT NULL
                   THEN ':' || BATCH_SOURCE_NAME END
               END,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_CUSTOMER_TRX_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_RA_LINES_TFM_TBL
    UNION ALL
    -- ---- GL Balances ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'GLBalances', 'GLBalances', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_JE_HEADER_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_GL_INTERFACE_TFM_TBL
    UNION ALL
    -- ---- GL Budget Balances ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'GLBudgets', 'GLBudgets', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_BUDGET_VERSION_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_GL_BUDGET_INT_TFM_TBL
    UNION ALL
    -- ---- Planning Budgets ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'PlanningBudgets', 'PlanningBudgets', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_BUDGET_VERSION_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_PLAN_BUDGET_TFM_TBL
    UNION ALL
    -- ---- Projects (C007) ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'Projects', 'Projects', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_PROJECT_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_PJF_PROJECTS_TFM_TBL
    UNION ALL
    -- ---- Project Budgets ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'ProjectBudgets', 'ProjectBudgets', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_BUDGET_VERSION_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_PRJ_BUDGET_TFM_TBL
    UNION ALL
    -- ---- Expenditures (C008) ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'Expenditures', 'Expenditures', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_EXPENDITURE_ITEM_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_PJC_EXPENDITURES_TFM_TBL
    UNION ALL
    -- ---- Billing Events ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'BillingEvents', 'BillingEvents', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_EVENT_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_PJB_BILL_EVENTS_TFM_TBL
    UNION ALL
    -- ---- Grants ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'Grants', 'Grants', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_AWARD_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_GMS_AWD_HEADERS_TFM_TBL
    UNION ALL
    -- ---- Fixed Assets ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'Assets', 'Assets', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_ASSET_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_FA_ASSET_HDR_TFM_TBL
    UNION ALL
    -- ---- Requisitions ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'Requisitions', 'Requisitions', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_REQUISITION_HEADER_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_POR_REQ_HEADERS_TFM_TBL
    UNION ALL
    -- ---- Misc Receipts (On Hand Qty) ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'MiscReceipts', 'MiscReceipts', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_RECEIPT_HEADER_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_RCV_HEADERS_TFM_TBL
    UNION ALL
    -- ---- HCM: Workers ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'Workers', 'Workers', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_PERSON_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_WORKER_TFM_TBL
    UNION ALL
    -- ---- HCM: Salaries ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'Salaries', 'Salaries', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_SALARY_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_SALARY_TFM_TBL
    UNION ALL
    -- ---- HCM: Salary Bases ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'SalaryBases', 'SalaryBases', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_SALARY_BASIS_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_SAL_BASIS_TFM_TBL
    UNION ALL
    -- ---- HCM: Absence Entries ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'AbsenceEntries', 'AbsenceEntries', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_ABSENCE_ENTRY_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_ABSENCE_TFM_TBL
    UNION ALL
    -- ---- HCM: W2 Balances ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'W2Balances', 'W2Balances', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_BALANCE_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_W2_BAL_TFM_TBL
    UNION ALL
    -- ---- HCM: Participant Enrollments ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'ParticipantEnrollments', 'ParticipantEnrollments', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_PARTICIPANT_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_BEN_PARTIC_TFM_TBL
    UNION ALL
    -- ---- HCM: Dependent Enrollments ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'DependentEnrollments', 'DependentEnrollments', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_DEPENDENT_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_BEN_DEPEND_TFM_TBL
    UNION ALL
    -- ---- HCM: Beneficiary Designations ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'BeneficiaryDesignations', 'BeneficiaryDesignations', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_BENEFICIARY_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_BEN_BENFY_TFM_TBL
    UNION ALL
    -- ---- HCM: Tax Cards ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'TaxCards', 'TaxCards', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_DIR_CARD_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_TAX_CARD_TFM_TBL
    UNION ALL
    -- ---- HCM: Talent Profiles ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'TalentProfiles', 'TalentProfiles', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_PROFILE_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_TALENT_PROF_TFM_TBL
    UNION ALL
    -- ---- HCM: Performance Documents ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'PerformanceDocuments', 'PerformanceDocuments', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_EVALUATION_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_PERF_EVAL_TFM_TBL
    UNION ALL
    -- ---- HCM: Work Schedules ----
    SELECT RUN_ID, WORK_QUEUE_ID, 'WorkSchedules', 'WorkSchedules', NULL,
           TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_SCHEDULE_ID, ERROR_TEXT,
           DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
    FROM   DMT_WORK_SCHED_TFM_TBL;
