-- Repo mirror of the SQL embedded in DMT_INV_TRX_RECON_V2_DM.xdm (the .xdm is authoritative;
-- scripts/check_bip_recon_reports.py rule BIP-MIRROR keeps the two equal).
-- ============================================================
-- MiscReceipts (inventory transactions) BIP reconciliation query
-- -- BIP reconciliation report contract v1 (nine columns, keyset
-- pagination), V2. Data source: ApplicationDB_FSCM. The repo
-- mirror of this SQL is bip/MiscReceipts/query.sql.
-- V2 (2026-10-07) is deployed ALONGSIDE DMT_INV_TRX_RECON_DM (V1);
-- BIP objects are never overwritten.
--
-- NINE columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE
--
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID,
--   P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY. No P_OFFSET / P_LIMIT.
--
-- Tiers: the posted or rejected transaction ('MiscReceipts', one
-- row per transaction keyed by SOURCE_LINE_ID = the TFM
-- STG_SEQUENCE_ID) and the posted serial ('MiscReceipts Serial',
-- keyed by the prefixed SERIAL_NUMBER). A lot or serial rejection
-- surfaces as its parent transaction's error.
--
-- Row selection (owner decision 2026-10-07, backlog #262): rows
-- are FOUND only by the Fusion load job id of ONE work item.
--   BASE transactions: INV_MATERIAL_TXNS.LOAD_REQUEST_ID =
--     :P_LOAD_REQUEST_ID. Fusion keeps the load request id on every
--     posted transaction. Its REQUEST_ID is the SingleTMEssJob that
--     the inventory transaction manager (PollTMEssJob, the work
--     item's recorded import id) spawns, not the recorded id itself,
--     and PollTMEssJob processes every pending interface row on the
--     pod, so the load request id is the exact per-work-item key.
--   INTERFACE rejections: INV_TRANSACTIONS_INTERFACE.LOAD_REQUEST_ID
--     = :P_LOAD_REQUEST_ID AND PROCESS_FLAG = 3.
--   BASE serials: INV_SERIAL_NUMBERS whose LAST_TRANSACTION_ID is a
--     transaction selected as above.
-- The run prefix and run id are never used to select rows (no LIKE
-- anywhere; the 'DMT-' || run id TRANSACTION_REFERENCE is no longer
-- a search value). P_RUN_ID, P_IMPORT_ESS_ID and P_PREFIX are
-- declared for contract symmetry only. SOURCE_LINE_ID and the
-- serial number are used only as RECORD_KEY, to match a row Fusion
-- returned back to its TFM row.
--
-- Keyset: ORDER BY RECORD_KEY (pinned to BINARY so the ordering
-- and the > comparison agree), only rows whose RECORD_KEY sorts
-- after :P_AFTER_KEY, at most :P_CHUNK_SIZE per page.
--
-- FUSION_STATUS normalized: BASE => SUCCESS, INTERFACE => ERROR.
-- FUSION_ID non-null on every BASE row (TRANSACTION_ID /
-- GEN_OBJECT_ID). ERROR_MESSAGE is the real Fusion rejection
-- carried inline on the interface row (ERROR_CODE +
-- ERROR_EXPLANATION), or NULL (the reconciler leaves such a row for
-- the UNACCOUNTED sweep).
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- BASE / posted transactions -- found by the load job id.
    SELECT
        'MiscReceipts'                       AS object_type,
        TO_CHAR(t.source_line_id)            AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        t.transaction_id                     AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        t.load_request_id                    AS load_request_id,
        t.transaction_reference              AS source_ref,
        TO_CHAR(t.source_line_id)            AS dmt_reference
    FROM   inv_material_txns t
    WHERE  t.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)

    UNION ALL

    -- INTERFACE / rejections (PROCESS_FLAG = 3) -- found by the load
    -- job id. ERROR_MESSAGE = the real Fusion rejection carried inline
    -- on the interface row.
    SELECT
        'MiscReceipts'                       AS object_type,
        TO_CHAR(t.source_line_id)            AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        CASE WHEN (NVL2(t.error_code, t.error_code || ': ', NULL) || t.error_explanation) IS NOT NULL
             THEN '[TXN] ' || NVL2(t.error_code, t.error_code || ': ', NULL) || t.error_explanation END
                                             AS error_message,
        t.load_request_id                    AS load_request_id,
        t.transaction_reference              AS source_ref,
        TO_CHAR(t.source_line_id)            AS dmt_reference
    FROM   inv_transactions_interface t
    WHERE  t.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
    AND    t.process_flag    = 3

    UNION ALL

    -- BASE / serials (backlog #11) -- a serial posted with its parent
    -- receipt carries its own base id INV_SERIAL_NUMBERS.GEN_OBJECT_ID,
    -- linked by LAST_TRANSACTION_ID to a transaction of this load (the
    -- receipt is the last transaction on a freshly migrated serial).
    -- RECORD_KEY = the prefixed SERIAL_NUMBER (globally unique, never
    -- collides with a numeric SOURCE_LINE_ID).
    SELECT
        'MiscReceipts Serial'                AS object_type,
        s.serial_number                      AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        s.gen_object_id                      AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        t.load_request_id                    AS load_request_id,
        s.serial_number                      AS source_ref,
        s.serial_number                      AS dmt_reference
    FROM   inv_serial_numbers s
    JOIN   inv_material_txns  t ON t.transaction_id = s.last_transaction_id
    WHERE  t.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL
-- in BIP, so NULL means "from the start". The ordering and the
-- comparison are both pinned to BINARY so they agree.
WHERE  (:P_AFTER_KEY IS NULL
        OR NLSSORT(record_key, 'NLS_SORT=BINARY') > NLSSORT(:P_AFTER_KEY, 'NLS_SORT=BINARY'))
ORDER BY NLSSORT(record_key, 'NLS_SORT=BINARY')
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
