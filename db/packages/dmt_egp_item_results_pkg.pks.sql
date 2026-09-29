-- PACKAGE DMT_EGP_ITEM_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_EGP_ITEM_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_EGP_ITEM_RESULTS_PKG
-- Post-load BIP reconciliation for Items.
--
-- RECONCILE_BATCH: called by run_one_object_type after ESS
--   import completes. Calls BIP report to match imported rows
--   against EGP_SYSTEM_ITEMS_INTERFACE status, then updates
--   TFM/STG rows to LOADED or FAILED.
--
-- LOAD_AND_RECONCILE: standalone runner path (ESS-only, no BIP).
--   Retained for dev/test but not used by the production pipeline.
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

    -- Parse the decoded BIP report XMLTYPE (from DMT_UTIL_PKG.RUN_BIP_REPORT)
    -- and update TFM + STG tables.
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml            IN XMLTYPE
    );

    -- Standalone runner path (ESS-only, retained for dev/test).
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER,
        p_fbdi_zip       IN BLOB,
        p_filename       IN VARCHAR2
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
