-- PACKAGE DMT_INV_UOM_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_INV_UOM_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_INV_UOM_RESULTS_PKG
-- REST-based load + reconciliation for Units of Measure.
--
-- Loads UOMs to Fusion via REST POST (unitsOfMeasure endpoint),
-- then verifies via REST GET. Updates TFM/STG status to LOADED/FAILED.
--
-- REST pattern (not FBDI/ESS):
--   POST unitsOfMeasure          -> create UOM
--   GET  unitsOfMeasure?q=UOMCode='XXX' -> verify
-- ============================================================

    -- Load all GENERATED TFM rows to Fusion via REST and reconcile.
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    );

END DMT_INV_UOM_RESULTS_PKG;
/
