-- PACKAGE DMT_QUEUE_WORKER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_QUEUE_WORKER_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_QUEUE_WORKER_PKG — Child job entry points
--
-- Separate package from DMT_QUEUE_PKG so that one-shot child
-- jobs (DMT_WQ_*, DMT_RC_*) don't acquire a library cache lock
-- on the heartbeat package. This prevents self-deadlock when the
-- heartbeat spawns children via DBMS_SCHEDULER.CREATE_JOB.
-- ============================================================

    -- Execute one queue row: validate + transform + generate + submit.
    PROCEDURE EXECUTE_ONE (p_queue_id IN NUMBER);

    -- Reconcile one queue row via BIP, then settle it through the
    -- accounting gate (the ONE writer of WORK_STATUS = DONE).
    PROCEDURE RECONCILE_ONE (p_queue_id IN NUMBER);

    -- Poll ESS status for one queue row (single check, no loop).
    -- Advances AWAITING_LOAD → AWAITING_IMPORT or RECONCILING.
    -- Advances AWAITING_IMPORT → RECONCILING.
    -- Timeout (ESS_POLL_TIMEOUT_MINUTES config) marks GENERATED rows
    -- FAILED [LOAD_ERROR] and routes to reconcile — never a verdict
    -- (design section 2 "Timeouts (decided 2026-07-07)").
    PROCEDURE POLL_ONE (p_queue_id IN NUMBER);

    -- Run one run's pipeline preflight in a child job (off the heartbeat
    -- tick, so the live Fusion calls never stall dispatch/polling):
    -- refresh the Fusion name->id lookups and verify every credential the
    -- run will use. On success sets DMT_PIPELINE_RUN_TBL.PREFLIGHT_STATUS
    -- = 'OK' so the run's work items may dispatch; on failure sets 'FAILED'
    -- and FAILs the run's not-yet-terminal work items (the heartbeat rollup
    -- then settles the run FAILED). Spawned by DMT_QUEUE_PKG.run_preflights;
    -- the run is already claimed 'PREFLIGHTING' before this is spawned.
    PROCEDURE PREFLIGHT_ONE (p_run_id IN NUMBER);

    -- ------------------------------------------------------------
    -- Catalog-driven row accounting (design section 5 "Object-status
    -- accounting" + Overview work-item status table, DONE/FAILED rows).
    -- Counts one object's TFM rows for one run from the record-type
    -- registry DMT_CEMLI_CATALOG_TBL (TFM_TABLE + STATUS_COLUMN +
    -- ROW_FILTER per record type). Whole-object accounting: partition-
    -- aware accounting (PARTITION_KEY other than ALL/NULL) is the
    -- Stage C task-5 partition work item.
    --   x_unaccounted = rows neither LOADED nor FAILED-with-ERROR_TEXT
    --   (FAILED with empty ERROR_TEXT is the derived UNRECONCILED
    --   bucket — it counts as unaccounted; Overview row-status table).
    -- Public so the heartbeat's run rollup reads the same numbers.
    -- ------------------------------------------------------------
    -- p_work_queue_id (work-queue-ID core, 2026-07-20): when set, the counts are
    -- scoped to just that work-queue item's rows (AND WORK_QUEUE_ID = it), so a
    -- spawn-per-partition child settles on its OWN rows only and is not failed by
    -- a sibling batch's still-unloaded rows. NULL = the run-scoped count exactly
    -- as before (the heartbeat run rollup and every non-spawn object pass NULL).
    PROCEDURE ACCOUNT_ROWS (
        p_run_id        IN  NUMBER,
        p_cemli_code    IN  VARCHAR2,
        x_total         OUT NUMBER,
        x_loaded        OUT NUMBER,
        x_failed        OUT NUMBER,
        x_unaccounted   OUT NUMBER,
        p_work_queue_id IN  NUMBER DEFAULT NULL
    );

    -- ------------------------------------------------------------
    -- Catalog-driven [LOAD_ERROR] row marking (design section 5 tag
    -- table, [LOAD_ERROR] row: "When the load ESS job fails, every
    -- GENERATED row of that ZIP is marked FAILED with this tag plus
    -- the job's diagnostics" — all-or-nothing, whole ZIP). Also the
    -- timeout trigger path (section 2 Timeouts). p_error_text must
    -- already carry the [LOAD_ERROR] tag; it is APPEND_ERROR'ed so
    -- history accumulates, never overwrites.
    -- ------------------------------------------------------------
    PROCEDURE MARK_GENERATED_ROWS_FAILED (
        p_run_id     IN NUMBER,
        p_cemli_code IN VARCHAR2,
        p_error_text IN VARCHAR2
    );

END DMT_QUEUE_WORKER_PKG;
/
