-- PACKAGE DMT_BEN_PARTIC_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_BEN_PARTIC_RESULTS_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_BEN_PARTIC_RESULTS_PKG
-- Post-load HDL reconciliation for BenParticipant (loaded via HDL as the
-- PersonBenefitBalance business object). Runs the per-record HDL error path and
-- then the shared Contract v1 base-tier proof (design section 5).
--
-- CEMLI_CODE: 'BenParticipant'
-- ============================================================

    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_dataset_status IN VARCHAR2 DEFAULT NULL
    );

END DMT_BEN_PARTIC_RESULTS_PKG;
/
