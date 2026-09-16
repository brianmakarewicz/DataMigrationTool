-- PACKAGE DMT_RECON_CONTRACT_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_RECON_CONTRACT_PKG" AS
-- ============================================================
-- DMT_RECON_CONTRACT_PKG  —  the ONE shared Contract v1 reconciliation FETCH.
-- ============================================================
-- Written once; every Contract-v1 object's BIP data model conforms to it
-- (design section 5, "BIP reconciliation report contract - v1"). Given a CEMLI
-- code, FETCH reads ONLY that object's report catalog path + parameters from
-- DMT_BIP_REPORT_TBL, runs the object's Contract v1 report over BIP (shared
-- transport DMT_UTIL_PKG.RUN_BIP_REPORT), pages through the result with keyset
-- pagination (P_AFTER_KEY loops until a short page), parses every page into a
-- collection of the SEVEN standard response fields, and RETURNS that collection:
--
--   OBJECT_TYPE   RECORD_KEY   SOURCE_TYPE('BASE'|'INTERFACE')
--   FUSION_STATUS('SUCCESS'|'ERROR')   FUSION_ID   ERROR_MESSAGE   LOAD_REQUEST_ID
--
-- The APPLY (turning these rows into LOADED/FAILED on a TFM table) lives in each
-- object's own reconciler, as STATIC SQL against that object's compile-time-known
-- TFM table -- see DMT_WORKER_RESULTS_PKG for the template. This split (Option A,
-- owner decision on PR #248) keeps this shared package free of ANY dynamic SQL:
-- it never names a TFM table or Fusion-id column and has ZERO EXECUTE IMMEDIATE,
-- so the design's dynamic-SQL restriction (Coding Standards section) needs no
-- amendment.
--
-- FETCH-side rules retained here:
--   * Zero report rows -> returns an EMPTY collection (never a silent success;
--     the caller applies its own no-rows policy -- zero rows is never LOADED).
--   * A SOAP fault / transport failure raises immediately (never a silent retry).
--   * Keyset pagination is bounded by a page-count cap derived from p_row_cap so
--     a misbehaving report cannot loop forever.
--
-- The APPLY-side rules (which each object's reconciler implements statically):
--   * BASE / SUCCESS / FUSION_ID NOT NULL  -> LOADED, stamp FUSION_ID.
--   * FUSION_STATUS = ERROR with a real ERROR_MESSAGE -> FAILED, message appended
--     as '[FUSION_ERROR] ' || message (never composed).
--   * Everything else is left for the shared unaccounted sweep. INTERFACE/SUCCESS
--     corroborates but is never sufficient for LOADED.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(30) := 'DMT_RECON_CONTRACT_PKG';

    -- The seven Contract v1 response fields, one record per report row.
    TYPE T_RECON_ROW IS RECORD (
        OBJECT_TYPE     VARCHAR2(100),
        RECORD_KEY      VARCHAR2(1000),
        SOURCE_TYPE     VARCHAR2(20),    -- 'BASE' | 'INTERFACE'
        FUSION_STATUS   VARCHAR2(20),    -- 'SUCCESS' | 'ERROR'
        FUSION_ID       NUMBER,
        ERROR_MESSAGE   VARCHAR2(4000),
        LOAD_REQUEST_ID VARCHAR2(100)
    );

    -- The full parsed result (all pages), returned by FETCH.
    TYPE T_RECON_TBL IS TABLE OF T_RECON_ROW INDEX BY PLS_INTEGER;

    -- --------------------------------------------------------
    -- FETCH_ROWS — run the object's Contract v1 report and RETURN its parsed rows.
    -- Touches NO TFM table; the caller applies the rows statically.
    --
    -- A PROCEDURE (not a function): it does network I/O (RUN_BIP_REPORT), so per
    -- the design's procedures-only rule it reports outcome via an OUT error code
    -- rather than being SQL-callable. Exceptions never escape — a transport/SOAP
    -- failure is logged and surfaced through x_error_code (x_rows left empty).
    --
    --   p_cemli_code    the object registered in DMT_BIP_REPORT_TBL (its report
    --                   catalog path is resolved by RUN_BIP_REPORT). CONTRACT_VERSION
    --                   must be 1 (else x_error_code = C_ERROR).
    --   p_run_id        the pipeline run id (Contract v1 P_RUN_ID).
    --   p_load_ess_id   the load job's request id (P_LOAD_REQUEST_ID). For HDL
    --                   objects this is the HDL data set request id.
    --   p_import_ess_id the import job's request id (P_IMPORT_ESS_ID, nullable).
    --   p_row_cap       expected upper bound on rows (usually the run's generated-
    --                   row count) used only to derive the keyset page-count cap.
    --                   NULL/0 falls back to a floor of 2 pages of slack.
    --   x_rows          OUT the parsed rows (empty when the report returns zero rows).
    --   x_error_code    OUT DMT_UTIL_PKG.C_SUCCESS or C_ERROR. On C_ERROR the failure
    --                   detail is in DMT_LOG_TBL and x_rows is empty.
    -- --------------------------------------------------------
    PROCEDURE FETCH_ROWS (
        p_cemli_code    IN  VARCHAR2,
        p_run_id        IN  NUMBER,
        p_load_ess_id   IN  NUMBER   DEFAULT NULL,
        p_import_ess_id IN  NUMBER   DEFAULT NULL,
        p_row_cap       IN  NUMBER   DEFAULT NULL,
        x_rows          OUT T_RECON_TBL,
        x_error_code    OUT NUMBER
    );

END DMT_RECON_CONTRACT_PKG;
/
