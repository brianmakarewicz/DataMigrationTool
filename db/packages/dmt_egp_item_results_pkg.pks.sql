-- PACKAGE DMT_EGP_ITEM_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_EGP_ITEM_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_EGP_ITEM_RESULTS_PKG
-- Post-load BIP reconciliation for Items.
--
-- RECONCILE_BATCH: called by run_one_object_type after ESS
--   import completes. Runs the Items Contract v1 report (V3) once,
--   selected by the work item's ESS job ids, and stamps TFM rows
--   LOADED (base-table row) or FAILED (real Fusion error).
--
-- BIP report path read from DMT_BIP_REPORT_TBL at runtime.
-- CEMLI_CODE: 'Items'
-- ============================================================

    -- GET_PARTITION_KEYS — spawn-per-partition support (work-queue-ID core,
    -- 2026-07-20). Returns the distinct partition tokens (BATCH_ID rendered
    -- with TO_CHAR) for one run using STATIC SQL over the object's OWN transform
    -- tables. Items UNIONs the item transform table AND the item-category
    -- transform table, so a batch that exists only in categories (no item rows)
    -- still spawns a child work item. The queue worker calls this through the
    -- sanctioned registered-dispatch path (DMT_QUEUE_WORKER_PKG.invoke_registered,
    -- style KEYS) and spawns one child per token; the token is OPAQUE to the
    -- engine. Replaces the retired dynamic SELECT DISTINCT in EXECUTE_ONE.
    FUNCTION GET_PARTITION_KEYS (
        p_run_id IN NUMBER
    ) RETURN DMT_PARTITION_KEY_TBL;

    -- Main entry point for pipeline: call after POLL_ESS_JOB completes.
    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_load_ess_id    IN NUMBER,
        p_import_ess_id  IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

    -- RESET_UNACCOUNTED -- re-run-reconcile recovery (backlog #95). Static UPDATE
    -- over this object's OWN literally-named TFM table(s): flip this run's
    -- UNACCOUNTED rows back to GENERATED and strip the bare [UNACCOUNTED] tag so
    -- the next reconcile pass re-examines them. Dispatched by the queue worker
    -- through the sanctioned invoke_registered site (INVOKE_RESET, RECON style);
    -- the ESS-id args are ignored. NO dynamic SQL; NO COMMIT (caller owns the txn).
    PROCEDURE RESET_UNACCOUNTED (p_run_id IN NUMBER, p_load_ess_id IN NUMBER DEFAULT NULL,
        p_import_ess_id IN NUMBER DEFAULT NULL, p_work_queue_id IN NUMBER DEFAULT NULL);

END DMT_EGP_ITEM_RESULTS_PKG;
/
