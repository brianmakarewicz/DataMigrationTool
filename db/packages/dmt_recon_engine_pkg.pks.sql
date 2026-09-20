-- PACKAGE DMT_RECON_ENGINE_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_RECON_ENGINE_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_RECON_ENGINE_PKG  —  the ONE generic Contract v1 reconcile.
-- ============================================================
-- Every Contract v1 object's BIP report returns the SAME nine columns
-- (design section 5, "BIP reconciliation report contract - v1"). The
-- reference reconciler DMT_GL_RESULTS_PKG proved the shape end-to-end:
-- keyset-page the nine-column report into ONE collection, then apply the
-- whole run in a handful of SET-BASED statements (no per-row loop). This
-- package EXTRACTS that shape so every object reuses it instead of copying
-- the per-object body.
--
-- RECONCILE(p_run_id, p_cemli_code, p_load_request_id, p_import_ess_id):
--   1. FETCH  — delegates to the existing shared fetch
--      DMT_RECON_CONTRACT_PKG.FETCH_ROWS: reads the object's report catalog
--      path from DMT_BIP_REPORT_TBL, runs the Contract v1 report with keyset
--      pagination (empty P_AFTER_KEY first, last RECORD_KEY fed back, page
--      size from BIP_CHUNK_SIZE config, page cap from the generated-row
--      count), and returns the parsed rows. That package already does the
--      generic, dynamic-SQL-free fetch, so the engine does not duplicate it.
--   2. APPLY  — two SET-BASED MERGEs, built GENERICALLY from the object's
--      registry-named TFM table / status column / fusion-id column / recon-key
--      column. Same two statements as the reference: one marks LOADED on a
--      BASE/SUCCESS row (capturing FUSION_ID); one marks FAILED on an ERROR
--      row (capturing the real Fusion message, appended '[FUSION_ERROR] ').
--      The identifiers are read from the seeded registry and pattern-asserted
--      (assert_ident, the same posture as DMT_QUEUE_WORKER_PKG.ACCOUNT_ROWS /
--      assert_catalog_identifier) before any concatenation; every value is
--      bound. No unsafe dynamic SQL.
--   3. ROUND-TRIP — one set-based diagnostic MERGE-free SELECT logs a single
--      WARN if any just-LOADED base row's DMT_REFERENCE does not equal
--      BUILD_REF for its TFM row (design round-trip proof). Diagnostic only;
--      never changes a verdict. Run only when the TFM table carries the
--      WORK_QUEUE_ID + identity-PK columns BUILD_REF needs (the reference
--      shape); skipped with an INFO otherwise.
--
-- Rows with no match and no error STAY GENERATED — the shared unaccounted
-- sweep (DMT_QUEUE_WORKER_PKG.SWEEP_UNACCOUNTED), never this engine, settles
-- them. Nothing is ever fabricated LOADED/FAILED. Honest accounting preserved.
--
-- Object-specific nuances (e.g. GL balanced-vs-unbalanced) live in the DM's
-- FUSION_STATUS normalization (SUCCESS/ERROR), NOT here. The engine is
-- object-agnostic: it only ever reads registry-named identifiers and the nine
-- standard columns.
--
-- Registry columns read (DMT_BIP_REPORT_TBL, one row per CEMLI):
--   CONTRACT_VERSION   must be 1 (else the object is legacy/bespoke — skip).
--   TFM_TABLE          the TFM table this engine updates.
--   FUSION_ID_COLUMN   the TFM column stamped with the Fusion base-table id
--                      on a BASE/SUCCESS row.
--   STATUS_COLUMN      the TFM status column (added; defaults to TFM_STATUS).
--   RECON_KEY_COLUMN   the TFM column matched to the report's RECORD_KEY
--                      (added; defaults to RECON_KEY).
-- ============================================================

    -- --------------------------------------------------------
    -- RECONCILE — the generic Contract v1 reconcile entry point.
    -- Signature matches the RECON dispatch style in
    -- DMT_QUEUE_WORKER_PKG.invoke_registered EXACTLY (p_run_id,
    -- p_load_ess_id, p_import_ess_id, p_work_queue_id), so an object's
    -- RECON_PROC can point straight at DMT_RECON_ENGINE_PKG.RECONCILE with
    -- RECON_HAS_CEMLI_ARG = 'N'. p_cemli_code identifies the object's
    -- registry row.
    --
    --   p_run_id          the pipeline run id (Contract v1 P_RUN_ID).
    --   p_cemli_code      the object registered in DMT_BIP_REPORT_TBL
    --                     (CONTRACT_VERSION must be 1).
    --   p_load_request_id the load job's request id (P_LOAD_REQUEST_ID).
    --   p_import_ess_id   the import job's request id (P_IMPORT_ESS_ID, nullable).
    --   p_work_queue_id   NULL for a single-item object; the child queue id for a
    --                     spawn-per-partition child (scopes both MERGEs to that
    --                     item's own rows). Optional (default NULL).
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
    -- RECONCILE_BATCH — thin RECON_PROC-compatible wrapper. Its parameter
    -- NAMES match the RECON_CEMLI dispatch style in
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
