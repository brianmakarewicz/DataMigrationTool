-- PACKAGE DMT_CE_BANK_RUNNER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CE_BANK_RUNNER_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_CE_BANK_RUNNER_PKG
-- Orchestrates the Cash Management Banks pipeline:
-- Pre-validate -> Transform Banks -> Transform Branches
-- -> Transform Accounts -> Post-validate -> Generate FBL
-- -> Load & Reconcile
-- ============================================================

    PROCEDURE RUN (
        p_run_id   IN NUMBER,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_CE_BANK_RUNNER_PKG;
/
