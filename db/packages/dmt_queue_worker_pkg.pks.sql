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
    -- x_awaiting_base (HDL base-table lag retry, 2026-09-17): of the unaccounted
    -- rows, how many are still GENERATED AND carry no [FUSION_ERROR] tag — rows
    -- awaiting async base-table confirmation rather than per-record HDL failures.
    -- Computed in the SAME dynamic SELECT as the other counts (no new dynamic-SQL
    -- site). Only the HDL base-lag deferral in RECONCILE_ONE reads it; other callers
    -- pass a throwaway. It is a plain OUT (PL/SQL OUT cannot carry a DEFAULT), so
    -- every caller supplies a variable — the two non-HDL callers ignore its value.
    PROCEDURE ACCOUNT_ROWS (
        p_run_id        IN  NUMBER,
        p_cemli_code    IN  VARCHAR2,
        x_total         OUT NUMBER,
        x_loaded        OUT NUMBER,
        x_failed        OUT NUMBER,
        x_unaccounted   OUT NUMBER,
        p_work_queue_id IN  NUMBER DEFAULT NULL,
        x_awaiting_base OUT NUMBER
    );

    -- ------------------------------------------------------------
    -- SWEEP_UNACCOUNTED — the one shared unaccounted sweep (design
    -- section 5 record-accounting rule + the [UNACCOUNTED] tag row,
    -- owner directive 2026-07-21). Called from RECONCILE_ONE after an
    -- object's RECONCILE_BATCH: every TFM row of the object still
    -- GENERATED for this run is set to the real terminal status
    -- UNACCOUNTED and the bare [UNACCOUNTED] tag is appended to
    -- ERROR_TEXT (no other text). Does NOT commit — the caller owns the
    -- transaction. Scope RUN_ID always; add WORK_QUEUE_ID only for a
    -- spawn-per-partition child (mirrors ACCOUNT_ROWS / the gate). This
    -- is the ONLY writer of UNACCOUNTED; no per-reconciler code sets it.
    -- ------------------------------------------------------------
    PROCEDURE SWEEP_UNACCOUNTED (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

    -- ------------------------------------------------------------
    -- RECONCILE_VIA_REGISTRY — the ONE reconcile dispatch (backlog
    -- item #7 "reconcile registered in two places / fail-open").
    -- Looks up the object's RECON_PROC / RECON_HAS_CEMLI_ARG from
    -- DMT_PIPELINE_DEF_TBL and invokes it through the sanctioned
    -- invoke_registered site — the SAME registry-driven path the
    -- queue's RECONCILE_ONE uses. This replaces the loader's two
    -- hardcoded IF/ELSIF reconcile chains (submit_and_reconcile_one
    -- and the generic single-load path), so an object is registered
    -- in ONE place, not two that can silently drift.
    --
    -- Fail-open guard (Rule #1) preserved: if the object has no
    -- RECON_PROC registered, this RAISES ORA-20044 — never a silent
    -- success without base-table confirmation. This is the same
    -- guard the retired loader ELSE arm carried, now at the single
    -- dispatch site.
    --
    -- Called by DMT_LOADER_PKG's inline reconcile path (grouped
    -- objects that submit multiple ESS jobs per object, and SYNC
    -- objects) and by any direct RUN_* call. The queue's own
    -- RECONCILE_ONE keeps calling invoke_registered directly.
    -- ------------------------------------------------------------
    PROCEDURE RECONCILE_VIA_REGISTRY (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

    -- ------------------------------------------------------------
    -- INVOKE_APPLY — dispatch an object's thin static apply procedure
    -- (APPLY_<OBJ>) through the SAME sanctioned invoke_registered site the
    -- queue already uses. The generic recon engine (DMT_RECON_ENGINE_PKG) has
    -- already staged the parsed nine-column report into DMT_RECON_STAGE_GTT;
    -- this hands off to the object's own package, which reads that GTT and
    -- MERGEs into its LITERALLY-named TFM table with STATIC SQL.
    --
    -- p_apply_proc is a PKG.PROC name (validated by invoke_registered's
    -- allow-pattern), NEVER a table or column name. It is invoked with the RECON
    -- style (p_run_id, p_load_ess_id, p_import_ess_id, p_work_queue_id) so no new
    -- dispatch style and no new dynamic-SQL site is added — the three-site rule
    -- (invoke_registered / ACCOUNT_ROWS / SWEEP_UNACCOUNTED) is unchanged. The
    -- apply proc uses only p_run_id (and p_work_queue_id when scoping a child);
    -- the ESS ids are along for the RECON signature.
    -- ------------------------------------------------------------
    PROCEDURE INVOKE_APPLY (
        p_apply_proc    IN VARCHAR2,
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_load_ess_id   IN NUMBER   DEFAULT NULL,
        p_import_ess_id IN NUMBER   DEFAULT NULL,
        p_work_queue_id IN NUMBER   DEFAULT NULL
    );

END DMT_QUEUE_WORKER_PKG;
/
