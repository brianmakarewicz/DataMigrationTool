-- PACKAGE DMT_AR_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AR_RESULTS_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AR_RESULTS_PKG
-- Post-load reconciliation for ARInvoices — Contract v1, MULTI-TIER.
--
-- Reuses the ONE shared Contract v1 fetch DMT_RECON_CONTRACT_PKG.FETCH_ROWS
-- (Option A, owner decision on PR #248), exactly as the Workers and Requisitions
-- templates do. A single fetch runs the ARInvoices Contract v1 report (nine
-- columns, keyset paginated) over BIP and returns BOTH tiers' rows in one
-- collection; each row's OBJECT_TYPE says which tier it belongs to. The apply is
-- STATIC SQL, one pair of UPDATEs per tier, joined on RECON_KEY = report
-- RECORD_KEY.
--
--   Tier           OBJECT_TYPE literal          TFM table               FUSION_ID column
--   lines          'ARInvoices'                 DMT_RA_LINES_TFM_TBL     FUSION_CUSTOMER_TRX_ID
--   distributions  'ARInvoices.Distribution'    DMT_RA_DISTS_TFM_TBL     FUSION_CUST_TRX_LINE_GL_DIST_ID
--
-- RECON_KEY per tier (stamped by DMT_AR_TRANSFORM_PKG, = each tier's report
-- RECORD_KEY): BOTH tiers = INTERFACE_LINE_ATTRIBUTE1 (the prefixed TRX_NUMBER).
-- The AR base distribution carries no interface key of its own, so a distribution
-- is confirmed TRANSITIVELY through its parent line: the data model emits the
-- parent line's stamped key as the distribution RECORD_KEY, and a BASE
-- distribution row for that key is positive proof the line's distributions
-- landed.
--
-- After the per-row apply, RECONCILE_BATCH propagates each rejected row's real
-- Fusion error to the other rows of the same Fusion invoice (AutoInvoice
-- grouping), before the shared UNACCOUNTED sweep (design section 5,
-- whole-document rejection, decided 2026-10-07).
--
-- The BIP report path + CONTRACT_VERSION are read from DMT_BIP_REPORT_TBL at
-- runtime by the shared fetch. CEMLI_CODE: 'ARInvoices'.
-- ============================================================

    -- Main entry point: call after POLL_ESS_JOB completes. Runs the shared
    -- Contract v1 fetch + per-tier apply. p_load_ess_id is the Contract v1
    -- P_LOAD_REQUEST_ID; the report's run-scoped selectors (P_PREFIX) pick up the
    -- whole run. p_import_ess_id / p_work_queue_id retained for the
    -- registered-signature contract.
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
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

    -- Cross-grain propagation working set (private PROPAGATE_DOCUMENT_ERRORS).
    -- Declared in the spec ONLY so the procedure's static MERGEs can read the
    -- collection through TABLE(); it is not an API. One element = "the line
    -- TARGET_LINE_SEQ belongs to the same Fusion invoice (AutoInvoice grouping) as
    -- the source row SOURCE_SEQ (an AR line or distribution with its own real
    -- Fusion error), and must carry QUOTED_ERROR".
    TYPE T_DOC_PAIR IS RECORD (
        TARGET_LINE_SEQ NUMBER,          -- DMT_RA_LINES_TFM_TBL.TFM_SEQUENCE_ID
        SOURCE_KIND     VARCHAR2(4),     -- 'LINE' | 'DIST'
        SOURCE_SEQ      NUMBER,          -- TFM_SEQUENCE_ID in the source's own table
        QUOTED_ERROR    VARCHAR2(4000)   -- DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(...)
    );
    TYPE T_DOC_PAIR_TBL IS TABLE OF T_DOC_PAIR;

END DMT_AR_RESULTS_PKG;
/
