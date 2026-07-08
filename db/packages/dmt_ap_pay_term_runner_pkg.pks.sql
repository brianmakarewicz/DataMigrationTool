-- PACKAGE DMT_AP_PAY_TERM_RUNNER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AP_PAY_TERM_RUNNER_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AP_PAY_TERM_RUNNER_PKG
-- Orchestrates the Payment Terms pipeline:
-- Pre-validate -> Transform Headers -> Transform Lines
-- -> Post-validate -> Generate FBL -> Load & Reconcile
-- ============================================================

    PROCEDURE RUN (
        p_run_id   IN NUMBER,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_AP_PAY_TERM_RUNNER_PKG;
/
