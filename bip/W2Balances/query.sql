-- DMT_W2BALANCES_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_W2BALANCES_RECON_DM.xdm, kept here for review and
-- for running the query standalone against live Fusion (bind the six parameters).
--
-- Returns the BASE tier for the W2Balances HDL load: one row per migrated
-- balance-initialization batch positively confirmed in the Fusion payroll balance
-- base table PAY_BAL_BATCH_HEADERS, with the real Fusion BATCH_ID as FUSION_ID. HDL
-- per-record failures are captured separately (RECONCILE_HDL tags [FUSION_ERROR]
-- before this report runs), so this report returns BASE/SUCCESS rows only; the
-- shared parser marks a BalanceInitialization row LOADED only from a BASE / SUCCESS /
-- FUSION_ID-not-null row.
--
-- W2Balances loads through the HCM Data Loader as PayrollBalanceInitialization: the
-- parent BalanceInitialization record loads as the InitializeBalanceBatchHeader HDL
-- object -> one row in PAY_BAL_BATCH_HEADERS (BATCH_ID is the base id); the child
-- BalInitializationDetails records load as InitializeBalanceBatchLine ->
-- PAY_BAL_BATCH_LINES. This report proves the parent (the batch header) only.
--
-- PAY_BAL_BATCH_HEADERS carries no business key we control, so the match is through
-- HRC_INTEGRATION_KEY_MAP: an HDL-loaded header is registered there as
-- OBJECT_NAME='InitializeBalanceBatchHeader', SOURCE_SYSTEM_OWNER='HRC_SQLLOADER'
-- (the .dat SourceSystemOwner), SOURCE_SYSTEM_ID = the .dat SourceSystemId, and
-- SURROGATE_ID = the base BATCH_ID.
--
-- RECORD_KEY = the prefixed SourceSystemId = prefixed PERSON_NUMBER || '_BAL'
--            = HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID
--            = the W2Balances TFM row's RECON_KEY (DMT_UTIL_PKG.PREFIXED(prefix,
--              PERSON_NUMBER, 30) || '_BAL' at transform, design section 5).
--
-- Verified live 2026-09-16 (--cred fin_impl):
--   -- base tables exist and correspond to the HDL objects:
--   SELECT COUNT(*) FROM pay_bal_batch_headers;  -> 648 (all balance batches)
--   -- the InitializeBalanceBatchHeader keys number 7, matching 7 rows in the
--   -- narrower PAY_BAL_BATCH_HEADERS variant PAY_BAL_BATCH_HEADERS
--   -- (InitializeBalanceBatchHeader = 7 keys; InitializeBalanceBatchLine = 13 keys).
--   -- join path proven:
--   SELECT m.source_system_id, h.batch_id, h.batch_name
--   FROM   hrc_integration_key_map m
--   JOIN   pay_bal_batch_headers h ON h.batch_id = m.surrogate_id
--   WHERE  m.object_name='InitializeBalanceBatchHeader'
--     -> 300000331552768 300000331552768 DMTW232147   (surrogate_id = batch_id)
--        300000331553085 300000331553085 DMTW210163
-- NOTE: all 7 existing keys are SOURCE_SYSTEM_OWNER='FUSION' (prior UI/test data);
--   zero are SOURCE_SYSTEM_OWNER<>'FUSION'. No record has yet been migrated through
--   the DMT HDL SourceSystemId path, so this report returns zero rows for a DMT
--   prefix today -- W2Balances is upstream-blocked. Zero rows is never LOADED.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    SELECT 'W2Balances'                    AS object_type,
           m.source_system_id              AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(h.batch_id)                 AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id
    FROM   hrc_integration_key_map m
    JOIN   pay_bal_batch_headers   h ON h.batch_id = m.surrogate_id
    WHERE  m.object_name         = 'InitializeBalanceBatchHeader'
    AND    m.source_system_owner = 'HRC_SQLLOADER'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    (:P_AFTER_KEY IS NULL OR m.source_system_id > :P_AFTER_KEY)
    GROUP BY m.source_system_id
    ORDER BY m.source_system_id
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
