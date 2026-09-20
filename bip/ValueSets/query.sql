-- ============================================================
-- ValueSets BIP reconciliation query -- MIRROR of the deployed
-- data model bip/ValueSets/DMT_VS_RECON_DM.xdm (deploy target
-- /Custom/DMT2/ValueSets/). The SQL below is the byte-exact CDATA
-- body of that .xdm; regenerate this file from the .xdm whenever the
-- data model changes -- the mirror must never drift.
--
-- New reconciliation standard (DMT_DESIGN.html, PROPOSED 2026-09):
-- reconciliation is a BIP report over the Fusion BASE table, returning
-- the base-table surrogate id. A REST load-call HTTP 200 is NOT
-- reconciliation. ValueSets is a two-object load (a value set, then its
-- child values), so this report reads BOTH base tables in one call:
--   * FND_VS_VALUE_SETS  -- surrogate VALUE_SET_ID, natural key VALUE_SET_CODE
--   * FND_VS_VALUES_B    -- surrogate VALUE_ID, keyed by VALUE within a set;
--                           joined to FND_VS_VALUE_SETS on VALUE_SET_ID so the
--                           report can expose VALUE_SET_CODE for matching.
--
-- Data source: ApplicationDB_FSCM
-- Parameters (config codes are NOT run-prefixed, so match on exact codes):
--   :P_SET_CODES  = comma-delimited list of the VALUE_SET_CODE values this run
--                   sent (e.g. 'DMT2_VS_G1,DMT2_VS_B1'). SOURCE_TYPE='SET';
--                   RECORD_KEY = VALUE_SET_CODE; FUSION_ID = VALUE_SET_ID.
--   :P_VALUE_KEYS = comma-delimited list of composite value keys, each
--                   VALUE_SET_CODE || '^' || VALUE (e.g. 'DMT2_VS_G1^A,DMT2_VS_G1^B').
--                   SOURCE_TYPE='VALUE'; RECORD_KEY = the same composite key;
--                   FUSION_ID = VALUE_ID. The '^' separator cannot appear in a
--                   value-set code or a value, so the composite key is unambiguous.
-- The comma-boundary INSTR match avoids substring false positives.
--
-- BASE tier only: a row returned here is positive proof the object was created;
-- rows not returned were not created and are handled by the reconciler (FAILED
-- with the real REST error, else left unaccounted).
-- ============================================================
SELECT
    s.value_set_code                     AS record_key,
    'SUCCESS'                            AS import_status,
    'SET'                                AS source_type,
    s.value_set_id                       AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))         AS error_message
FROM   fnd_vs_value_sets s
WHERE  INSTR(',' || :P_SET_CODES || ',', ',' || s.value_set_code || ',') > 0
UNION ALL
SELECT
    s.value_set_code || '^' || v.value   AS record_key,
    'SUCCESS'                            AS import_status,
    'VALUE'                              AS source_type,
    v.value_id                           AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))         AS error_message
FROM   fnd_vs_values_b v
       JOIN fnd_vs_value_sets s ON s.value_set_id = v.value_set_id
WHERE  INSTR(',' || :P_VALUE_KEYS || ',', ',' || s.value_set_code || '^' || v.value || ',') > 0
