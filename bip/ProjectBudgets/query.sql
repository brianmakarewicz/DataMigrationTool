-- ============================================================
-- ProjectBudgets BIP Reconciliation Query (Two-Tier)
-- Data source: ApplicationDB_FSCM
-- Parameters: :P_BATCH_ID = Load ESS request ID (LOAD_REQUEST_ID)
--             :P_IMPORT_ESS_ID = Import ESS request ID (for base table lookup)
--
-- Tier 1 (INTERFACE): Rows in PJO_PLAN_VERSIONS_XFACE after import.
--   PROCESS_CODE and LOAD_STATUS indicate per-row outcome.
--
-- Tier 2 (BASE): Rows that reached PJO_PLAN_VERSIONS_B.
--   Linked via REQUEST_ID = Import ESS job ID.
--
-- AD#19 note: PJO_PLAN_VERSIONS_XFACE has NO error message column (verified:
-- no %MSG%, %ERR%, %DETAIL% columns exist). Error detail comes from
-- Import Report XML via DMT_IMPORT_REPORT_PKG.PARSE_ERRORS in the results
-- package. The BIP query returns status only.
-- ============================================================
SELECT
    v.project_name,
    v.project_number,
    v.plan_version_name,
    v.financial_plan_type,
    v.src_budget_line_reference,
    'INTERFACE'                         AS source_type,
    v.process_code,
    v.load_status,
    CAST(NULL AS NUMBER)                AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))        AS error_message
FROM   pjo_plan_versions_xface v
WHERE  v.load_request_id = :P_BATCH_ID

UNION ALL

SELECT
    p.project_name,
    p.project_number,
    v.plan_version_name,
    v.financial_plan_type,
    v.src_budget_line_reference,
    'BASE'                              AS source_type,
    'SUCCESS'                           AS process_code,
    'SUCCESS'                           AS load_status,
    v.plan_version_id                   AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))        AS error_message
FROM   pjo_plan_versions_b v
JOIN   pjf_projects_all_b p ON p.project_id = v.project_id
WHERE  v.request_id = :P_IMPORT_ESS_ID
AND    :P_IMPORT_ESS_ID IS NOT NULL
