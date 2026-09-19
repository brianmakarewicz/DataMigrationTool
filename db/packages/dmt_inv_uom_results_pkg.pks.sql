-- PACKAGE DMT_INV_UOM_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_INV_UOM_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_INV_UOM_RESULTS_PKG
-- REST load + BIP base-table reconciliation for Units of Measure.
--
-- New reconciliation standard (DMT_DESIGN.html, PROPOSED 2026-09):
-- reconciliation MUST be a BIP report over the Fusion base table that
-- returns the base-table surrogate id. A REST load-call HTTP 200 is NOT
-- reconciliation. So load and reconcile are two separate phases:
--   LOAD:      POST each GENERATED UOM to the unitsOfMeasure REST resource.
--              A non-2xx/exception is a real rejection -> FAILED with the
--              REST error. A 2xx is left GENERATED (not LOADED).
--   RECONCILE: run DMT_UOM_RECON_RPT over the run's UOM codes against the
--              base table INV_UNITS_OF_MEASURE_B. A code found there is
--              LOADED with FUSION_UOM_ID = UNIT_OF_MEASURE_ID (the real
--              surrogate id, == the REST UOMId). Codes not found stay as
--              the load step set them -- never a fabricated LOADED or id.
-- ============================================================

    -- Load all GENERATED TFM rows via REST, then reconcile them against the
    -- Fusion base table via BIP (capturing FUSION_UOM_ID for confirmed rows).
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    );

END DMT_INV_UOM_RESULTS_PKG;
/
