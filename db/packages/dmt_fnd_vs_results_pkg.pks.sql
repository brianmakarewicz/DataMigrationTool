-- PACKAGE DMT_FND_VS_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FND_VS_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_FND_VS_RESULTS_PKG
-- FBDI-file + ESS-import load (loadAndImportData) + BIP base-table
-- reconciliation for FND Value Sets and Values.
--
-- Loads value set VALUES to Fusion via the house FBDI path: the generated
-- FND_VS zip (built by DMT_FND_VS_FBL_GEN_PKG) is uploaded to UCM and imported
-- by the Fusion "Upload Value Set Values" scheduled process
-- (FndValueSetUploadServiceJob) through the shared DMT_LOADER_PKG.SUBMIT_LOAD
-- (loadAndImportData) + POLL_ESS_JOB. This replaces the dead REST POST path
-- (the valueSets REST "create" action is disabled on the demo pod). Reconcile
-- is unchanged: a BIP report over the Fusion base tables confirms LOADED and
-- captures the real surrogate id; rows not confirmed stay as the load step set
-- them (FAILED on a real ESS error, else GENERATED/unaccounted).
--
-- FBDI/ESS pattern (not REST):
--   loadAndImportData(FND_VS zip) -> Upload Value Set Values ESS job
--   BIP DMT_VS_RECON_RPT over FND_VS_VALUE_SETS + FND_VS_VALUES_B -> LOADED
-- ============================================================

    -- Load all GENERATED TFM rows to Fusion via REST and reconcile.
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    );

END DMT_FND_VS_RESULTS_PKG;
/
