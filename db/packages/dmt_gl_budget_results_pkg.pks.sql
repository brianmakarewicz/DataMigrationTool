-- PACKAGE DMT_GL_BUDGET_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GL_BUDGET_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_GL_BUDGET_RESULTS_PKG
-- Post-load reconciliation for GL Budget Balances.
-- CEMLI_CODE: 'GLBudgets'
--
-- Budgets are CELLS, not transactions: GL_BUDGET_BALANCES has one row per
-- (ledger + budget_name + period + account segments + currency + currency_type)
-- and carries NO run_name/request_id/interface id. Reconciliation therefore uses
-- a RUN-START window + cell key + DR/CR amount:
--   * LOADED  = a GL_BUDGET_BALANCES cell touched since run start whose DR/CR
--               matches the staged amount (loose positive confirmation).
--   * FAILED  = a row lingering in GL_BUDGET_INTERFACE (successful rows are
--               consumed on load) created since run start, with ERROR_MESSAGE.
--   * Rows matched by neither are left un-terminal (accounting rule: not DONE).
--
-- Signature keeps the generic 3-arg RECONCILE_BATCH the loader dispatch expects,
-- plus optional p_run_start / p_ledger_id supplied by the custom GL-Budget loader
-- block. When p_run_start is NULL it defaults to a wide same-instance window.
-- ============================================================
    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER    DEFAULT NULL,
        p_run_start     IN TIMESTAMP DEFAULT NULL,
        p_ledger_id     IN NUMBER    DEFAULT NULL,
        p_work_queue_id IN NUMBER    DEFAULT NULL
    );

    FUNCTION FETCH_BIP_RESULTS (
        p_run_id     IN NUMBER,
        p_run_start  IN TIMESTAMP DEFAULT NULL,
        p_ledger_id  IN NUMBER    DEFAULT NULL
    ) RETURN CLOB;

    PROCEDURE PARSE_AND_UPDATE (p_run_id IN NUMBER, p_xml_data IN CLOB);
END DMT_GL_BUDGET_RESULTS_PKG;
/
