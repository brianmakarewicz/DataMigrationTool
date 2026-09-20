-- ============================================================
-- UnitsOfMeasure BIP reconciliation query -- MIRROR of the deployed
-- data model bip/UnitsOfMeasure/DMT_UOM_RECON_DM.xdm (deploy target
-- /Custom/DMT2/UnitsOfMeasure/). The SELECT below is the byte-exact
-- CDATA body of that .xdm; regenerate this file from the .xdm
-- whenever the data model changes -- the mirror must never drift.
--
-- Report contract v1: NINE columns, keyset pagination, SIX standard
-- parameters. Same shape as bip/GLBalances/DMT_GL_BAL_RECON_DM.xdm.
--
-- NINE columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE
--
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID,
--   P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY (names must match what the
--   shared DMT_RECON_CONTRACT_PKG fetch loop sends). No P_OFFSET /
--   P_LIMIT.
--
-- Keyset: ORDER BY RECORD_KEY, only rows whose RECORD_KEY sorts
-- after :P_AFTER_KEY, at most :P_CHUNK_SIZE per page.
--
-- OBJECT MODEL: UnitsOfMeasure is REST-loaded (POST unitsOfMeasure,
-- one call per UOM). There is NO ESS import and NO Fusion interface
-- table, so this report has a BASE tier only -- a row in
-- INV_UNITS_OF_MEASURE_B is positive proof the UOM was created.
-- REST rejections are captured per-record from the POST response at
-- load time by the object's reconciler (DMT_INV_UOM_RESULTS_PKG, a
-- separate track), not by this report. LOAD_REQUEST_ID, SOURCE_REF,
-- and ERROR_MESSAGE are therefore NULL on every BASE row; they exist
-- only for nine-column contract symmetry.
--
-- KEYS:
--   RECORD_KEY    = UOM_CODE           (= TFM RECON_KEY; not run-prefixed)
--   FUSION_ID     = UNIT_OF_MEASURE_ID (surrogate id == REST UOMId)
--   DMT_REFERENCE = ATTRIBUTE1         (Slot C 'DMT:<run>:...' read-back)
--   SOURCE_REF    = NULL               (no native source-ref column on
--                                       INV_UNITS_OF_MEASURE_B)
--
-- ROW SELECTION (Slot C DFF): ATTRIBUTE1 LIKE 'DMT:'||:P_RUN_ID||':%'.
-- The run-scoped, contract-correct selector using the six standard
-- parameters only (codes are not run-prefixed, so P_PREFIX cannot
-- filter; there is no ESS id). Stamping ATTRIBUTE1 at load time is a
-- SEPARATE track (the current REST POST body does not write the DFF),
-- so this predicate returns zero rows for a run until that lands --
-- which is honest (zero base rows is never LOADED).
--
-- STANDALONE VALIDATION of the nine-column shape and keyset paging was
-- performed against a prior loaded UOM base row (UOM_CODE='DZ8',
-- UNIT_OF_MEASURE_ID=300000333812175, loaded by regression run 275)
-- by binding the run predicate to that code's presence. See the PR
-- body for the returned rows.
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
    WHERE  b.attribute1 LIKE 'DMT:' || :P_RUN_ID || ':%'
)
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
