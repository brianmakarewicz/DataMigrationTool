-- Reference copy of the DMT_LOOKUP_RECON_DM dataset SQL (see DMT_LOOKUP_RECON_DM.xdm).
-- Lookups base-table reconciliation. No numeric surrogate id exists on FND lookups,
-- so the report proves existence by the STRING key only and returns RECORD_KEY +
-- SOURCE_TYPE. DISTINCT collapses the date-tracked / translation rows.
--
--   TYPE  rows  from FND_LOOKUP_TYPES     (key LOOKUP_TYPE):
--                 RECORD_KEY = LOOKUP_TYPE
--   VALUE rows  from FND_LOOKUP_VALUES_B  (key LOOKUP_TYPE + LOOKUP_CODE):
--                 RECORD_KEY = LOOKUP_TYPE || '^' || LOOKUP_CODE
--
-- Params: P_TYPE_CODES (comma-delimited LOOKUP_TYPE list),
--         P_VALUE_KEYS (comma-delimited LOOKUP_TYPE^LOOKUP_CODE composite-key list).

SELECT record_key, source_type FROM (
    SELECT DISTINCT
        t.lookup_type                        AS record_key,
        'TYPE'                               AS source_type
    FROM   fnd_lookup_types t
    WHERE  INSTR(',' || :P_TYPE_CODES || ',', ',' || t.lookup_type || ',') > 0
    UNION ALL
    SELECT DISTINCT
        v.lookup_type || '^' || v.lookup_code AS record_key,
        'VALUE'                               AS source_type
    FROM   fnd_lookup_values_b v
    WHERE  INSTR(',' || :P_VALUE_KEYS || ',', ',' || v.lookup_type || '^' || v.lookup_code || ',') > 0
);
