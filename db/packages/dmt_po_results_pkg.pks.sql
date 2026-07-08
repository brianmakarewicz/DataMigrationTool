-- PACKAGE DMT_PO_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PO_RESULTS_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_PO_RESULTS_PKG
-- Post-load BIP reconciliation for PurchaseOrders.
--
-- PO FBDI uses a single ESS job for all 4 object types (unlike
-- suppliers which had 5 separate jobs). One BIP report call
-- reconciles headers, lines, line locations, and distributions.
--
-- Fusion interface table: PO_HEADERS_INTERFACE (status/errors).
-- Related child interface tables joined via INTERFACE_HEADER_KEY.
--
-- BIP report path read from DMT_BIP_REPORT_TBL at runtime.
-- CEMLI_CODE: 'PurchaseOrders'
-- ============================================================

    -- Main entry point: call after POLL_ESS_JOB completes.
    -- p_load_ess_id: the ESS job ID used as P_BATCH_ID in the BIP report
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    );

    -- Call Fusion BIP v2 SOAP runReport and return raw XML response.
    FUNCTION FETCH_BIP_RESULTS (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    ) RETURN CLOB;

    -- Parse BIP XML response and update all 4 TFM + STG tables.
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml_data       IN CLOB
    );

END DMT_PO_RESULTS_PKG;
/
