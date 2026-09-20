-- PACKAGE DMT_CE_BANK_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CE_BANK_RESULTS_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_CE_BANK_RESULTS_PKG
-- REST load + BIP base-table reconciliation for Cash Management
-- Banks, Bank Branches, and Bank Accounts.
--
-- New reconciliation standard (DMT_DESIGN.html, PROPOSED 2026-09):
-- reconciliation is a BIP report over the Fusion BASE tables, not the REST
-- response. LOAD_AND_RECONCILE, per tier in hierarchy order (banks -> branches
-- -> accounts): POST the GENERATED rows via the cashBanks / cashBankBranches /
-- cashBankAccounts REST resources (LOAD only; a non-2xx is stashed, the row stays
-- GENERATED), then runs DMT_CEBANK_RECON_RPT over that tier's natural keys and
-- marks a row LOADED with its FUSION_*_ID set to the real base-table surrogate id
-- (BANK_PARTY_ID / BRANCH_PARTY_ID / BANK_ACCOUNT_ID) only when the base view/
-- table confirms it. Children are POSTed only under a base-table-confirmed parent.
-- Unconfirmed rows go FAILED on their stashed real error, else stay UNACCOUNTED
-- -- never fabricated. Body helpers: LOAD_BANKS/LOAD_BRANCHES/LOAD_ACCOUNTS,
-- FETCH_BIP_RESULTS, PARSE_BANKS/PARSE_BRANCHES/PARSE_ACCOUNTS.
--
-- Base tables / surrogate ids:
--   banks    -> CE_BANKS_V          (BANK_PARTY_ID,    key BANK_NAME)
--   branches -> CE_BANK_BRANCHES_V  (BRANCH_PARTY_ID,  key BANK_BRANCH_NAME + parent BANK_NAME)
--   accounts -> CE_BANK_ACCOUNTS    (BANK_ACCOUNT_ID,  key BANK_ACCOUNT_NAME)
-- ============================================================

    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    );

END DMT_CE_BANK_RESULTS_PKG;
/
