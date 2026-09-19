-- ============================================================
-- UnitsOfMeasure BIP reconciliation query -- MIRROR of the deployed
-- data model bip/UnitsOfMeasure/DMT_UOM_RECON_DM.xdm (deploy target
-- /Custom/DMT2/UnitsOfMeasure/). The SQL below is the byte-exact
-- CDATA body of that .xdm; regenerate this file from the .xdm
-- whenever the data model changes -- the mirror must never drift.
--
-- New reconciliation standard (DMT_DESIGN.html, PROPOSED 2026-09):
-- reconciliation is a BIP report over the Fusion BASE table, returning
-- the base-table surrogate id. A REST load-call HTTP 200 is NOT
-- reconciliation. For UnitsOfMeasure the base table is
-- INV_UNITS_OF_MEASURE_B; the surrogate id is UNIT_OF_MEASURE_ID (the
-- same value the unitsOfMeasure REST resource returns as UOMId).
--
-- Data source: ApplicationDB_FSCM
-- Parameter:
--   :P_UOM_CODES = comma-delimited list of the UOM codes this run sent
--                  to Fusion (e.g. 'DZ8,DZ7'). Config UOM codes are 3
--                  characters and are NOT run-prefixed (a numeric prefix
--                  would not fit UOM_CODE VARCHAR2(3)), so the reconciler
--                  matches on the exact codes of this run's TFM rows,
--                  passed as this list. The comma-boundary INSTR match
--                  (',DZ8,' inside ',DZ8,DZ7,') avoids substring false
--                  positives.
--
-- BASE tier only: a row present in INV_UNITS_OF_MEASURE_B is positive
-- proof the UOM was created; FUSION_ID = UNIT_OF_MEASURE_ID. Codes not
-- returned by this report were not created and are handled by the
-- reconciler (FAILED with the real REST error, else left unaccounted).
-- ============================================================
SELECT
    b.uom_code                           AS record_key,
    'SUCCESS'                            AS import_status,
    'BASE'                               AS source_type,
    b.unit_of_measure_id                 AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))         AS error_message
FROM   inv_units_of_measure_b b
WHERE  INSTR(',' || :P_UOM_CODES || ',', ',' || b.uom_code || ',') > 0
