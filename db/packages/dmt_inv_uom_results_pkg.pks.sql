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

    -- ------------------------------------------------------------
    -- APPLY_UOM — UnitsOfMeasure' thin STATIC apply for the generic recon
    -- engine (DMT_RECON_ENGINE_PKG), the same shape as DMT_GL_RESULTS_PKG.APPLY_GL.
    -- By the time the engine dispatches this proc through the sanctioned
    -- invoke_registered site (style RECON), it has already keyset-paged the
    -- deployed nine-column Contract v1 recon report and staged the parsed rows
    -- into DMT_RECON_STAGE_GTT for this RUN_ID. This proc reads that GTT and
    -- MERGEs into the LITERALLY-named DMT_INV_UOM_TFM_TBL with STATIC SQL:
    --   * LOADED on SOURCE_TYPE='BASE' AND FUSION_STATUS='SUCCESS', capturing
    --             FUSION_UOM_ID from the report's FUSION_ID;
    --   * FAILED on FUSION_STATUS='ERROR', appending the real Fusion error
    --             tagged [FUSION_ERROR].
    -- Rows with no match and no error STAY GENERATED (the shared sweep settles
    -- them). Both MERGEs scope to RUN_ID, plus WORK_QUEUE_ID for a child item.
    -- The parameter shape matches invoke_registered's RECON style; only p_run_id
    -- and p_work_queue_id are used, the ESS ids ride the signature unused.
    -- ------------------------------------------------------------
    PROCEDURE APPLY_UOM (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER   DEFAULT NULL,
        p_import_ess_id IN NUMBER   DEFAULT NULL,
        p_work_queue_id IN NUMBER   DEFAULT NULL
    );

END DMT_INV_UOM_RESULTS_PKG;
/
