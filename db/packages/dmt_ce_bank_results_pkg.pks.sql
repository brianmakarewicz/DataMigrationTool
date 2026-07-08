-- PACKAGE DMT_CE_BANK_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CE_BANK_RESULTS_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_CE_BANK_RESULTS_PKG
-- REST-based load + reconciliation for Cash Management
-- Banks, Branches, and Accounts.
--
-- Three-phase load:
--   Phase 1: POST banks via /cashBanks, extract BankPartyId
--   Phase 2: POST branches via /cashBanks/{id}/child/bankBranches,
--            extract BranchPartyId
--   Phase 3: POST accounts via /cashBankAccounts
--
-- Updates TFM/STG status to LOADED/FAILED with [FUSION_ERROR].
-- ============================================================

    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    );

END DMT_CE_BANK_RESULTS_PKG;
/
