-- PACKAGE DMT_CUST_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CUST_RESULTS_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_CUST_RESULTS_PKG
-- Post-load BIP reconciliation for Customers (ONE object, seven
-- HZ record types loaded by a single ESS bulkImport job).
--
-- Modernized 2026-07-09 to the shared Contract v1 pattern (design
-- section 5), mirroring DMT_GL_RESULTS_PKG / DMT_POZ_SUP_RESULTS_PKG:
--   * transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no private
--     UTL_HTTP copy, no raw-envelope logging -- credentials never reach
--     DMT_LOG_TBL);
--   * FETCH_BIP_RESULTS is a PROCEDURE returning x_report_xml /
--     x_error_code (section 7 procedures-only contract for network calls);
--   * Contract v1 report parameters P_RUN_ID, P_LOAD_REQUEST_ID,
--     P_IMPORT_ESS_ID, P_PREFIX (report filters on P_LOAD_REQUEST_ID);
--   * outcomes are written to the seven TFM tables only -- nothing is
--     written back to staging.
--
-- Primary reconciliation on HZ_IMP_PARTIES_T (report DMT_CUST_RECON_RPT);
-- child record types cascade from the party outcome via
-- ORIG_SYSTEM_REFERENCE linkage. BIP report path is read from
-- DMT_BIP_REPORT_TBL at runtime. CEMLI_CODE: 'Customers'.
--
-- RECONCILE_BATCH keeps its public 3-argument signature: DMT_LOADER_PKG
-- calls DMT_CUST_RESULTS_PKG.RECONCILE_BATCH(run_id, load_ess_id,
-- import_ess_id) and is unaffected by this modernization.
-- ============================================================

    PROCEDURE RECONCILE_BATCH (
        p_run_id          IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id          IN  NUMBER,
        p_load_ess_id     IN  NUMBER,
        x_report_xml      OUT XMLTYPE,
        x_error_code      OUT NUMBER,
        p_import_ess_id   IN  NUMBER DEFAULT NULL
    );

    PROCEDURE PARSE_AND_UPDATE (
        p_run_id          IN NUMBER,
        p_report_xml      IN XMLTYPE
    );

END DMT_CUST_RESULTS_PKG;
/
