-- PACKAGE DMT_ZX_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_ZX_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_ZX_TRANSFORM_PKG
-- Transforms Tax Regimes and Tax Rates from STG to TFM tables.
-- Handles both ZX_REGIME and ZX_RATE in one package,
-- mirroring the Lookup Type/Value pattern.
-- ============================================================

    PROCEDURE TRANSFORM_REGIMES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

    PROCEDURE TRANSFORM_RATES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_ZX_TRANSFORM_PKG;
/
