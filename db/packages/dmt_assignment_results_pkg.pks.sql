-- PACKAGE DMT_ASSIGNMENT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_ASSIGNMENT_RESULTS_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_ASSIGNMENT_RESULTS_PKG
-- Post-load HDL reconciliation for Worker Assignments.
--
-- Worker Assignment HDL uses HCM Data Loader REST API for error retrieval.
-- Calls DMT_HDL_UTIL_PKG.RECONCILE_HDL for each of the 2 TFM tables.
--
-- CEMLI_CODE: 'WorkerAssignments'
-- ============================================================

    -- Main entry point: call after POLL_HDL completes.
    -- p_request_id: the HDL data set RequestId
    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_dataset_status IN VARCHAR2 DEFAULT NULL
    );

END DMT_ASSIGNMENT_RESULTS_PKG;
/
