-- ============================================================
-- Projects BIP Reconciliation Query (Two-Tier + Child Objects)
-- Data source: ApplicationDB_FSCM
-- Parameters: :P_LOAD_REQUEST_ID = Load ESS request ID (LOAD_REQUEST_ID)
--             :P_PREFIX = Run prefix (e.g. '9393') for Tier 2 base table matching
--
-- Returns rows for ALL 4 object types: Projects, Tasks, TeamMembers, TxnControls.
-- OBJECT_TYPE column discriminates which TFM table to update.
--
-- Projects:
--   Tier 1 (INTERFACE): PJF_PROJECTS_ALL_XFACE — error/unprocessed rows remain.
--   Tier 2 (BASE): PJF_PROJECTS_ALL_B — positively confirmed LOADED.
--
-- Tasks:
--   Tier 1 only: PJF_PROJ_ELEMENTS_XFACE — IMPORT_STATUS=SUBMITTED means rejected.
--   Successful tasks are purged from the interface table after import.
--
-- TeamMembers:
--   Tier 1 only: PJF_PROJECT_PARTIES_INT — same pattern as Tasks.
--
-- TxnControls:
--   Tier 1 only: PJC_TXN_CONTROLS_STAGE — uses LOAD_STATUS (no IMPORT_STATUS).
--
-- AD#19 note: None of these interface tables have error message columns.
-- Error detail comes exclusively from Import Report XML, fetched by
-- DMT_IMPORT_REPORT_PKG.PARSE_ERRORS in the results package.
-- ============================================================

-- Projects Tier 1 (INTERFACE)
SELECT
    'Projects'                          AS object_type,
    p.project_name,
    p.project_number,
    CAST(NULL AS VARCHAR2(240))         AS task_name,
    CAST(NULL AS VARCHAR2(240))         AS team_member_name,
    CAST(NULL AS VARCHAR2(240))         AS txn_ctrl_reference,
    'INTERFACE'                         AS source_type,
    p.import_status,
    p.load_status,
    CAST(NULL AS NUMBER)                AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))        AS error_message
FROM   pjf_projects_all_xface p
WHERE  p.load_request_id = :P_LOAD_REQUEST_ID

UNION ALL

-- Projects Tier 2 (BASE)
SELECT
    'Projects'                          AS object_type,
    CAST(NULL AS VARCHAR2(240))         AS project_name,
    p.segment1                          AS project_number,
    CAST(NULL AS VARCHAR2(240))         AS task_name,
    CAST(NULL AS VARCHAR2(240))         AS team_member_name,
    CAST(NULL AS VARCHAR2(240))         AS txn_ctrl_reference,
    'BASE'                              AS source_type,
    'SUCCESS'                           AS import_status,
    'SUCCESS'                           AS load_status,
    p.project_id                        AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))        AS error_message
FROM   pjf_projects_all_b p
WHERE  p.segment1 LIKE :P_PREFIX || '%'
AND    :P_PREFIX IS NOT NULL

UNION ALL

-- Tasks Tier 1 (INTERFACE)
SELECT
    'Tasks'                             AS object_type,
    CAST(NULL AS VARCHAR2(240))         AS project_name,
    t.project_number,
    t.task_name,
    CAST(NULL AS VARCHAR2(240))         AS team_member_name,
    CAST(NULL AS VARCHAR2(240))         AS txn_ctrl_reference,
    'INTERFACE'                         AS source_type,
    t.import_status,
    t.load_status,
    CAST(NULL AS NUMBER)                AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))        AS error_message
FROM   pjf_proj_elements_xface t
WHERE  t.load_request_id = :P_LOAD_REQUEST_ID

UNION ALL

-- TeamMembers Tier 1 (INTERFACE)
SELECT
    'TeamMembers'                       AS object_type,
    tm.project_name,
    CAST(NULL AS VARCHAR2(25))          AS project_number,
    CAST(NULL AS VARCHAR2(240))         AS task_name,
    tm.team_member_name,
    CAST(NULL AS VARCHAR2(240))         AS txn_ctrl_reference,
    'INTERFACE'                         AS source_type,
    tm.import_status,
    tm.load_status,
    CAST(NULL AS NUMBER)                AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))        AS error_message
FROM   pjf_project_parties_int tm
WHERE  tm.load_request_id = :P_LOAD_REQUEST_ID

UNION ALL

-- TxnControls Tier 1 (INTERFACE)
SELECT
    'TxnControls'                       AS object_type,
    CAST(NULL AS VARCHAR2(240))         AS project_name,
    tc.project_number,
    CAST(NULL AS VARCHAR2(240))         AS task_name,
    CAST(NULL AS VARCHAR2(240))         AS team_member_name,
    tc.txn_ctrl_reference,
    'INTERFACE'                         AS source_type,
    CAST(NULL AS VARCHAR2(50))          AS import_status,
    tc.load_status,
    CAST(NULL AS NUMBER)                AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))        AS error_message
FROM   pjc_txn_controls_stage tc
WHERE  tc.load_request_id = :P_LOAD_REQUEST_ID
