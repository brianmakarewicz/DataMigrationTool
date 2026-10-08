-- PACKAGE DMT_WORKER_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_WORKER_RESULTS_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_WORKER_RESULTS_PKG
-- Post-load HDL reconciliation for Workers (the person tiers).
--
-- Per-record HDL errors are staged by DMT_HDL_UTIL_PKG.STAGE_HDL_MESSAGES and
-- applied here with static SQL on the exact SourceSystemId of each of the 7
-- person TFM tables; LOADED comes only from each record's own base-table proof
-- (Workers recon report V2). The work relationship and assignment tiers are
-- reconciled by DMT_ASSIGNMENT_RESULTS_PKG against the same HDL data set.
--
-- CEMLI_CODE: 'Workers'
-- ============================================================

    -- Main entry point: call after POLL_HDL completes.
    -- p_request_id: the HDL data set RequestId
    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_dataset_status IN VARCHAR2 DEFAULT NULL
    );

    -- Whole-document rejection (backlog #289, design section 5). Called by
    -- DMT_ASSIGNMENT_RESULTS_PKG.RECONCILE_BATCH once both person and assignment
    -- tiers of the same HDL request have their errors and proof applied: every
    -- still-GENERATED row of a person whose Worker document Fusion rejected is
    -- FAILED quoting the real error of the record that failed.
    PROCEDURE PROPAGATE_DOCUMENT_ERRORS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    );

END DMT_WORKER_RESULTS_PKG;
/
