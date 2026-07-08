CREATE OR REPLACE PACKAGE DMT_LOOKUP.DMT_LKP_REFRESH_PKG AS
-- ============================================================
-- DMT_LKP_REFRESH_PKG
-- Calls pre-deployed BIP data models on Fusion to fetch
-- reference values and MERGEs them into DMT_LKP_FUSION_VALUES.
-- Uses BIP v2 SOAP runDataModel (static catalog path).
-- Logs to DMT_OWNER.DMT_LOG_TBL.
-- ============================================================

    -- Refresh Fusion values for one lookup type (or all if NULL)
    PROCEDURE REFRESH_FUSION_VALUES (
        p_lookup_type IN VARCHAR2 DEFAULT NULL
    );

    -- Convenience: refresh all active lookup types
    PROCEDURE REFRESH_ALL_FUSION_VALUES;

END DMT_LKP_REFRESH_PKG;
/
