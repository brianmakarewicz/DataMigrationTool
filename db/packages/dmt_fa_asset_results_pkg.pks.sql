-- PACKAGE DMT_FA_ASSET_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FA_ASSET_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_FA_ASSET_RESULTS_PKG
-- Post-load reconciliation for Assets — Contract v1 (nine-column report).
--
-- Reuses the ONE shared Contract v1 fetch DMT_RECON_CONTRACT_PKG.FETCH_ROWS
-- (Option A, owner decision on PR #248), exactly as the Workers / Requisitions
-- templates do. A single fetch runs the Assets Contract v1 report (nine columns,
-- keyset paginated) over BIP and returns the report's rows in one collection;
-- each row's OBJECT_TYPE identifies its tier.
--
-- Assets emits ONE apply tier — the ASSET (header) — because the Contract v1
-- data model (DMT_FA_ASSET_RECON_DM.xdm, fixed #344) reports one BASE row per
-- ASSET_NUMBER (a scalar subquery folds the book into OBJECT_TYPE for display so
-- the keyset stays one-row-per-ASSET_NUMBER) and one INTERFACE row per rejected
-- asset. OBJECT_TYPE is 'Assets' or 'Assets [<BOOK>]', so the apply matches on
-- the OBJECT_TYPE prefix 'Assets', not an exact literal.
--
--   Tier     OBJECT_TYPE literal     TFM table                    FUSION_ID column
--   ASSET    'Assets' / 'Assets [.]' DMT_FA_ASSET_HDR_TFM_TBL     FUSION_ASSET_ID
--
-- The apply is STATIC SQL, one pair of UPDATEs, joined on
-- RECON_KEY = the report RECORD_KEY (= prefixed ASSET_NUMBER, stamped by
-- DMT_FA_ASSET_TRANSFORM_PKG). The book and assignment TFM tables have no report
-- tier of their own; they inherit the header outcome by the existing cascade.
--
-- ALL-OR-NOTHING (Assets-only, preserved): the nine-column apply gives the
-- per-row POSITIVE proof for assets that reach FA_ADDITIONS_B and the real Fusion
-- error for interface rejections. The SQL*Loader LOAD stage is atomic per book
-- (a WARNING commits zero rows), so when a whole book's load genuinely failed and
-- nothing reached the interface the report has nothing to confirm; ACCOUNT_ALL_OR_
-- NOTHING then reads the SQL*Loader log and gives those rows a real verdict. That
-- log path is UNCHANGED by the Contract v1 migration.
--
-- The BIP report path + CONTRACT_VERSION are read from DMT_BIP_REPORT_TBL at
-- runtime by the shared fetch. CEMLI_CODE: 'Assets'.
-- ============================================================
    -- GET_PARTITION_KEYS — distinct spawn-per-partition tokens (BOOK_TYPE_CODE)
    -- for one run, STATIC SQL over this object's own asset-book transform table.
    -- Called through DMT_QUEUE_WORKER_PKG.invoke_registered (style KEYS); one
    -- child work item is spawned per token, which the engine treats as opaque.
    FUNCTION GET_PARTITION_KEYS (p_run_id IN NUMBER) RETURN DMT_PARTITION_KEY_TBL;

    -- Main entry point: call after POLL_ESS_JOB completes. Runs the shared
    -- Contract v1 fetch + static header apply, cascades to book/assignment, then
    -- runs the all-or-nothing SQL*Loader log path. p_load_ess_id is the Contract
    -- v1 P_LOAD_REQUEST_ID; the report's run-scoped selectors (P_RUN_ID, P_PREFIX)
    -- pick up the whole run. p_import_ess_id / p_work_queue_id retained for the
    -- registered-signature contract (p_work_queue_id scopes all-or-nothing to a
    -- book partition).
    PROCEDURE RECONCILE_BATCH (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL);
END DMT_FA_ASSET_RESULTS_PKG;
/
