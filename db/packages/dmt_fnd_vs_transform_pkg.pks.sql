-- PACKAGE DMT_FND_VS_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FND_VS_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_FND_VS_TRANSFORM_PKG
-- Transforms Value Sets and Values from STG to TFM tables.
-- Handles both FND_VS_SET and FND_VS_VALUE in one package,
-- mirroring the Lookup Type/Value pattern.
-- ============================================================

    PROCEDURE TRANSFORM_SETS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

    PROCEDURE TRANSFORM_VALUES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_FND_VS_TRANSFORM_PKG;
/
