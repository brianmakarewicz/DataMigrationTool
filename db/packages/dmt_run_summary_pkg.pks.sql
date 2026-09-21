-- PACKAGE DMT_RUN_SUMMARY_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_RUN_SUMMARY_PKG" AS
-- ============================================================
-- DMT_RUN_SUMMARY_PKG  (backlog #66 — post-run base-table reporting)
--
-- Reports, for one run, which of our records landed in Fusion (with the real
-- Fusion id), which failed with a real error, which are unaccounted, and which
-- are still in flight. Everything reads the normalized per-record view
-- DMT_RUN_RECORDS_V, so there is ONE object list to keep in step with
-- DMT_RUN_STATUS_V and no per-object branching here.
--
-- Three read procedures, plus one live "prove it in Fusion" audit:
--
--   GET_RUN_ROLLUP  — per-object counts (TOTAL / LOADED / FAILED / UNACCOUNTED
--                     / GENERATED) plus the run header, aggregated from the view.
--   GET_RUN_RECORDS — the drillable per-record list from the view, optionally
--                     filtered by object and status, with the record's
--                     DMT_REFERENCE and a Fusion deep link built from the
--                     registry DEEP_LINK_KEY_TEMPLATE.
--   AUDIT_IN_FUSION — on demand, run the object's Contract v1 reconciliation
--                     report LIVE and return each returned base row joined to
--                     its TFM row by the tfm-seq id parsed out of the reference.
--
-- Honest accounting (design, "The accounting rule" + the UNACCOUNTED tag):
--   * LOADED       — the record is confirmed in a Fusion base table, FUSION_ID
--                    captured. The only positive success.
--   * FAILED       — the record carries a real Fusion error in ERROR_TEXT. A
--                    FAILED row with NO error text is not accounted — it is
--                    counted as UNACCOUNTED (the derived UNRECONCILED state),
--                    never as a clean failure.
--   * UNACCOUNTED  — the stored terminal status the shared honest sweep writes
--                    when reconciliation could neither confirm nor error a
--                    record. Counted as unaccounted.
--   * GENERATED    — still in flight (not yet settled). The TFM lifecycle is
--                    STAGED -> GENERATED -> LOADED/FAILED, so the rollup's
--                    GENERATED_ROWS bucket counts BOTH non-terminal statuses
--                    (STAGED and GENERATED) as one in-flight lane, which makes
--                    LOADED + FAILED + UNACCOUNTED + GENERATED partition TOTAL
--                    exactly. Reported separately so in-flight rows are never
--                    mistaken for a settled outcome.
--
-- The rollup counts are golden-equivalent to DMT_RUN_STATUS_V: for every object
-- TOTAL / LOADED / FAILED agree, and DMT_RUN_STATUS_V's OTHER_ROWS bucket is
-- split here into the honest UNACCOUNTED vs GENERATED pair.
--
-- Read-only: no INSERT / UPDATE / DELETE. All SQL is static against the view and
-- compile-time-known tables — NO EXECUTE IMMEDIATE anywhere. The live audit
-- reuses DMT_RECON_CONTRACT_PKG.FETCH_ROWS verbatim (that package owns all the
-- BIP transport); this package never touches a TFM table dynamically.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(30) := 'DMT_RUN_SUMMARY_PKG';

    -- --------------------------------------------------------
    -- GET_RUN_ROLLUP
    -- Per-object outcome counts for one run, plus the run header columns from
    -- DMT_PIPELINE_RUN_TBL repeated on each row (so a single fetch drives a
    -- header + rollup grid). Counts are aggregated from DMT_RUN_RECORDS_V using
    -- the design's exact accounting rule.
    --
    -- Cursor columns:
    --   RUN_ID, RUN_STATUS, PIPELINE_CODES, PREFIX, SCENARIO_NAME,
    --   SUBMITTED_DATE, COMPLETED_DATE,          -- run header (repeated)
    --   OBJECT_TYPE,                             -- the split object label
    --   CEMLI_CODE,                              -- the base CEMLI (registry key)
    --   TOTAL_ROWS, LOADED_ROWS, FAILED_ROWS,
    --   UNACCOUNTED_ROWS, GENERATED_ROWS
    -- Ordered by OBJECT_TYPE. Empty cursor when the run has no records.
    -- --------------------------------------------------------
    PROCEDURE GET_RUN_ROLLUP (
        p_run_id IN  NUMBER,
        x_cursor OUT SYS_REFCURSOR
    );

    -- --------------------------------------------------------
    -- GET_RUN_RECORDS
    -- The drillable per-record list for one run from DMT_RUN_RECORDS_V.
    --   p_object  optional filter on OBJECT_TYPE (the split label) — NULL = all.
    --   p_status  optional filter on the RAW stored TFM_STATUS (LOADED / FAILED
    --             / UNACCOUNTED / GENERATED / STAGED) — NULL = all. Note this is
    --             the raw status, not the rollup's folded bucket: the rollup
    --             counts STAGED under GENERATED, so to drill the rollup's
    --             GENERATED count fetch both p_status => 'GENERATED' and
    --             p_status => 'STAGED' (or p_status => NULL and filter in the UI).
    --
    -- Cursor columns:
    --   RUN_ID, WORK_QUEUE_ID, CEMLI_CODE, OBJECT_TYPE, SUB_OBJECT,
    --   TFM_SEQUENCE_ID, RECON_KEY, TFM_STATUS, FUSION_ID, ERROR_TEXT,
    --   DMT_REFERENCE,
    --   FUSION_DEEP_LINK   -- the registry DEEP_LINK_KEY_TEMPLATE with the
    --                         literal '{FUSION_ID}' replaced by FUSION_ID; NULL
    --                         when the object has no template or the row has no
    --                         Fusion id (never a fabricated link).
    -- Ordered by OBJECT_TYPE, TFM_SEQUENCE_ID.
    -- --------------------------------------------------------
    PROCEDURE GET_RUN_RECORDS (
        p_run_id IN  NUMBER,
        p_object IN  VARCHAR2 DEFAULT NULL,
        p_status IN  VARCHAR2 DEFAULT NULL,
        x_cursor OUT SYS_REFCURSOR
    );

    -- --------------------------------------------------------
    -- AUDIT_IN_FUSION
    -- On-demand live "prove it in Fusion" audit for ONE object of a run. Runs
    -- the object's Contract v1 reconciliation report live (via the shared
    -- DMT_RECON_CONTRACT_PKG.FETCH_ROWS — no new transport, no dynamic SQL) and
    -- returns each base row it got back, joined to the run's TFM record by the
    -- tfm-seq id parsed from the record's reference. This never writes anything
    -- and never fabricates: a record whose id does not come back is simply
    -- absent from the result (its stored TFM_STATUS in GET_RUN_RECORDS stands).
    --
    --   p_run_id      the pipeline run to prove.
    --   p_cemli_code  the object to prove. It MUST be registered in
    --                 DMT_BIP_REPORT_TBL with CONTRACT_VERSION = 1; otherwise
    --                 x_error_code = C_ERROR, the reason is logged, and the
    --                 cursor is returned empty (the audit only supports the
    --                 Contract v1 shape).
    --   x_cursor      OUT one row per Contract v1 report row:
    --                   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
    --                   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID,   -- as returned
    --                   TFM_SEQUENCE_ID, DMT_REFERENCE, TFM_STATUS,  -- joined TFM
    --                   STORED_FUSION_ID
    --                 The join is by the tfm-seq id parsed from the reference:
    --                 TO_NUMBER(REGEXP_SUBSTR(NVL(DMT_REFERENCE, SOURCE_REF),
    --                 '[^:]+', 1, 4)) where SOURCE_REF is the reference the
    --                 report carried in LOAD_REQUEST_ID's provenance. A report
    --                 row that does not match a TFM record of this run still
    --                 appears, with the TFM columns NULL (honest — we return
    --                 exactly what Fusion gave us).
    --   x_error_code  OUT C_SUCCESS or C_ERROR (detail logged on C_ERROR).
    -- --------------------------------------------------------
    PROCEDURE AUDIT_IN_FUSION (
        p_run_id     IN  NUMBER,
        p_cemli_code IN  VARCHAR2,
        x_cursor     OUT SYS_REFCURSOR,
        x_error_code OUT NUMBER
    );

END DMT_RUN_SUMMARY_PKG;
/
