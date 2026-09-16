-- PACKAGE DMT_BEN_BENFY_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_BEN_BENFY_RESULTS_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_BEN_BENFY_RESULTS_PKG
-- Post-load HDL reconciliation for BenBeneficiary.
-- Calls DMT_HDL_UTIL_PKG.RECONCILE_HDL (per-record FAILED), then applies the
-- shared Contract v1 base-table proof (design section 5) for LOADED.
--
-- CEMLI_CODE: 'BenBeneficiary'
-- ============================================================

    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_dataset_status IN VARCHAR2 DEFAULT NULL
    );

END DMT_BEN_BENFY_RESULTS_PKG;
/
