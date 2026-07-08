-- ============================================================
-- Assets BIP Reconciliation Query (Two-Tier)
-- Data source: ApplicationDB_FSCM
-- Parameters: :P_BATCH_ID = Load ESS request ID (LOAD_REQUEST_ID in FA_MASS_ADDITIONS)
--             :P_PREFIX = Run prefix (e.g. '9181') for Tier 2 base table matching
--
-- Tier 1 (INTERFACE): Rows still in FA_MASS_ADDITIONS after PostMassAdditions.
--   PostMassAdditions removes successfully posted rows from FA_MASS_ADDITIONS.
--   Rows remaining here are errors/not-posted.
--   ERROR_MSG (VARCHAR2 4000) contains Fusion-populated error detail.
--
-- Tier 2 (BASE): Assets created in FA_ADDITIONS_B.
--   PostMassAdditions purges interface rows after posting, so Tier 2 uses
--   prefix-based matching on ASSET_NUMBER instead of joining through FA_MASS_ADDITIONS.
-- ============================================================
SELECT
    fma.asset_number,
    fma.posting_status                   AS import_status,
    'INTERFACE'                          AS source_type,
    CAST(NULL AS NUMBER)                 AS fusion_id,
    fma.error_msg                        AS error_message
FROM   fa_mass_additions fma
WHERE  fma.load_request_id = :P_BATCH_ID

UNION ALL

-- Tier 2 (BASE): FA_ADDITIONS_B — PostMassAdditions purges FA_MASS_ADDITIONS
-- after posting, so match on prefixed ASSET_NUMBER instead.
SELECT
    a.asset_number,
    'POSTED'                             AS import_status,
    'BASE'                               AS source_type,
    a.asset_id                           AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))         AS error_message
FROM   fa_additions_b a
WHERE  a.asset_number LIKE :P_PREFIX || '%'
AND    :P_PREFIX IS NOT NULL
