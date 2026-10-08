-- DMT_W2_BAL_RECON_V2_DM query (BIP reconciliation report contract v1).
-- Mirror of the CDATA SQL in DMT_W2_BAL_RECON_V2_DM.xdm (the data model the
-- registry row 100000035 points at; V1 DMT_W2_BAL_RECON_DM stays deployed,
-- never overwritten), kept here for review and for running the query
-- standalone against live Fusion.
--
-- W2Balances (payroll balance initialization) loads through HCM Data Loader as
-- the "Balance Initialization" business object: InitializeBalanceBatchHeader
-- (parent) and InitializeBalanceBatchLine (child, referenced by BatchName).
-- DMT_W2_BAL_HDL_GEN_PKG emits ONE batch per run. Its BatchName is the
-- W2Balances TFM RECON_KEY: the run prefix followed by the work-queue id (owner
-- decision 2026-10-07, backlog #413; the work-queue id alone with USE_PREFIX =
-- N, so it is never a constant at cutover).
--
-- ROW SELECTION (backlog #413): the batch is found ONLY by the exact BatchName,
-- bound as P_FUSION_BATCH_ID (sent by DMT_RECON_CONTRACT_PKG.FETCH_ROWS).
-- V1 used BATCH_NAME LIKE P_PREFIX followed by anything, which finds rows by
-- the prefix (forbidden) and can match a longer prefix with the same leading
-- digits. PAY_BAL_BATCH_HEADERS has no request id column, so the BatchName is
-- the only exact selector.
--
-- An HDL load has no interface table, so this report returns the BASE tier
-- only: one row per batch confirmed in PAY_BAL_BATCH_HEADERS, with the Fusion
-- BATCH_ID as FUSION_ID. Per-record HDL failures are applied from the HDL
-- response before this report runs.
--
-- NINE response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE('BASE'), FUSION_STATUS('SUCCESS'),
--   FUSION_ID (= BATCH_ID), ERROR_MESSAGE (NULL), LOAD_REQUEST_ID (NULL),
--   SOURCE_REF (= BATCH_NAME), DMT_REFERENCE (NULL).
-- PARAMETERS: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID, P_PREFIX,
--   P_CHUNK_SIZE, P_AFTER_KEY (Contract v1) plus P_FUSION_BATCH_ID; only
--   P_FUSION_BATCH_ID selects rows. Keyset pagination by RECORD_KEY.
--
-- WHY THE BASE TABLE, NOT HRC_INTEGRATION_KEY_MAP (verified live 2026-09-20):
-- on this pod the balance-init key-map rows are owned by FUSION and carry
-- Fusion's surrogate as SOURCE_SYSTEM_ID, not our BatchName; the base table
-- carries the BatchName and its BATCH_ID equals the key-map SURROGATE_ID.

SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT 'W2Balances'                   AS object_type,
           h.batch_name                   AS record_key,
           'BASE'                         AS source_type,
           'SUCCESS'                      AS fusion_status,
           MAX(h.batch_id)                AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))   AS error_message,
           CAST(NULL AS VARCHAR2(30))     AS load_request_id,
           h.batch_name                   AS source_ref,
           CAST(NULL AS VARCHAR2(4000))   AS dmt_reference
    FROM   pay_bal_batch_headers h
    WHERE  h.batch_name = :P_FUSION_BATCH_ID
    GROUP BY h.batch_name
)
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY;
