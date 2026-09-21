-- PACKAGE DMT_CUST_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CUST_RESULTS_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_CUST_RESULTS_PKG
-- Post-load BIP reconciliation for Customers (ONE object, seven
-- HZ record types loaded by a single ESS bulkImport job).
--
-- Contract v1 (design section 5), mirroring the proven Items reconciler
-- DMT_EGP_ITEM_RESULTS_PKG (PR #368):
--   * the shared package DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the
--     Customers nine-column recon report over BIP and RETURNS the parsed
--     rows (no dynamic SQL, no TFM reference, keyset paged);
--   * the APPLY is STATIC SQL against the seven Customer TFM tables, keyed
--     on RECON_KEY = the report's RECORD_KEY, dispatched by OBJECT_TYPE;
--   * the ONLY path to LOADED is a BASE-tier SUCCESS row with a non-null
--     FUSION_ID; a real ERROR message -> FAILED; everything else is left
--     for the shared unaccounted sweep (never fabricated);
--   * outcomes are written to the seven TFM tables only -- nothing is
--     written back to staging. CEMLI_CODE: 'Customers'.
--
-- RECONCILE_BATCH keeps its public 4-argument signature: the pipeline
-- definition calls DMT_CUST_RESULTS_PKG.RECONCILE_BATCH(run_id, load_ess_id,
-- import_ess_id, work_queue_id) and is unaffected. The former public
-- FETCH_BIP_RESULTS / PARSE_AND_UPDATE are retired: the shared fetch and
-- the private static APPLY replace them.
-- ============================================================

    PROCEDURE RECONCILE_BATCH (
        p_run_id          IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

END DMT_CUST_RESULTS_PKG;
/
