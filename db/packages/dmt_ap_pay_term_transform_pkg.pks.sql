-- PACKAGE DMT_AP_PAY_TERM_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AP_PAY_TERM_TRANSFORM_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AP_PAY_TERM_TRANSFORM_PKG
-- Transforms Payment Term Headers and Lines from STG to TFM.
-- Two-level hierarchy: HDR (term) -> LINE (installment).
-- ============================================================

    PROCEDURE TRANSFORM_HEADERS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

    PROCEDURE TRANSFORM_LINES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_AP_PAY_TERM_TRANSFORM_PKG;
/
