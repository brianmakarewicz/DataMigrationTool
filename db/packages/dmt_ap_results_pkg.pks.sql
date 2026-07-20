-- PACKAGE DMT_AP_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AP_RESULTS_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AP_RESULTS_PKG
-- Post-load BIP reconciliation for APInvoices.
--
-- AP FBDI uses a single ESS job for both object types (headers
-- and lines). One BIP report call reconciles both.
--
-- Fusion interface table: AP_INVOICES_INTERFACE (status/errors).
-- Child lines linked via INVOICE_ID.
--
-- BIP report path read from DMT_BIP_REPORT_TBL at runtime.
-- CEMLI_CODE: 'APInvoices'
-- ============================================================

    -- Main entry point: call after POLL_ESS_JOB completes.
    -- p_load_ess_id: the ESS job ID used as P_BATCH_ID in the BIP report
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

    -- Call Fusion BIP v2 SOAP runReport and return raw XML response.
    FUNCTION FETCH_BIP_RESULTS (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    ) RETURN CLOB;

    -- Parse BIP XML response and update header + line TFM and STG tables.
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml_data       IN CLOB
    );

END DMT_AP_RESULTS_PKG;
/
