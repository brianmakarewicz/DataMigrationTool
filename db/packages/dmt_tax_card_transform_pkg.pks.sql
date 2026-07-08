-- PACKAGE DMT_TAX_CARD_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_TAX_CARD_TRANSFORM_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_TAX_CARD_TRANSFORM_PKG
-- Transforms staged CalculationCard HDL records into the transformed table(s).
-- Called by DMT_LOADER_PKG before HDL generation.
-- ============================================================

    PROCEDURE TRANSFORM_TAXCARDS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_TAX_CARD_TRANSFORM_PKG;
/
