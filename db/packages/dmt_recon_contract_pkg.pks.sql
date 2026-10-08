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
-- collection of the standard response fields, and RETURNS that collection:
--
--   OBJECT_TYPE   RECORD_KEY   SOURCE_TYPE('BASE'|'INTERFACE')
--   FUSION_STATUS('SUCCESS'|'ERROR')   FUSION_ID   ERROR_MESSAGE   LOAD_REQUEST_ID
--   DFF_KEY (tier 2, from DMT_REFERENCE)   BUSINESS_KEY (tier 3, from SOURCE_REF)
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

    -- The Contract v1 response fields, one record per report row.
    --
    -- Backlog #65 (three-tier reconcile match, owner-directed order on PR #481):
    -- the APPLY in each object's reconciler resolves its Fusion match in priority
    -- order, falling through only when the higher tier does not resolve a TFM row --
    --   (1) RECORD_KEY    the Slot A native stamped reference (as today, PRIMARY);
    --                     match TFM.RECON_KEY = RECORD_KEY.
    --   (2) DFF_KEY       the Slot C DFF ATTRIBUTE reference (DMT_REFERENCE column of
    --                     the recon report, the DMT:run:queue:tfm stamp). Tried ONLY
    --                     when tier 1 matched no TFM row (RECORD_KEY null, or stamped
    --                     ref did not round-trip). The trailing ':'/'~'-delimited
    --                     segment of DFF_KEY is TFM_SEQUENCE_ID (see DMT_REF_ID_PKG
    --                     .BUILD_REF), so the APPLY matches TFM_SEQUENCE_ID to it.
    --   (3) BUSINESS_KEY  the object's native business key (SOURCE_REF column of the
    --                     recon report). The last-resort fallback, tried ONLY when
    --                     tiers 1 and 2 both resolved nothing -- match the object's
    --                     own business-key TFM column to it.
    -- Tier 1 stays primary and unchanged, so existing loaded outcomes are identical;
    -- the fall-through is driven by a zero-row tier-1 UPDATE (SQL%ROWCOUNT = 0), so a
    -- row that matches on RECORD_KEY never touches tier 2 or 3. Driving the
    -- fall-through off match failure (not off a null report value) keeps keyset
    -- pagination -- which orders by RECORD_KEY -- unchanged.
    --
    -- DFF_KEY and BUSINESS_KEY ride the nine-column recon report that every Contract
    -- v1 DM already emits (SOURCE_REF = column 8, DMT_REFERENCE = column 9). A DM that
    -- genuinely has no DFF carrier emits NULL DMT_REFERENCE -> DFF_KEY is null and
    -- tier 2 is skipped. FETCH_ROWS parses them tolerantly: a DM that does not emit
    -- the element at all simply yields NULL (the XMLTABLE PATH returns NULL for an
    -- absent node), so no DM change is forced and behaviour is preserved.
    TYPE T_RECON_ROW IS RECORD (
        OBJECT_TYPE     VARCHAR2(100),
        RECORD_KEY      VARCHAR2(1000),
        SOURCE_TYPE     VARCHAR2(20),    -- 'BASE' | 'INTERFACE'
        FUSION_STATUS   VARCHAR2(20),    -- 'SUCCESS' | 'ERROR'
        FUSION_ID       VARCHAR2(200),   -- base Fusion id OR a line-grain composite
                                         -- (e.g. INVOICE_ID~LINE_NUMBER); VARCHAR2 so a
                                         -- '~'-joined composite id can ride the contract
                                         -- (a plain numeric id still converts implicitly).
        ERROR_MESSAGE   VARCHAR2(4000),
        LOAD_REQUEST_ID VARCHAR2(100),
        -- Backlog #65 tiers 2 and 3. Both nullable; populated from the report's
        -- DMT_REFERENCE (Slot C DFF) and SOURCE_REF (business key) columns.
        DFF_KEY         VARCHAR2(1000),  -- tier 2: Slot C DFF ATTRIBUTE reference
        BUSINESS_KEY    VARCHAR2(1000)   -- tier 3: object native business key
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
    --   p_work_queue_id the work item's queue id, sent as P_WQ_ID ONLY when not
    --                   NULL. Used solely by the Projects report (owner-approved
    --                   exception 2026-10-07, design section 5): Fusion stamps no
    --                   job id on the project base tables, so that report selects
    --                   the work item's projects by the reference DMT stamps,
    --                   '<run_id>:<work_queue_id>:<legacy reference>'. Every other
    --                   caller leaves it NULL and its report never sees P_WQ_ID.
    --   p_fusion_batch_id  optional: the Fusion import batch id this load sent, for an
    --                   object whose base tables carry that batch rather than the
    --                   import job id (Customers: HZ_* base REQUEST_ID = the bulk
    --                   import batch id). Sent as the report parameter
    --                   P_FUSION_BATCH_ID only when not NULL, so every other object's
    --                   report call is unchanged. (Added 2026-10-07.)
    -- --------------------------------------------------------
    PROCEDURE FETCH_ROWS (
        p_cemli_code    IN  VARCHAR2,
        p_run_id        IN  NUMBER,
        p_load_ess_id   IN  NUMBER   DEFAULT NULL,
        p_import_ess_id IN  NUMBER   DEFAULT NULL,
        p_row_cap       IN  NUMBER   DEFAULT NULL,
        x_rows          OUT T_RECON_TBL,
        x_error_code    OUT NUMBER,
        p_work_queue_id IN  NUMBER   DEFAULT NULL,
        p_fusion_batch_id IN NUMBER  DEFAULT NULL
    );

END DMT_RECON_CONTRACT_PKG;
/
