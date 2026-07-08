-- PACKAGE DMT_FND_VS_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FND_VS_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_FND_VS_RESULTS_PKG
-- REST-based load + reconciliation for FND Value Sets and Values.
--
-- Loads value sets to Fusion via REST POST (valueSets endpoint),
-- then creates child values. Updates TFM/STG status to LOADED/FAILED.
--
-- REST pattern (not FBDI/ESS):
--   POST valueSets                                -> create value set
--   POST valueSets/{ValueSetCode}/child/values    -> create value
-- ============================================================

    -- Load all GENERATED TFM rows to Fusion via REST and reconcile.
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    );

END DMT_FND_VS_RESULTS_PKG;
/
