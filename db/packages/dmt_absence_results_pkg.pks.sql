-- PACKAGE DMT_ABSENCE_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_ABSENCE_RESULTS_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_ABSENCE_RESULTS_PKG
-- Post-load HDL reconciliation for AbsenceEntries.
-- Calls DMT_HDL_UTIL_PKG.RECONCILE_HDL for each TFM table.
--
-- CEMLI_CODE: 'AbsenceEntries'
-- ============================================================

    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_dataset_status IN VARCHAR2 DEFAULT NULL
    );

END DMT_ABSENCE_RESULTS_PKG;
/
