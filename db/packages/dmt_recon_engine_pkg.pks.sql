-- PACKAGE DMT_RECON_ENGINE_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_RECON_ENGINE_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_RECON_ENGINE_PKG — the ONE generic Contract v1 reconcile engine.
-- ============================================================
-- Every Contract v1 object's BIP recon report returns the SAME nine columns
-- (design section 5, "BIP reconciliation report contract — v1"). This package
-- owns the parts that are TRULY generic and need NO dynamic SQL, because the
-- report shape is fixed at compile time:
--
--   1. FETCH  — keyset-page the nine-column report. Empty P_AFTER_KEY on the
--               first call, last RECORD_KEY fed back on each next call, page
--               size from BIP_CHUNK_SIZE config, page cap derived from the run
--               (a fixed floor — the engine does NOT read the object's TFM
--               table for a count, which would need the table name as data).
--               Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT. All six
--               Contract v1 params are bound.
--   2. PARSE  — decode each page with XMLTABLE over the nine FIXED columns
--               (static SQL — the column list is a compile-time constant).
--   3. STAGE  — STATIC INSERT of the parsed rows into the generic session GTT
--               DMT_RECON_STAGE_GTT, keyed by RUN_ID (the GTT column list is
--               fixed; no dynamic SQL). The engine first deletes this RUN_ID's
--               own rows so a re-run starts clean.
--   4. ROUND-TRIP — a set-based diagnostic over the GTT: WARN once if any
--               BASE/SUCCESS row's DMT_REFERENCE (Slot C) does not equal what
--               DMT_REF_ID_PKG.BUILD_REF reconstructs from the parsed values.
--               Static SQL against the fixed GTT columns; NEVER changes a
--               verdict.
--   5. APPLY  — the engine does NOT touch the object's TFM table. It DISPATCHES
--               to the object's OWN thin static procedure APPLY_<OBJ>(p_run_id,
--               ...) through the EXISTING sanctioned dynamic-invocation site
--               DMT_QUEUE_WORKER_PKG.invoke_registered (style RECON). That proc
--               reads DMT_RECON_STAGE_GTT and MERGEs into its LITERALLY-named
--               TFM table with STATIC SQL. The TFM table name never appears as
--               data in this engine, so this engine contains NO dynamic SQL and
--               adds NO new dynamic-SQL site — the three-site rule
--               (invoke_registered / ACCOUNT_ROWS / SWEEP_UNACCOUNTED) is
--               unchanged (design section 7, dynamic-SQL rule).
--
-- WHY this shape (owner decision — Option 1): a generic dynamic MERGE that
-- names each object's TFM table from the registry was a FOURTH dynamic-SQL
-- site and was refused. The rule-safe split is: generic parse HERE (no dynamic
-- SQL), per-object STATIC apply in the object's OWN package, joined by the GTT
-- and reached through the one dispatch call that already exists — the same
-- pattern the partition-key work used (each object's GET_PARTITION_KEYS is
-- static SQL, called through invoke_registered's KEYS style).
--
-- Rows with no match and no error STAY GENERATED — the shared unaccounted
-- sweep (DMT_QUEUE_WORKER_PKG.SWEEP_UNACCOUNTED), never this engine or an
-- APPLY proc, settles them. Nothing is fabricated LOADED/FAILED.
--
-- Registry columns read (DMT_BIP_REPORT_TBL, one row per CEMLI):
--   CONTRACT_VERSION  must be 1 (else the object is legacy/bespoke — skip).
--   REPORT_CATALOG_PATH the deployed nine-column recon report (used by the
--                     shared transport, not by this engine directly).
--   APPLY_PROC        PKG.PROC of the object's thin static apply, invoked
--                     through invoke_registered (style RECON). This is the ONE
--                     new registry column; it is a PROCEDURE NAME (validated by
--                     invoke_registered's PKG.PROC allow-pattern), never a table
--                     or column name.
-- ============================================================

    -- --------------------------------------------------------
    -- RECONCILE — the generic Contract v1 reconcile entry point. Its parameter
    -- shape matches the RECON dispatch style in
    -- DMT_QUEUE_WORKER_PKG.invoke_registered (p_run_id, p_load_ess_id,
    -- p_import_ess_id, p_work_queue_id) plus p_cemli_code, so an object's
    -- RECON_PROC points at RECONCILE_BATCH (RECON_HAS_CEMLI_ARG = 'Y') and the
    -- shared queue engine invokes the generic reconcile with no code change.
    --
    --   p_run_id          the pipeline run id (Contract v1 P_RUN_ID).
    --   p_cemli_code      the object registered in DMT_BIP_REPORT_TBL
    --                     (CONTRACT_VERSION must be 1).
    --   p_load_request_id the load job's request id (P_LOAD_REQUEST_ID).
    --   p_import_ess_id   the import job's request id (P_IMPORT_ESS_ID, nullable).
    --   p_work_queue_id   NULL for a single-item object; the child queue id for a
    --                     spawn-per-partition child. Passed straight through to
    --                     the object's APPLY proc so its MERGE can scope to the
    --                     item's own rows. Optional (default NULL).
    --
    -- Exceptions propagate to the caller (RECONCILE_ONE) so a fetch/apply
    -- failure fails the item loudly (never a silent zero-row success).
    -- --------------------------------------------------------
    PROCEDURE RECONCILE (
        p_run_id          IN NUMBER,
        p_cemli_code      IN VARCHAR2,
        p_load_request_id IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id   IN NUMBER DEFAULT NULL
    );

    -- --------------------------------------------------------
    -- RECONCILE_BATCH — thin RECON_PROC-compatible wrapper. Its parameter NAMES
    -- match the RECON_CEMLI dispatch style in
    -- DMT_QUEUE_WORKER_PKG.invoke_registered exactly (that dispatch binds by
    -- name: p_run_id, p_cemli_code, p_load_ess_id, p_import_ess_id,
    -- p_work_queue_id), so an object's registry row can point RECON_PROC at
    -- DMT_RECON_ENGINE_PKG.RECONCILE_BATCH with RECON_HAS_CEMLI_ARG = 'Y' and
    -- the shared queue engine invokes the generic reconcile with no code change.
    -- Delegates straight to RECONCILE.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

END DMT_RECON_ENGINE_PKG;
/
