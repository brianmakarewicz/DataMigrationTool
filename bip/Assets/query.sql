-- ============================================================
-- Assets BIP reconciliation query -- BIP reconciliation report
-- contract v1 (nine columns, keyset pagination).
-- Data source: ApplicationDB_FSCM. This mirrors the SQL embedded
-- in DMT_FA_ASSET_RECON_DM.xdm for review; the .xdm is authoritative.
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
-- Assets recon key = ASSET_NUMBER (prefixed; honoured by Fusion so
-- it survives to FA_ADDITIONS_B). RECORD_KEY = SOURCE_REF =
-- ASSET_NUMBER on both tiers.
--
-- Row selection: BASE rows are FA_ADDITIONS_B assets whose
--   ASSET_NUMBER carries the run prefix (PostMassAdditions purges the
--   interface after posting, so the base tier matches by prefix, not
--   by joining the interface). INTERFACE rows are FA_MASS_ADDITIONS
--   rows the load ESS left carrying :P_LOAD_REQUEST_ID that did not
--   post (rejections), carrying Fusion's ERROR_MSG.
--
-- FUSION_STATUS normalized SUCCESS/ERROR in the DM:
--   BASE (in FA_ADDITIONS_B) => SUCCESS; INTERFACE (not posted) => ERROR.
-- FUSION_ID non-null on every BASE row (ASSET_ID); ERROR_MESSAGE
-- non-null on every ERROR row (real ERROR_MSG or an honest fallback).
--
-- Assets special case: the LOAD stage partitions by BOOK_TYPE_CODE and
-- has the sanctioned all-or-nothing load-stage behaviour, but that logic
-- lives in the reconciler, NOT here. This DM reports per-row BASE/
-- INTERFACE like every object; the book is folded into OBJECT_TYPE only
-- for readability.
--
-- Read-back (honest): Assets stamps no DMT DFF on the base row, so
--   DMT_REFERENCE = native SERIAL_NUMBER on BASE rows (where present,
--   else NULL) and FEEDER_SYSTEM_NAME on INTERFACE rows.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- BASE -- posted assets in FA_ADDITIONS_B, matched by prefix.
    SELECT
        'Assets' || NVL2(bk.book_type_code,
                         ' [' || bk.book_type_code || ']', '')  AS object_type,
        a.asset_number                       AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        a.asset_id                           AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)        AS load_request_id,
        a.asset_number                       AS source_ref,
        a.serial_number                      AS dmt_reference
    FROM   fa_additions_b a
    LEFT   JOIN fa_books bk
           ON  bk.asset_id = a.asset_id
           AND bk.transaction_header_id_out IS NULL
    WHERE  a.asset_number LIKE :P_PREFIX || '%'
    AND    :P_PREFIX IS NOT NULL

    UNION ALL

    -- INTERFACE -- rejections left in FA_MASS_ADDITIONS after Post.
    SELECT
        'Assets' || NVL2(fma.book_type_code,
                         ' [' || fma.book_type_code || ']', '')  AS object_type,
        fma.asset_number                     AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '[ASSET] ' || NVL(fma.error_msg,
             'Not posted to FA_ADDITIONS_B (posting_status='
             || NVL(fma.posting_status, 'NULL')
             || '); rejected by Mass Additions import.')
                                             AS error_message,
        fma.load_request_id                  AS load_request_id,
        fma.asset_number                     AS source_ref,
        fma.feeder_system_name               AS dmt_reference
    FROM   fa_mass_additions fma
    WHERE  fma.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
    AND    NVL(fma.posting_status, 'X')
           NOT IN ('POSTED', 'POST', 'Y', 'PROCESSED', 'SUCCESS', 'COMPLETED')
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start". On later pages it carries the
-- previous page's last RECORD_KEY; only greater keys are returned.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
