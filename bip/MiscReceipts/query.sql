-- ============================================================
-- MiscReceipts BIP reconciliation query -- BIP reconciliation
-- report contract v1 (nine columns, keyset pagination).
-- Data source: ApplicationDB_FSCM. This mirrors the SQL embedded
-- in DMT_INV_TRX_RECON_DM.xdm for review; the .xdm is authoritative.
--
-- NINE columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE
--
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID,
--   P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY. No P_OFFSET / P_LIMIT.
--
-- Keyset: ORDER BY RECORD_KEY, only rows whose RECORD_KEY sorts
-- after :P_AFTER_KEY, at most :P_CHUNK_SIZE per page.
--
-- SINGLE-TIER (MiscReceipts inventory transactions). One recon key
-- per record: SOURCE_LINE_ID (= TFM STG_SEQUENCE_ID). Two source
-- tiers only -- BASE (posted) and INTERFACE (rejected) -- UNION
-- ALL-ed then ordered by RECORD_KEY. Lot/serial rejections surface
-- on the parent transaction's interface row, so there is no
-- separate lot/serial recon tier.
--
-- Row selection: run-scoped by the batch key
--   TRANSACTION_REFERENCE = 'DMT-' || :P_RUN_ID and SOURCE_CODE='DMT'.
--   BASE tier    => INV_MATERIAL_TXNS (posted; FUSION_ID=TRANSACTION_ID).
--   INTERFACE tier => INV_TRANSACTIONS_INTERFACE where PROCESS_FLAG=3
--   (rejections). ERROR_CODE + ERROR_EXPLANATION are carried inline
--   on the interface row (no separate interface-errors table on this
--   release), so they are the real Fusion rejection text.
--
-- FUSION_STATUS normalized SUCCESS/ERROR in the DM:
--   BASE (present in base table) => SUCCESS; INTERFACE => ERROR.
-- FUSION_ID non-null on every BASE row; ERROR_MESSAGE non-null on
-- every ERROR row.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- BASE / posted transactions -- RECORD_KEY = SOURCE_LINE_ID
    SELECT
        'MiscReceipts'                       AS object_type,
        TO_CHAR(t.source_line_id)            AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        t.transaction_id                     AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        t.transaction_reference              AS source_ref,
        TO_CHAR(t.source_line_id)            AS dmt_reference
    FROM   inv_material_txns t
    WHERE  t.source_code           = 'DMT'
    AND    t.transaction_reference = 'DMT-' || :P_RUN_ID

    UNION ALL

    -- INTERFACE / rejections only (PROCESS_FLAG=3) -- RECORD_KEY = SOURCE_LINE_ID
    SELECT
        'MiscReceipts'                       AS object_type,
        TO_CHAR(t.source_line_id)            AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '[TXN] ' || NVL(
            NVL2(t.error_code, t.error_code || ': ', NULL) || t.error_explanation,
            'Rejected by Inventory Transaction import (process_flag=3; '
            || 'transaction not created in base table; no error text written).')
                                             AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        t.transaction_reference              AS source_ref,
        TO_CHAR(t.source_line_id)            AS dmt_reference
    FROM   inv_transactions_interface t
    WHERE  t.source_code           = 'DMT'
    AND    t.transaction_reference = 'DMT-' || :P_RUN_ID
    AND    t.process_flag          = 3
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start". On later pages it carries the
-- previous page's last RECORD_KEY; only greater keys are returned.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
