-- PACKAGE DMT_POZ_SUP_ADDR_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_POZ_SUP_ADDR_RESULTS_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_POZ_SUP_ADDR_RESULTS_PKG
-- Post-load BIP reconciliation for the SupplierAddresses supplier-family object
-- (coding standard: one results/reconciler package per object).
-- Procedures relocated verbatim from the former shared
-- DMT_POZ_SUP_RESULTS_PKG (behavior-preserving split, backlog #43).
-- The p_cemli_code signature is retained: the pipeline registry
-- dispatches RECON_PROC / reset positionally (RECON_HAS_CEMLI_ARG='Y')
-- and always passes 'SupplierAddresses' to this package.
-- ============================================================

    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id  IN NUMBER,
        p_cemli_code      IN VARCHAR2,
        p_load_ess_id     IN NUMBER,
        x_report_xml      OUT XMLTYPE,
        x_error_code      OUT NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    );

    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_cemli_code     IN VARCHAR2,
        p_report_xml     IN XMLTYPE
    );

    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_cemli_code      IN VARCHAR2,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

    PROCEDURE RESET_UNACCOUNTED (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_load_ess_id   IN NUMBER DEFAULT NULL,
        p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

END DMT_POZ_SUP_ADDR_RESULTS_PKG;
/
