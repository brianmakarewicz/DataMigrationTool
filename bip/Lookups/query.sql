-- ============================================================
-- Lookups BIP reconciliation query -- MIRROR of the deployed data
-- model bip/Lookups/DMT_LOOKUP_RECON_DM.xdm (deploy target
-- /Custom/DMT2/Lookups/). The SELECT below mirrors the CDATA body of
-- that .xdm for review; the .xdm is authoritative. Regenerate this
-- file whenever the data model changes.
--
-- NINE columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE
--
-- SPECIAL CASE -- Lookups has NO numeric surrogate id. Base tables:
--   FND_LOOKUP_TYPES     (key LOOKUP_TYPE)
--   FND_LOOKUP_VALUES_B  (key LOOKUP_TYPE + LOOKUP_CODE)
-- Existence-by-key IS the proof, so every returned row carries
-- FUSION_STATUS = 'SUCCESS', FUSION_ID = NULL, ERROR_MESSAGE = NULL.
-- SOURCE_TYPE carries the tier ('TYPE' / 'VALUE') so the reconciler
-- DMT_FND_LOOKUP_RESULTS_PKG.PARSE_AND_UPDATE can route each row.
--
-- Keys:
--   RECORD_KEY : TYPE  = LOOKUP_TYPE
--                VALUE = LOOKUP_TYPE || '^' || LOOKUP_CODE
--   DMT_REFERENCE : TYPE = NULL ; VALUE = ATTRIBUTE1 (context only)
--
-- ROW SELECTION (natural key -- backlog #135):
--   TYPE  : INSTR(',' || :P_TYPE_CODES || ',',
--                 ',' || t.lookup_type || ',') > 0
--   VALUE : INSTR(',' || :P_VALUE_KEYS || ',',
--                 ',' || v.lookup_type || '^' || v.lookup_code || ',') > 0
-- The reconciler sends P_TYPE_CODES and P_VALUE_KEYS = the
-- comma-delimited lists of this run's lookup-type codes and
-- type^code value keys. This REPLACES the former
-- ATTRIBUTE1 LIKE 'DMT:'||:P_RUN_ID||':%' DFF filter, which returned
-- zero rows because the REST create never persists that flexfield
-- marker (proven zero in runs 143/146). Matching the base tables on
-- the exact keys this run sent is the honest base-table proof -- the
-- same pattern CashBanks' recon uses for its natural keys.
-- DISTINCT collapses date-tracked / translation rows.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT DISTINCT
        'LookupType'                          AS object_type,
        t.lookup_type                         AS record_key,
        'TYPE'                                AS source_type,
        'SUCCESS'                             AS fusion_status,
        CAST(NULL AS NUMBER)                  AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))          AS error_message,
        CAST(NULL AS NUMBER)                  AS load_request_id,
        t.lookup_type                         AS source_ref,
        CAST(NULL AS VARCHAR2(4000))          AS dmt_reference
    FROM   fnd_lookup_types t
    WHERE  INSTR(',' || :P_TYPE_CODES || ',',
                 ',' || t.lookup_type || ',') > 0

    UNION ALL

    SELECT DISTINCT
        'LookupValue'                         AS object_type,
        v.lookup_type || '^' || v.lookup_code AS record_key,
        'VALUE'                               AS source_type,
        'SUCCESS'                             AS fusion_status,
        CAST(NULL AS NUMBER)                  AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))          AS error_message,
        CAST(NULL AS NUMBER)                  AS load_request_id,
        v.lookup_type || '^' || v.lookup_code AS source_ref,
        v.attribute1                          AS dmt_reference
    FROM   fnd_lookup_values_b v
    WHERE  INSTR(',' || :P_VALUE_KEYS || ',',
                 ',' || v.lookup_type || '^' || v.lookup_code || ',') > 0
)
ORDER BY record_key
;
