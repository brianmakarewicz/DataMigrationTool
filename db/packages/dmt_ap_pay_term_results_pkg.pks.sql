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

    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    );

END DMT_AP_PAY_TERM_RESULTS_PKG;
/
