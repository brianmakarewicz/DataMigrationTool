-- ============================================================
-- CashBanks BIP reconciliation query -- MIRROR of the deployed data model
-- bip/CashBanks/DMT_CEBANK_RECON_DM.xdm (deploy target /Custom/DMT2/CashBanks/).
-- The three SELECTs below are the byte-exact CDATA bodies of that .xdm's three
-- datasets; regenerate this file from the .xdm whenever the data model changes --
-- the mirror must never drift.
--
-- New reconciliation standard (DMT_DESIGN.html, PROPOSED 2026-09):
-- reconciliation is a BIP report over the Fusion BASE tables, returning the
-- base-table surrogate id. A REST load-call HTTP 200 is NOT reconciliation.
-- For Cash Management the three tiers are:
--   banks    -> CE_BANKS_V          (surrogate BANK_PARTY_ID,   key BANK_NAME)
--   branches -> CE_BANK_BRANCHES_V  (surrogate BRANCH_PARTY_ID, key BANK_BRANCH_NAME
--                                    + parent BANK_NAME to disambiguate a reused name)
--   accounts -> CE_BANK_ACCOUNTS    (surrogate BANK_ACCOUNT_ID, key BANK_ACCOUNT_NAME)
--
-- Data source: ApplicationDB_FSCM
-- Parameters:
--   :P_BANK_NAMES   = comma-delimited list of the bank names this run sent.
--   :P_BRANCH_NAMES = comma-delimited list of the branch names this run sent.
--   :P_ACCT_NAMES   = comma-delimited list of the account names this run sent.
-- Names are NOT run-prefixed. The comma-boundary INSTR match avoids substring
-- false positives.
--
-- G_1 (BASE_BANK):    a row in CE_BANKS_V is positive proof; FUSION_ID = BANK_PARTY_ID.
-- G_2 (BASE_BRANCH):  a row in CE_BANK_BRANCHES_V is positive proof; FUSION_ID =
--                     BRANCH_PARTY_ID; PARENT_BANK_NAME lets the reconciler match
--                     the branch to its TFM row by (branch name, parent bank name).
-- G_3 (BASE_ACCOUNT): a row in CE_BANK_ACCOUNTS is positive proof; FUSION_ID =
--                     BANK_ACCOUNT_ID.
-- Rows not returned were not created and are handled by the reconciler (FAILED
-- with the real REST error, else left unaccounted).
-- ============================================================

-- G_1: bank confirmation over CE_BANKS_V by BANK_NAME
SELECT
    b.bank_name                          AS record_key,
    'SUCCESS'                            AS import_status,
    'BASE_BANK'                          AS source_type,
    b.bank_party_id                      AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))         AS error_message
FROM   ce_banks_v b
WHERE  INSTR(',' || :P_BANK_NAMES || ',', ',' || b.bank_name || ',') > 0
;

-- G_2: branch confirmation over CE_BANK_BRANCHES_V by BANK_BRANCH_NAME
SELECT
    br.bank_branch_name                  AS record_key,
    'SUCCESS'                            AS import_status,
    'BASE_BRANCH'                        AS source_type,
    br.branch_party_id                   AS fusion_id,
    br.bank_name                         AS parent_bank_name,
    CAST(NULL AS VARCHAR2(4000))         AS error_message
FROM   ce_bank_branches_v br
WHERE  INSTR(',' || :P_BRANCH_NAMES || ',', ',' || br.bank_branch_name || ',') > 0
;

-- G_3: account confirmation over CE_BANK_ACCOUNTS by BANK_ACCOUNT_NAME
SELECT
    a.bank_account_name                  AS record_key,
    'SUCCESS'                            AS import_status,
    'BASE_ACCOUNT'                       AS source_type,
    a.bank_account_id                    AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))         AS error_message
FROM   ce_bank_accounts a
WHERE  INSTR(',' || :P_ACCT_NAMES || ',', ',' || a.bank_account_name || ',') > 0
;
