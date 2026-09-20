-- ============================================================
-- ValueSets BIP reconciliation query - BIP reconciliation report
-- contract v1 (nine columns, keyset pagination, the six standard
-- parameters). MIRROR of the deployed data model
-- bip/ValueSets/DMT_VS_RECON_DM.xdm (deploy target
-- /Custom/DMT2/ValueSets/). The SQL below is the byte-exact CDATA
-- body of that .xdm; regenerate this file from the .xdm whenever the
-- data model changes - the mirror must never drift.
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
-- Two tiers via OBJECT_TYPE ('ValueSet' / 'ValueSetValue'), UNION
-- ALL, ordered by RECORD_KEY.
--
-- Base tables (columns confirmed live 2026-09-20):
--   FND_VS_VALUE_SETS - VALUE_SET_ID (FUSION_ID), VALUE_SET_CODE (key).
--       Has NO ATTRIBUTE1 and NO EXTERNAL_DATA_SOURCE, so a value set
--       cannot be run-stamped and carries no SOURCE_REF / DMT_REFERENCE;
--       the set tier is scoped indirectly through its run values.
--   FND_VS_VALUES_B - VALUE_ID (FUSION_ID), keyed by VALUE within a set
--       (join to FND_VS_VALUE_SETS on VALUE_SET_ID for VALUE_SET_CODE).
--       Carries ATTRIBUTE1 (DMT run reference) and EXTERNAL_DATA_SOURCE
--       (native source reference).
--
-- Run-scoping: values are stamped ATTRIBUTE1 = 'DMT:<run>:<queue>:<tfm>',
-- so value rows are selected by ATTRIBUTE1 LIKE 'DMT:'||:P_RUN_ID||':%'
-- and each set is returned when it owns at least one such value.
-- The load/import params (P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID, P_PREFIX)
-- are declared for contract symmetry but do not select rows (FBL object).
--
-- BASE tier only: a row returned here is positive proof the object was
-- created; rows not returned were not created and are handled by the
-- reconciler (FAILED with the real FBL error, else left unaccounted).
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT
        'ValueSet'                           AS object_type,
        s.value_set_code                     AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        s.value_set_id                       AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)        AS load_request_id,
        CAST(NULL AS VARCHAR2(4000))         AS source_ref,
        CAST(NULL AS VARCHAR2(4000))         AS dmt_reference
    FROM   fnd_vs_value_sets s
    WHERE  EXISTS (
               SELECT 1
               FROM   fnd_vs_values_b v
               WHERE  v.value_set_id = s.value_set_id
               AND    v.attribute1 LIKE 'DMT:' || :P_RUN_ID || ':%'
           )

    UNION ALL

    SELECT
        'ValueSetValue'                      AS object_type,
        s.value_set_code || '^' || v.value   AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        v.value_id                           AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)        AS load_request_id,
        v.external_data_source               AS source_ref,
        v.attribute1                         AS dmt_reference
    FROM   fnd_vs_values_b   v
    JOIN   fnd_vs_value_sets s ON s.value_set_id = v.value_set_id
    WHERE  v.attribute1 LIKE 'DMT:' || :P_RUN_ID || ':%'
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start". On later pages it carries the
-- previous page's last RECORD_KEY; only greater keys are returned.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
