-- PACKAGE DMT_ZX_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_ZX_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_ZX_RESULTS_PKG
-- REST-based load + reconciliation for Tax Regimes and Rates.
--
-- Loads tax configuration to Fusion via REST POST (taxRegimes
-- endpoint), then creates child rates. Updates TFM/STG status
-- to LOADED/FAILED.
--
-- NOTE: Tax REST API structure may be complex
-- (regime > tax > status > rate hierarchy). If the REST POST
-- fails with 404, the error is logged and the row is marked
-- FAILED rather than crashing — the exact endpoint structure
-- can be refined later.
-- ============================================================

    -- Load all GENERATED TFM rows to Fusion via REST and reconcile.
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    );

END DMT_ZX_RESULTS_PKG;
/
