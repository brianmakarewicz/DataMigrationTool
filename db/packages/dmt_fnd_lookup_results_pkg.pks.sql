-- PACKAGE DMT_FND_LOOKUP_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FND_LOOKUP_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_FND_LOOKUP_RESULTS_PKG
-- REST-based load + reconciliation for FND Lookup Types and Values.
--
-- Loads lookups to Fusion via REST POST (standardLookups endpoint),
-- then verifies via REST GET. Updates TFM/STG status to LOADED/FAILED.
--
-- REST pattern (not FBDI/ESS):
--   POST standardLookups          -> create lookup type
--   POST standardLookups/{type}/child/lookupCodes -> create lookup codes
--   GET  standardLookups/{type}?expand=lookupCodes -> verify
-- ============================================================

    -- Load all GENERATED TFM rows to Fusion via REST and reconcile.
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    );

END DMT_FND_LOOKUP_RESULTS_PKG;
/
