-- PACKAGE DMT_GL_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GL_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_GL_RESULTS_PKG
-- Post-load BIP reconciliation for GL Balances - Contract v1, Option A.
--
-- GLBalances reconciles through the ONE shared Contract v1 parser
-- DMT_RECON_CONTRACT_PKG.FETCH_ROWS, exactly like the other ~29
-- conforming objects (the Workers / Expenditures / BillingEvents
-- template, owner decision Option A on PR #248). The shared parser
-- runs the object's nine-column recon report over BIP, keyset-pages
-- it, and returns the parsed rows; the APPLY here is STATIC SQL
-- against the compile-time-known DMT_GL_INTERFACE_TFM_TBL. There is no
-- GL-specific reader and no generic-engine dispatch any more (backlog
-- #92 conformance migration): the standalone keyset reader
-- FETCH_ALL_PAGES, the single-page FETCH_BIP_RESULTS, the XML
-- PARSE_AND_UPDATE overload, and the generic-engine APPLY_GL (which
-- read DMT_RECON_STAGE_GTT) are all retired.
--
-- GL two-tier semantics (FUSION_STATUS is normalized in the DM to
-- SUCCESS/ERROR, so the APPLY is object-agnostic):
--   BASE  + SUCCESS (balanced/postable)          => LOADED
--   BASE  + ERROR   (unbalanced; report V2 returns NO message, since
--                    Fusion records no error for it) => left GENERATED,
--                    settled UNACCOUNTED by the shared sweep
--   INTERFACE + ERROR + message (Journal Import rejection, the message
--                    is GL_INTERFACE.STATUS, plus ': ' STATUS_DESCRIPTION
--                    when Fusion wrote one) => FAILED
--   other lines of a rejected import group (GROUP_ID = prefix || work queue id, per
--                    ledger) => FAILED quoting that error (PROPAGATE_DOCUMENT_ERRORS)
--   INTERFACE with no error is corroborating only, never LOADED on its
--   own (LOADED requires a BASE row with a real FUSION_ID).
-- The FUSION_ID captured on LOADED is the per-line composite
-- JE_HEADER_ID~JE_LINE_NUM, so two lines of one journal carry DIFFERENT
-- ids (positive proof at line grain). Rows with no match and no error
-- STAY GENERATED (unaccounted) - the shared unaccounted sweep, never
-- this reconciler, settles them.
--
-- Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no private
-- UTL_HTTP copy, no raw envelope logging - the shared transport never
-- logs the request envelope, which carries credentials). Outcomes are
-- written to the TFM table only: nothing is written back to staging;
-- the TFM row is the sole record of the Fusion outcome (design
-- section 2 STG_STATUS: terminal from staging's point of view).
-- CEMLI_CODE: 'GLBalances'
-- ============================================================

    -- RECONCILE_BATCH — the reconcile entry point. Dispatched by the shared
    -- queue worker through invoke_registered's RECON style (RECON_HAS_CEMLI_ARG
    -- = 'N'): the registry row DMT_PIPELINE_DEF_TBL.RECON_PROC points at this
    -- proc and the worker binds (p_run_id, p_load_ess_id, p_import_ess_id,
    -- p_work_queue_id) by name. Delegates to the private Contract v1 apply
    -- APPLY_CONTRACT_V1_GL_BALANCES. NO COMMIT (the orchestrator owns the txn).
    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    );

    -- RESET_UNACCOUNTED -- re-run-reconcile recovery (backlog #95). Static UPDATE
    -- over this object's OWN literally-named TFM table: flip this run's
    -- UNACCOUNTED rows back to GENERATED and strip the bare [UNACCOUNTED] tag so
    -- the next reconcile pass re-examines them. Dispatched by the queue worker
    -- through the sanctioned invoke_registered site (INVOKE_RESET, RECON style,
    -- RECON_HAS_CEMLI_ARG = 'N'); the ESS-id args are ignored. NO dynamic SQL; NO
    -- COMMIT (caller owns the txn). Standard RECON reset shape (same as every
    -- other single-table object, e.g. DMT_EXPENDITURE_RESULTS_PKG).
    PROCEDURE RESET_UNACCOUNTED (p_run_id IN NUMBER, p_load_ess_id IN NUMBER DEFAULT NULL,
        p_import_ess_id IN NUMBER DEFAULT NULL, p_work_queue_id IN NUMBER DEFAULT NULL);

END DMT_GL_RESULTS_PKG;
/
