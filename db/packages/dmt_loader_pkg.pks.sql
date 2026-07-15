-- PACKAGE DMT_LOADER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_LOADER_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_LOADER_PKG
-- FBDI submission, ESS polling, and pipeline orchestration.
--
-- Execution model: APEX calls one of the public pipeline
-- procedures below. Python scripts call the same procedures
-- during development and unit testing.
--
-- Pipeline entry points (call from APEX or test script):
--   RUN_PROCURE_TO_PAY     — full P2P flow (all CEMLIs in order)
--   RUN_SUPPLIER_PIPELINE  — all 5 supplier object types
--   RUN_SUPPLIERS          — suppliers only (unit test / one-off)
--   RUN_SUPPLIER_ADDRESSES — supplier addresses only
--   RUN_SUPPLIER_SITES     — supplier sites only
--   RUN_SUPPLIER_SITE_ASSIGNMENTS — site assignments only
--   RUN_SUPPLIER_CONTACTS  — supplier contacts only
--
-- Required config keys (DMT_CONFIG_TBL):
--   FUSION_URL, FUSION_USERNAME, FUSION_PASSWORD
--
-- Job names, UCM accounts, and interface details IDs are looked up
-- from DMT_ERP_INTERFACE_OPTIONS_TBL (local mirror of Fusion
-- FUN_ERP_INTERFACE_OPTIONS, seeded at deploy time).
-- ============================================================

    -- --------------------------------------------------------
    -- Low-level infrastructure (also exposed for APEX testing)
    -- --------------------------------------------------------

    -- MCCS pattern: calls loadAndImportData SOAP with jobList.
    -- Uploads FBDI zip to UCM and chains the import job in one call.
    -- Returns the Load ESS job ID. Caller polls to completion.
    -- p_job_name, p_interface_details, p_doc_account: looked up via
    --   get_erp_options() from DMT_ERP_INTERFACE_OPTIONS_TBL.
    FUNCTION SUBMIT_LOAD (
        p_run_id    IN NUMBER,
        p_fbdi_zip          IN BLOB,
        p_filename          IN VARCHAR2,
        p_job_name          IN VARCHAR2,  -- full ESS path e.g. /oracle/.../package;JobDefinition
        p_interface_details IN NUMBER,    -- ERP_INTERFACE_OPTIONS_ID from DMT_ERP_INTERFACE_OPTIONS_TBL
        p_doc_account       IN VARCHAR2,  -- UCM account e.g. prc/supplier/import
        p_parameter_list    IN VARCHAR2 DEFAULT 'NEW,N',  -- ESS import job parameters
        p_log_context       IN VARCHAR2 DEFAULT NULL,
        p_username          IN VARCHAR2 DEFAULT NULL,  -- per-CEMLI Fusion user override
        p_password          IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2;

    -- Submit a standalone ESS job (submitESSJobRequest). Used for the second-stage
    -- post-load job (e.g. Assets PostMassAdditions) run after the import job succeeds.
    -- p_job_name: full ESS path with ',' or ';' before the job definition.
    -- p_param_list: ESS ParameterList (e.g. book code 'US CORP'); NULL => 'NEW,N,<run_id>'.
    FUNCTION SUBMIT_IMPORT_JOB (
        p_run_id         IN NUMBER,
        p_job_name       IN VARCHAR2,
        p_param_list     IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2;

    -- Find the chained import ESS job ID after the Load job completes.
    -- ESS request IDs are sequential; chained job has requestid > p_load_ess_id.
    -- Polls every 15s for up to 15 minutes. Raises -20050 if not found.
    FUNCTION GET_IMPORT_ESS_ID (
        p_run_id IN NUMBER,
        p_cemli_code     IN VARCHAR2,
        p_load_ess_id    IN VARCHAR2
    ) RETURN VARCHAR2;

    -- Poll an ESS job until terminal state or timeout.
    -- SUCCEEDED/WARNING → returns normally.
    -- FAILED/ERROR/EXPIRED → raises -20022 if p_raise_on_error = TRUE (default).
    -- x_fusion_status returns the terminal Fusion status so callers can branch
    -- (e.g. skip import job lookup when Load ESS returned ERROR).
    PROCEDURE POLL_ESS_JOB (
        p_run_id  IN NUMBER,
        p_ess_job_id      IN VARCHAR2,
        p_timeout_sec     IN NUMBER   DEFAULT 1800,
        p_raise_on_error  IN BOOLEAN  DEFAULT TRUE,
        p_log_context     IN VARCHAR2 DEFAULT NULL,
        p_cemli_code      IN VARCHAR2 DEFAULT NULL,  -- passed to CAPTURE_ESS_HIERARCHY
        x_fusion_status   OUT VARCHAR2,              -- terminal Fusion status (SUCCEEDED/WARNING/ERROR/FAILED/EXPIRED)
        p_username        IN VARCHAR2 DEFAULT NULL,  -- per-CEMLI Fusion user override
        p_password        IN VARCHAR2 DEFAULT NULL
    );

    -- --------------------------------------------------------
    -- Individual object-type runners
    -- Call from APEX for one-off loads or unit testing.
    -- Each runner: Validate → Generate FBDI → Load → Poll → BIP reconcile.
    -- --------------------------------------------------------
    PROCEDURE RUN_SUPPLIERS              (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);
    PROCEDURE RUN_SUPPLIER_ADDRESSES     (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);
    PROCEDURE RUN_SUPPLIER_SITES         (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);
    PROCEDURE RUN_SUPPLIER_SITE_ASSIGNMENTS (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);
    PROCEDURE RUN_SUPPLIER_CONTACTS      (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- PurchaseOrders: all 4 PO object types per ESS job.
    -- Multi-BU: loops over distinct PRC_BU_NAMEs in the data,
    -- submitting a separate loadAndImportData+jobList per BU.
    -- Validate → Transform → [per BU: Generate FBDI → Load → Reconcile].
    PROCEDURE RUN_PURCHASE_ORDERS       (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Customers: all 7 customer object types in one zip.
    -- Validate → Transform 7 types → Generate FBDI → Load → Reconcile.
    PROCEDURE RUN_CUSTOMERS             (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- ARInvoices: lines + distributions in one zip.
    -- Upstream dependency: customers must be LOADED.
    -- Validate → Transform 2 types → [per BU: Generate FBDI → Load → Reconcile].
    PROCEDURE RUN_AR_INVOICES           (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- APInvoices: headers + lines in one zip (no separate distributions).
    -- Upstream dependency: suppliers must be LOADED.
    -- Validate → Transform 2 types → [per OU: Generate FBDI → Load → Reconcile].
    PROCEDURE RUN_AP_INVOICES           (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Projects: 4 object types in one zip (projects, tasks, team members, txn controls).
    -- No upstream dependency (projects are master data).
    PROCEDURE RUN_PROJECTS              (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- BillingEvents: single CSV. Upstream: projects.
    PROCEDURE RUN_BILLING_EVENTS        (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Expenditures: single CSV. Upstream: projects.
    PROCEDURE RUN_EXPENDITURES          (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Grants: 15 CSVs in one zip. Upstream: projects.
    PROCEDURE RUN_GRANTS                (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Items: single CSV (EgpSystemItemsInterface). No upstream dependency.
    PROCEDURE RUN_ITEMS                 (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- ItemCategories: single CSV (EgpItemCategoriesInterface). Upstream: Items.
    PROCEDURE RUN_ITEM_CATEGORIES       (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- MiscReceipts: Items on Hand via miscellaneous receiving receipts.
    -- 2 CSVs: headers + transactions. Upstream: Items.
    PROCEDURE RUN_MISC_RECEIPTS         (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Requisitions: headers + lines + distributions. No upstream dependency.
    -- UCM: prc/requisition/import. ESS: RequisitionImportJob.
    PROCEDURE RUN_REQUISITIONS          (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- BlanketPOs: headers + lines (no locs/dists). Shares PO tables.
    -- STYLE_DISPLAY_NAME = 'Blanket Purchase Agreement'.
    PROCEDURE RUN_BLANKET_POS           (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Contracts: headers only (no lines/locs/dists). Shares PO tables.
    -- STYLE_DISPLAY_NAME = 'Contract Purchase Agreement'.
    PROCEDURE RUN_CONTRACTS             (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- --------------------------------------------------------
    -- HCM Objects (HDL pattern — uses DMT_HDL_UTIL_PKG)
    -- --------------------------------------------------------

    -- Workers: 7 business objects in Worker.dat (HDL).
    -- Worker + PersonName + PersonEmail + PersonPhone + PersonAddress
    -- + PersonNationalIdentifier + PersonLegislativeData.
    PROCEDURE RUN_WORKERS               (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Worker Assignments: WorkRelationship + Assignment in Worker.dat (HDL).
    PROCEDURE RUN_ASSIGNMENTS           (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Salaries: Salary.dat (HDL).
    PROCEDURE RUN_SALARIES              (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Salary Bases: SalaryBasis.dat (HDL).
    PROCEDURE RUN_SALARY_BASES          (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Absence Balances: AbsenceEntry.dat (HDL).
    PROCEDURE RUN_ABSENCES              (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- W-2 Balances: PayrollBalanceInitialization.dat (HDL).
    PROCEDURE RUN_W2_BALANCES           (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Participant Enrollment: BenefitParticipantEnrollment.dat (HDL).
    PROCEDURE RUN_BEN_PARTICIPANT       (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Dependent Enrollment: BenefitParticipantEnrollment.dat (HDL).
    PROCEDURE RUN_BEN_DEPENDENT         (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Beneficiary Enrollment: BenefitParticipantEnrollment.dat (HDL).
    PROCEDURE RUN_BEN_BENEFICIARY       (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Payroll Relationships: Worker.dat (HDL).
    PROCEDURE RUN_PAYROLL_RELS          (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Tax Calculation Cards: CalculationCard.dat (HDL).
    PROCEDURE RUN_TAX_CARDS             (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Talent Profiles: TalentProfile.dat (HDL).
    PROCEDURE RUN_TALENT_PROFILES       (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Performance Evaluations: PerformanceDocument.dat (HDL).
    PROCEDURE RUN_PERF_EVALUATIONS      (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Work Schedules: WorkSchedule.dat (HDL).
    PROCEDURE RUN_WORK_SCHEDULES        (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- --------------------------------------------------------
    -- FBDI Objects (Financials)
    -- --------------------------------------------------------

    -- GL Balances: GlInterface.csv (FBDI).
    PROCEDURE RUN_GL_BALANCES           (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- GL Budget Balances: GlBudgetInterface.csv (FBDI).
    PROCEDURE RUN_GL_BUDGETS            (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Planning Budget Balances: EpbcsDataImport.csv (FBDI). Dormant — no EPBCS interface on this instance.
    PROCEDURE RUN_PLAN_BUDGETS          (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Project Budgets: PjoPlanVersionsXface.csv (FBDI). Upstream: projects.
    PROCEDURE RUN_PROJECT_BUDGETS       (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Assets: 3 CSVs in one zip (FBDI).
    PROCEDURE RUN_ASSETS                (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- --------------------------------------------------------
    -- RUN_STANDALONE — single entry point for running any CEMLI
    -- individually with automatic prefix assignment.
    -- Creates the run row with one prefix per run from DMT_RUN_PREFIX_SEQ.
    -- Use this from APEX, regression scripts, or any caller that
    -- wants a self-contained run. The existing p_run_id IN
    -- versions remain for composite pipelines that share one IID.
    -- --------------------------------------------------------
    PROCEDURE RUN_STANDALONE (
        x_run_id   OUT NUMBER,
        p_cemli_code       IN  VARCHAR2,
        p_scenario_name    IN  VARCHAR2 DEFAULT NULL,
        p_run_mode         IN  VARCHAR2 DEFAULT 'NEW'
    );

    -- --------------------------------------------------------
    -- Pipeline flows
    -- Call from APEX for full pipeline runs.
    -- --------------------------------------------------------

    -- All 5 supplier object types in strict dependency order.
    -- Halts on any BIP reconciliation failure (hard stop).
    PROCEDURE RUN_SUPPLIER_PIPELINE (p_run_id IN NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW', p_skip_bu_refresh IN BOOLEAN DEFAULT FALSE);

    -- Full Procure-to-Pay flow: suppliers → POs → blankets → contracts → AP → 1099.
    -- Creates a new CONVERSION_MASTER row; integration ID and prefix both from sequences.
    -- x_run_id: returns the generated integration ID for the caller to log/display.
    PROCEDURE RUN_PROCURE_TO_PAY (x_run_id OUT NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW');

    -- Full Order-to-Cash flow: customers → AR invoices.
    -- Creates a new CONVERSION_MASTER row.
    PROCEDURE RUN_ORDER_TO_CASH (x_run_id OUT NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW');

    -- Full Project pipeline: projects → billing events → expenditures → grants → project budgets.
    -- Creates a new CONVERSION_MASTER row.
    PROCEDURE RUN_PROJECT_PIPELINE (x_run_id OUT NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW');

    -- Full HCM pipeline: workers → assignments → salaries → salary bases →
    -- absences → W-2 balances → benefits (3) → payroll rels → tax cards →
    -- talent profiles → perf evaluations → work schedules.
    -- Creates a new CONVERSION_MASTER row.
    PROCEDURE RUN_HCM_PIPELINE (x_run_id OUT NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW');

    -- Full Financials pipeline: GL balances → GL budgets → plan budgets → assets.
    -- Creates a new CONVERSION_MASTER row.
    PROCEDURE RUN_FINANCIALS_PIPELINE (x_run_id OUT NUMBER, p_scenario_name IN VARCHAR2 DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW');

    -- --------------------------------------------------------
    -- Async mode support for DMT_QUEUE_PKG
    -- When g_async_mode = TRUE, run_one_object_type returns
    -- immediately after SUBMIT_LOAD (no polling, no reconciliation).
    -- The Load ESS job ID is stored in g_load_ess_id.
    -- Queue poller handles ESS polling and reconciliation.
    -- --------------------------------------------------------
    g_async_mode   BOOLEAN      := FALSE;
    g_load_ess_id  VARCHAR2(100) := NULL;

    -- Multi-book Assets: when set (to a BOOK_TYPE_CODE), run_one_object_type for Assets
    -- skips re-transform and generates the FBDI for ONLY this book. NULL = all books.
    g_partition_key VARCHAR2(200) := NULL;

    -- Transform-only pass for Assets multi-book split: validate + transform STG->TFM (STAGED),
    -- no generate/submit. The queue worker then splits into one child queue row per book.
    PROCEDURE RUN_ASSETS_TRANSFORM_ONLY (
        p_run_id           IN NUMBER,
        p_scenario_name    IN VARCHAR2 DEFAULT NULL,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_LOADER_PKG;
/
