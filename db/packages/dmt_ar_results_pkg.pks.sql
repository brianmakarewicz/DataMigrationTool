-- PACKAGE DMT_AR_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AR_RESULTS_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AR_RESULTS_PKG
-- Post-load BIP reconciliation for ARInvoices.
--
-- AR AutoInvoice uses a single ESS job for lines + dists.
-- BIP report queries RA_INTERFACE_LINES_ALL for load status.
--
-- BIP report path read from DMT_BIP_REPORT_TBL at runtime.
-- CEMLI_CODE: 'ARInvoices'
-- ============================================================

    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    );

    FUNCTION FETCH_BIP_RESULTS (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    ) RETURN CLOB;

    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml_data       IN CLOB
    );

END DMT_AR_RESULTS_PKG;
/
