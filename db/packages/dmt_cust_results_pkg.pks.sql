-- PACKAGE DMT_CUST_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CUST_RESULTS_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_CUST_RESULTS_PKG
-- Post-load BIP reconciliation for Customers.
--
-- Customer FBDI uses a single ESS job (BulkImportJob) for
-- all 7 object types. One BIP report call reconciles all.
--
-- Fusion interface table: HZ_IMP_PARTIES_T (primary status).
-- Child tables joined via BATCH_ID + ORIG_SYSTEM_REFERENCE.
--
-- BIP report path read from DMT_BIP_REPORT_TBL at runtime.
-- CEMLI_CODE: 'Customers'
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

END DMT_CUST_RESULTS_PKG;
/
