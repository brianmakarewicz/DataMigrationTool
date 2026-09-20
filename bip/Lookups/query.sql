-- ============================================================
-- Lookups BIP reconciliation query — BIP reconciliation report
-- contract v1 (nine columns, keyset pagination). Data source:
-- ApplicationDB_FSCM. This mirrors the SQL embedded in
-- DMT_LOOKUP_RECON_DM.xdm for review; the .xdm is authoritative.
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
-- SPECIAL CASE — Lookups has NO numeric surrogate id. Base tables:
--   FND_LOOKUP_TYPES     (key LOOKUP_TYPE)
--   FND_LOOKUP_VALUES_B  (key LOOKUP_TYPE + LOOKUP_CODE)
-- Existence-by-key IS the proof, so every returned row carries
-- SOURCE_TYPE = 'BASE', FUSION_STATUS = 'SUCCESS', FUSION_ID = NULL,
-- ERROR_MESSAGE = NULL.
--
-- Run-scoping: FND_LOOKUP_VALUES_B has ATTRIBUTE1..15, so the VALUE
-- tier is scoped by v.attribute1 LIKE 'DMT:'||:P_RUN_ID||':%'.
-- FND_LOOKUP_TYPES has NO ATTRIBUTE columns (verified live), so the
-- TYPE tier is scoped by EXISTS against the run's own values.
-- Therefore DMT_REFERENCE is NULL for TYPE rows and = ATTRIBUTE1 for
-- VALUE rows. DISTINCT collapses date-tracked / translation rows.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT DISTINCT
        'LookupType'                          AS object_type,
        t.lookup_type                         AS record_key,
        'BASE'                                AS source_type,
        'SUCCESS'                             AS fusion_status,
        CAST(NULL AS NUMBER)                  AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))          AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)         AS load_request_id,
        t.lookup_type                         AS source_ref,
        CAST(NULL AS VARCHAR2(4000))          AS dmt_reference
    FROM   fnd_lookup_types t
    WHERE  EXISTS (
               SELECT 1
               FROM   fnd_lookup_values_b cv
               WHERE  cv.lookup_type = t.lookup_type
               AND    cv.attribute1 LIKE 'DMT:' || :P_RUN_ID || ':%'
           )

    UNION ALL

    SELECT DISTINCT
        'LookupValue'                         AS object_type,
        v.lookup_type || '^' || v.lookup_code AS record_key,
        'BASE'                                AS source_type,
        'SUCCESS'                             AS fusion_status,
        CAST(NULL AS NUMBER)                  AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))          AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)         AS load_request_id,
        v.lookup_type || '^' || v.lookup_code AS source_ref,
        v.attribute1                          AS dmt_reference
    FROM   fnd_lookup_values_b v
    WHERE  v.attribute1 LIKE 'DMT:' || :P_RUN_ID || ':%'
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start". On later pages it carries the
-- previous page's last RECORD_KEY; only greater keys are returned.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
;
