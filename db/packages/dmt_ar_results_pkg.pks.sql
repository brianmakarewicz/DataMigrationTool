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
-- RECORD_KEY): lines = INTERFACE_LINE_ATTRIBUTE1 || '/' || INTERFACE_LINE_ATTRIBUTE2
-- (report V3, unique per line); distributions = parent ATTRIBUTE1 || ':' ||
-- ACCOUNT_CLASS || ':' || per-line ordinal.
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
    -- Contract v1 fetch + per-tier apply for ONE (BU, batch source) group's
    -- load: p_load_ess_id is the Contract v1 P_LOAD_REQUEST_ID and
    -- p_import_ess_id the AutoInvoice import id; the report finds rows only by
    -- these two job ids. p_work_queue_id is the group's child work item: the
    -- cross-grain propagation and the shared sweep stay inside it. With no load
    -- id (a split parent work item) there is nothing to fetch and it returns.
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

    -- GET_PARTITION_KEYS -- spawn-per-partition keys (backlog #313). One JSON
    -- token per distinct (BU_NAME, BATCH_SOURCE_NAME) group of this run's STAGED
    -- AR lines, e.g. {"BU_NAME":"Progress US Business Unit","BATCH_SOURCE_NAME":
    -- "External Source"}. AutoInvoice takes exactly one business unit and one
    -- transaction source per submission (ParameterList arguments 1 and 2), so one
    -- group = one FBDI zip = one load + import = one child work item, and each
    -- child records its OWN load and import ids. STATIC SQL over this object's own
    -- transform table; called by the queue worker through invoke_registered
    -- (style KEYS, registry DMT_PIPELINE_DEF_TBL.PARTITION_KEYS_PROC).
    FUNCTION GET_PARTITION_KEYS (p_run_id IN NUMBER) RETURN DMT_PARTITION_KEY_TBL;

    -- RESET_UNACCOUNTED -- re-run-reconcile recovery (backlog #95). Static UPDATE
    -- over this object's OWN literally-named TFM table(s): flip this run's
    -- UNACCOUNTED rows back to GENERATED and strip the bare [UNACCOUNTED] tag so
    -- the next reconcile pass re-examines them. Dispatched by the queue worker
    -- through the sanctioned invoke_registered site (INVOKE_RESET, RECON style);
    -- the ESS-id args are ignored. NO dynamic SQL; NO COMMIT (caller owns the txn).
    PROCEDURE RESET_UNACCOUNTED (p_run_id IN NUMBER, p_load_ess_id IN NUMBER DEFAULT NULL,
        p_import_ess_id IN NUMBER DEFAULT NULL, p_work_queue_id IN NUMBER DEFAULT NULL);

END DMT_AR_RESULTS_PKG;
/
