-- PACKAGE DMT_AP_PAY_TERM_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AP_PAY_TERM_RESULTS_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AP_PAY_TERM_RESULTS_PKG
-- REST-based load + reconciliation for AP Payment Terms.
--
-- Loads terms to Fusion via REST POST (standardTerms endpoint),
-- then creates installment lines as children of each term.
-- Updates TFM/STG status to LOADED/FAILED.
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
