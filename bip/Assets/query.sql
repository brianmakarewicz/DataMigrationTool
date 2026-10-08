-- ============================================================
-- Assets reconciliation data model V2 -- BIP reconciliation report
-- contract v1 (nine columns, keyset pagination, the six standard
-- parameters). V2 (2026-10-07) is deployed ALONGSIDE
-- DMT_FA_ASSET_RECON_DM (V1); BIP objects are never overwritten.
--
-- NINE response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE.
--
-- SIX parameters (Contract v1): P_RUN_ID, P_LOAD_REQUEST_ID,
--   P_IMPORT_ESS_ID, P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY.
--   No P_OFFSET / P_LIMIT.
--
-- Row selection (owner decision 2026-10-07): rows are FOUND only by
-- the Fusion job id of ONE work item (one book = one load). The
-- reconciler calls this report once per work item with that item's
-- own load request id.
--   FA_ADDITIONS_B, FA_BOOKS and FA_DISTRIBUTION_HISTORY carry no
--   request id. FA_MASS_ADDITIONS keeps the row after Post Mass
--   Additions, stamped with the load job's LOAD_REQUEST_ID and, once
--   posted, POSTING_STATUS = 'POSTED' and the created ASSET_ID
--   (verified live: load 10070606 -> ASSET_ID 581149 / 581150).
--   BASE assets: FA_ADDITIONS_B rows whose ASSET_ID is on a POSTED
--     mass addition of :P_LOAD_REQUEST_ID.
--   BASE distributions: the active FA_DISTRIBUTION_HISTORY row of
--     those same assets.
--   INTERFACE rows: FA_MASS_ADDITIONS rows of :P_LOAD_REQUEST_ID that
--     did not post, carrying Fusion's ERROR_MSG.
-- The run prefix and run id are never used to select rows (no LIKE
-- anywhere). P_RUN_ID, P_IMPORT_ESS_ID and P_PREFIX are declared for
-- contract symmetry only. The asset number is used only as
-- RECORD_KEY, to match a row Fusion returned back to its TFM row.
--
-- Assets special case (NOT reflected in this DM): the load stage
-- partitions by BOOK_TYPE_CODE, one FBDI per book, and the sanctioned
-- all-or-nothing SQL*Loader behaviour lives in the reconciler. This DM
-- reports per-row BASE/INTERFACE like every other object; the book is
-- folded into OBJECT_TYPE for readability only.
--
-- FUSION_STATUS is normalized in this DM to exactly SUCCESS/ERROR:
--   BASE (present in FA_ADDITIONS_B)              => SUCCESS
--   INTERFACE (left in FA_MASS_ADDITIONS, posting_status not posted)
--                                                 => ERROR
-- FUSION_ID is non-null on every BASE row (ASSET_ID, or the
-- DISTRIBUTION_ID on the distribution tier). ERROR_MESSAGE is the real
-- ERROR_MSG text, or NULL when Fusion wrote none (the reconciler then
-- leaves the row for the all-or-nothing path or the unaccounted sweep).
--
-- Keys / read-back (Assets stamps no DMT DFF on the base row):
--   RECORD_KEY / SOURCE_REF = ASSET_NUMBER (distribution tier:
--                             ASSET_NUMBER || '#DIST', unique)
--   DMT_REFERENCE (BASE)      = FA_ADDITIONS_B.SERIAL_NUMBER
--   DMT_REFERENCE (INTERFACE) = FA_MASS_ADDITIONS.FEEDER_SYSTEM_NAME
-- Keyset: ORDER BY RECORD_KEY (pinned to BINARY so the ordering and
-- the > comparison agree), only rows whose RECORD_KEY sorts after
-- :P_AFTER_KEY, at most :P_CHUNK_SIZE per page.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- Tier: BASE -- assets this load posted to FA_ADDITIONS_B, found
    -- through their POSTED mass addition (LOAD_REQUEST_ID). The book is
    -- folded into OBJECT_TYPE through a scalar subquery (ROWNUM = 1), not
    -- a join, so the one-row-per-asset grain and the unique RECORD_KEY
    -- are kept when an asset also carries tax-book rows in FA_BOOKS.
    SELECT
        'Assets' || NVL2(
            (SELECT bk.book_type_code
               FROM fa_books bk
              WHERE bk.asset_id = a.asset_id
                AND bk.transaction_header_id_out IS NULL
                AND ROWNUM = 1),
            ' [' || (SELECT bk.book_type_code
                       FROM fa_books bk
                      WHERE bk.asset_id = a.asset_id
                        AND bk.transaction_header_id_out IS NULL
                        AND ROWNUM = 1) || ']', '')          AS object_type,
        a.asset_number                       AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        a.asset_id                           AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)        AS load_request_id,
        a.asset_number                       AS source_ref,
        a.serial_number                      AS dmt_reference
    FROM   fa_additions_b a
    WHERE  a.asset_id IN (
               SELECT pma.asset_id
               FROM   fa_mass_additions pma
               WHERE  pma.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
               AND    pma.posting_status  = 'POSTED'
               AND    pma.asset_id IS NOT NULL)

    UNION ALL

    -- Tier: INTERFACE -- rows of this load still unposted in
    -- FA_MASS_ADDITIONS after Post Mass Additions are rejections.
    -- ERROR_MSG carries the Fusion rejection text.
    SELECT
        'Assets' || NVL2(fma.book_type_code,
                         ' [' || fma.book_type_code || ']', '')  AS object_type,
        fma.asset_number                     AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        CASE WHEN fma.error_msg IS NOT NULL
             THEN '[ASSET] ' || fma.error_msg END
                                             AS error_message,
        fma.load_request_id                  AS load_request_id,
        fma.asset_number                     AS source_ref,
        fma.feeder_system_name               AS dmt_reference
    FROM   fa_mass_additions fma
    WHERE  fma.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
    AND    NVL(fma.posting_status, 'X')
           NOT IN ('POSTED', 'POST', 'Y', 'PROCESSED', 'SUCCESS', 'COMPLETED')

    UNION ALL

    -- Tier: BASE (Assets Distribution) -- backlog #11. The assignment
    -- child's own Fusion id is the active FA_DISTRIBUTION_HISTORY row of
    -- an asset this load posted (same POSTED mass-addition route as the
    -- asset tier). RECORD_KEY is the asset number plus '#DIST' so it stays
    -- unique across the report. The assign child is one row per asset, so
    -- the lowest active distribution id is returned (MIN), a real id that
    -- belongs to this asset.
    SELECT
        'Assets Distribution'                AS object_type,
        a.asset_number || '#DIST'            AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        (SELECT MIN(d.distribution_id)
           FROM fa_distribution_history d
          WHERE d.asset_id = a.asset_id
            AND d.date_ineffective IS NULL)  AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)        AS load_request_id,
        a.asset_number                       AS source_ref,
        CAST(NULL AS VARCHAR2(240))          AS dmt_reference
    FROM   fa_additions_b a
    WHERE  a.asset_id IN (
               SELECT pma.asset_id
               FROM   fa_mass_additions pma
               WHERE  pma.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
               AND    pma.posting_status  = 'POSTED'
               AND    pma.asset_id IS NOT NULL)
    AND    EXISTS (SELECT 1 FROM fa_distribution_history d
                   WHERE d.asset_id = a.asset_id
                   AND   d.date_ineffective IS NULL)
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start". On later pages it carries the
-- previous page's last RECORD_KEY; only greater keys are returned. The
-- ordering and the comparison are both pinned to BINARY so they agree.
WHERE  (:P_AFTER_KEY IS NULL
        OR NLSSORT(record_key, 'NLS_SORT=BINARY') > NLSSORT(:P_AFTER_KEY, 'NLS_SORT=BINARY'))
ORDER BY NLSSORT(record_key, 'NLS_SORT=BINARY')
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
