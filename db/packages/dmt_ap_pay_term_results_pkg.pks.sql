-- PACKAGE DMT_AP_PAY_TERM_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AP_PAY_TERM_RESULTS_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AP_PAY_TERM_RESULTS_PKG
-- REST load + BIP base-table reconciliation for AP Payment Terms.
--
-- New reconciliation standard (DMT_DESIGN.html, PROPOSED 2026-09):
-- reconciliation is a BIP report over the Fusion BASE table AP_TERMS, not the
-- REST response. LOAD_AND_RECONCILE POSTs each header to standardTerms (LOAD
-- only; a non-2xx is stashed, header stays GENERATED), runs DMT_APTERMS_RECON_RPT
-- over the run's term names, and marks a header LOADED with FUSION_TERM_ID =
-- AP_TERMS.TERM_ID only when the base table confirms it. Installment lines are
-- POSTed as children under a base-table-confirmed TERM_ID. Unconfirmed headers
-- go FAILED on their stashed real error, else stay UNACCOUNTED -- never
-- fabricated. Body helpers: LOAD_TERMS, FETCH_BIP_RESULTS, PARSE_AND_UPDATE,
-- LOAD_LINES.
--
-- REST pattern:
--   POST /standardTerms                             -> create term
--   POST /standardTerms/{TermId}/child/installments -> create lines
-- ============================================================

    -- LOAD phase: POST headers, confirm them mid-load to obtain each TERM_ID
    -- (the child URL key the installment lines need), then POST the lines.
    -- Rows are left GENERATED; the generic recon engine owns the final verdict
    -- via APPLY_PAY_TERM. (Name retained for the runner's contract.)
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    );

    -- APPLY_PAY_TERM — thin STATIC apply dispatched by the generic recon engine
    -- (DMT_RECON_ENGINE_PKG) through invoke_registered (style RECON). Reads
    -- DMT_RECON_STAGE_GTT and MERGEs LOADED/FAILED into the two literally-named
    -- payment-term TFM tables with STATIC SQL, one tier per report SOURCE_TYPE
    -- ('BASE' header by NAME; 'BASE_LINE' installment by TERM_ID-SEQUENCE_NUM),
    -- capturing FUSION_TERM_ID.
    PROCEDURE APPLY_PAY_TERM (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER   DEFAULT NULL,
        p_import_ess_id IN NUMBER   DEFAULT NULL,
        p_work_queue_id IN NUMBER   DEFAULT NULL
    );

END DMT_AP_PAY_TERM_RESULTS_PKG;
/
