-- ============================================================
-- UnitsOfMeasure BIP reconciliation query -- MIRROR of the deployed
-- data model bip/UnitsOfMeasure/DMT_UOM_RECON_DM.xdm (deploy target
-- /Custom/DMT2/UnitsOfMeasure/). The SELECT below is the byte-exact
-- CDATA body of that .xdm; regenerate this file from the .xdm
-- whenever the data model changes -- the mirror must never drift.
--
-- NINE columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE
--
-- OBJECT MODEL: UnitsOfMeasure is REST-loaded (POST unitsOfMeasure,
-- one call per UOM). There is NO ESS import and NO Fusion interface
-- table, so this report has a BASE tier only -- a row in
-- INV_UNITS_OF_MEASURE_B is positive proof the UOM was created.
-- REST rejections are captured per-record from the POST response at
-- load time by the object's reconciler (DMT_INV_UOM_RESULTS_PKG, a
-- separate track), not by this report. LOAD_REQUEST_ID, SOURCE_REF,
-- and ERROR_MESSAGE are therefore NULL on every BASE row.
--
-- KEYS:
--   RECORD_KEY    = UOM_CODE           (= TFM RECON_KEY; not run-prefixed)
--   FUSION_ID     = UNIT_OF_MEASURE_ID (surrogate id == REST UOMId)
--   DMT_REFERENCE = ATTRIBUTE1         (context only; not a filter)
--   SOURCE_REF    = NULL               (no native source-ref column on
--                                       INV_UNITS_OF_MEASURE_B)
--
-- ROW SELECTION (natural key -- backlog #135):
--   INSTR(',' || :P_UOM_CODES || ',', ',' || b.uom_code || ',') > 0
-- The reconciler sends P_UOM_CODES = the comma-delimited list of this
-- run's GENERATED UOM codes. This REPLACES the former
-- ATTRIBUTE1 LIKE 'DMT:'||:P_RUN_ID||':%' DFF filter, which returned
-- zero rows because the REST create never persists that flexfield
-- marker (proven zero in runs 143/146). Matching the base table on the
-- exact codes this run sent is the honest base-table proof -- the same
-- pattern CashBanks' recon uses for bank/branch/account names.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT
        'UnitsOfMeasure'                     AS object_type,
        b.uom_code                           AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        b.unit_of_measure_id                 AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        CAST(NULL AS NUMBER)                 AS load_request_id,
        CAST(NULL AS VARCHAR2(4000))         AS source_ref,
        b.attribute1                         AS dmt_reference
    FROM   inv_units_of_measure_b b
    WHERE  INSTR(',' || :P_UOM_CODES || ',', ',' || b.uom_code || ',') > 0
)
ORDER BY record_key
;
