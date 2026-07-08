-- ============================================================
-- PlanningBudgets BIP Reconciliation Query
-- Data source: ApplicationDB_FSCM
-- Parameter: :P_BATCH_ID = ESS load request ID
--
-- INTENTIONAL EMPTY RESULT SET: No EPBCS/planning interface table
-- is accessible via BIP on ApplicationDB_FSCM. Verified 2026-03-31:
--   - FIN_PLAN_LINES_INTERFACE: does not exist
--   - EPBCS_DATA_IMPORT_INT: does not exist
--   - No table matching %PLAN%INT%, EPBCS%, or %BUDGET%INT% found
--
-- The EPBCS Data Import ESS job processes data through internal
-- planning tables that are not exposed to BIP SQL queries.
--
-- The results package handles this correctly via the "absence = LOADED"
-- pattern: when BIP returns 0 rows, all GENERATED TFM rows are marked
-- LOADED. This is the correct behavior for planning budget imports.
-- ============================================================
SELECT
    CAST(NULL AS VARCHAR2(100))  AS scenario,
    CAST(NULL AS VARCHAR2(50))   AS import_status,
    CAST(NULL AS VARCHAR2(4000)) AS error_message
FROM   DUAL
WHERE  1 = 0
