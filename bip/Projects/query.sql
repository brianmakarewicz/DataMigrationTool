-- ============================================================
-- Projects reconciliation data model V2 -- BIP reconciliation
-- report contract v1 (nine columns, keyset pagination) plus the
-- owner-approved P_WQ_ID parameter. Data source:
-- ApplicationDB_FSCM. The repo mirror of this SQL is
-- bip/Projects/query.sql; the .xdm is authoritative.
-- V2 (2026-10-07) is deployed ALONGSIDE DMT_PROJECT_RECON_DM (V1);
-- BIP objects are never overwritten.
--
-- NINE response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE (plus the debug-only DEBUG_DISPOSITION, not
--   mapped into the report output).
--
-- PARAMETERS: the six Contract v1 parameters (P_RUN_ID,
--   P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID, P_PREFIX, P_CHUNK_SIZE,
--   P_AFTER_KEY) plus P_WQ_ID, the work item's queue id.
--
-- Projects is ONE object (one FBDI zip / one Import Projects job)
-- with four record types; OBJECT_TYPE discriminates the tier:
--   Projects, Tasks, TeamMembers, TxnControls.
--
-- ROW SELECTION -- owner-approved exception (DECIDED 2026-10-07,
-- design section 5). Reports find rows by Fusion job id, but the
-- project base tables carry none: PJF_PROJECTS_ALL_B.REQUEST_ID is
-- NULL after import, the task, team-member and transaction-control
-- base tables have no request-id column, and the interface is purged
-- after a successful import. So, like Customers, the transform
-- stamps the FBDI SOURCE_PROJECT_REFERENCE (stored by Fusion as
-- PJF_PROJECTS_ALL_B.PM_PROJECT_REFERENCE) with
-- '<run_id>:<work_queue_id>:<legacy reference>' when prefixing is
-- on, and this report selects the work item's projects by
--     PM_PROJECT_REFERENCE LIKE :P_RUN_ID || ':' || :P_WQ_ID || ':%'
-- That exact work-item scope is the only text-scoped row selection
-- allowed, and only for Projects. Tasks, team members and
-- transaction controls are reached through their project.
--   INTERFACE rows (all four tiers) are selected by the load job's
--   LOAD_REQUEST_ID = :P_LOAD_REQUEST_ID (anything left behind after
--   import is a rejection).
-- No LIKE on the run prefix. RECORD_KEY stays the prefixed project
-- number (and its task / team / control extensions); it is used
-- only to match a row Fusion returned back to its TFM row.
--
-- FUSION_STATUS normalized to exactly SUCCESS / ERROR:
--   BASE (row present in the Fusion base table)  => SUCCESS
--   INTERFACE (rejection left behind by Import)  => ERROR
-- FUSION_ID: Projects BASE = PROJECT_ID; Tasks BASE = PROJ_ELEMENT_ID;
--   TxnControls BASE = TXN_CONTROL_ID (PJC_TRANSACTION_CONTROLS);
--   TeamMembers BASE = PROJ_RESOURCE_ID (PJT_PROJECT_RESOURCE);
--   INTERFACE rows have no Fusion id yet (NULL).
-- ERROR_MESSAGE: the Projects interface tables carry no error-text
--   column, so an ERROR row returns the Contract v1 marker
--   '#IMPORT_REPORT#'; the reconciler takes the real per-row message
--   from the Import Report XML (the child ImportProjectReportJob).
--
-- Keyset: ORDER BY RECORD_KEY (pinned to BINARY so the ordering
-- and the > comparison agree), only rows whose RECORD_KEY sorts
-- after :P_AFTER_KEY, at most :P_CHUNK_SIZE per page.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference,
    debug_disposition
FROM (
    -- Projects tier : BASE -- the work item's projects, found by the reference
    -- DMT stamps (<run_id>:<work_queue_id>:<legacy ref>), owner-approved exception.
    SELECT
        'Projects'                           AS object_type,
        p.segment1                           AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        p.project_id                         AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)        AS load_request_id,
        p.segment1                           AS source_ref,
        p.segment1                           AS dmt_reference,
        CAST(NULL AS VARCHAR2(4000))         AS debug_disposition
    FROM   pjf_projects_all_b p
    WHERE  :P_RUN_ID IS NOT NULL AND :P_WQ_ID IS NOT NULL
    AND    p.pm_project_reference LIKE :P_RUN_ID || ':' || :P_WQ_ID || ':%'

    UNION ALL

    -- Projects tier : INTERFACE (rejections left behind).
    SELECT
        'Projects'                           AS object_type,
        x.project_number                     AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '#IMPORT_REPORT#'                    AS error_message,
        x.load_request_id                    AS load_request_id,
        x.project_number                     AS source_ref,
        x.project_number                     AS dmt_reference,
        '[PROJECT] Left in interface after import (IMPORT_STATUS='
             || NVL(x.import_status,'?') || ', LOAD_STATUS='
             || NVL(x.load_status,'?')
             || '). See Import Report for the row-level message.'
                                             AS debug_disposition
    FROM   pjf_projects_all_xface x
    WHERE  x.load_request_id = :P_LOAD_REQUEST_ID

    UNION ALL

    -- Tasks tier : BASE (PJF_TASKS rows only; join project for the key).
    SELECT
        'Tasks'                              AS object_type,
        p.segment1 || '/' || e.element_number AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        e.proj_element_id                    AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)        AS load_request_id,
        p.segment1 || '/' || e.element_number AS source_ref,
        p.segment1 || '/' || e.element_number AS dmt_reference,
        CAST(NULL AS VARCHAR2(4000))         AS debug_disposition
    FROM   pjf_proj_elements_b e
    JOIN   pjf_projects_all_b  p ON p.project_id = e.project_id
    WHERE  :P_RUN_ID IS NOT NULL AND :P_WQ_ID IS NOT NULL
    AND    p.pm_project_reference LIKE :P_RUN_ID || ':' || :P_WQ_ID || ':%'
    AND    e.object_type = 'PJF_TASKS'

    UNION ALL

    -- Tasks tier : INTERFACE (rejections left behind).
    SELECT
        'Tasks'                              AS object_type,
        t.project_number || '/' || t.task_number AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '#IMPORT_REPORT#'                    AS error_message,
        t.load_request_id                    AS load_request_id,
        t.project_number || '/' || t.task_number AS source_ref,
        t.project_number || '/' || t.task_number AS dmt_reference,
        '[TASK] Left in interface after import (IMPORT_STATUS='
             || NVL(t.import_status,'?') || ', LOAD_STATUS='
             || NVL(t.load_status,'?')
             || '). See Import Report for the row-level message.'
                                             AS debug_disposition
    FROM   pjf_proj_elements_xface t
    WHERE  t.load_request_id = :P_LOAD_REQUEST_ID

    UNION ALL

    -- TeamMembers tier : BASE (positive LOADED confirmation).
    -- Team members DO land in a queryable Fusion base table on this instance:
    -- PJT_PROJECT_RESOURCE (Project Management team-member assignments), one row per
    -- loaded member with a real id (PROJ_RESOURCE_ID), keyed to the project via
    -- PROJECT_ID and to the person via RESOURCE_ID. The prior "no base table" claim
    -- checked only the FINANCIAL project-parties view PJF_PROJECT_PARTIES, a
    -- different representation that is empty for every DMT-migrated project;
    -- PJT_PROJECT_RESOURCE is where Import Project actually persists accepted members.
    -- Confirmed live 2026-09-21 (run 327 / prefix 10267): Alan Cook -> PROJ_RESOURCE_ID
    -- 300000333829040, Mandy Steward -> 300000333829065. The base table carries no
    -- project number, so join PJF_PROJECTS_ALL_VL for the prefix filter and the
    -- descriptive project NAME, and PJT_PRJ_ENTERPRISE_RESOURCE_VL for the member
    -- DISPLAY_NAME, so RECORD_KEY (project NAME || '/TM/' || display name) matches the
    -- transform's RECON_KEY exactly (PROJECT_NAME || '/TM/' || TEAM_MEMBER_NAME).
    -- FUSION_ID = PROJ_RESOURCE_ID so the reconciler marks the TFM row LOADED with a
    -- real Fusion base id -- Rule #1 satisfied exactly like every other tier.
    SELECT
        'TeamMembers'                        AS object_type,
        pv.name || '/TM/' || er.display_name AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        pr.proj_resource_id                  AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)        AS load_request_id,
        pv.name || '/TM/' || er.display_name AS source_ref,
        pv.name || '/TM/' || er.display_name AS dmt_reference,
        CAST(NULL AS VARCHAR2(4000))         AS debug_disposition
    FROM   pjt_project_resource            pr
    JOIN   pjf_projects_all_vl             pv ON pv.project_id  = pr.project_id
    JOIN   pjt_prj_enterprise_resource_vl er ON er.resource_id = pr.resource_id
    JOIN   pjf_projects_all_b             pb ON pb.project_id  = pr.project_id
    WHERE  :P_RUN_ID IS NOT NULL AND :P_WQ_ID IS NOT NULL
    AND    pb.pm_project_reference LIKE :P_RUN_ID || ':' || :P_WQ_ID || ':%'

    UNION ALL

    -- TeamMembers tier : INTERFACE (rejections left behind).
    -- Anything still in the interface table after import is a rejection (Import
    -- purges the accepted members). Keyed by project name + member name.
    SELECT
        'TeamMembers'                        AS object_type,
        tm.project_name || '/TM/' || tm.team_member_name AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '#IMPORT_REPORT#'                    AS error_message,
        tm.load_request_id                   AS load_request_id,
        tm.project_name || '/TM/' || tm.team_member_name AS source_ref,
        tm.project_name || '/TM/' || tm.team_member_name AS dmt_reference,
        '[TEAMMEMBER] Left in interface after import (IMPORT_STATUS='
             || NVL(tm.import_status,'?') || ', LOAD_STATUS='
             || NVL(tm.load_status,'?')
             || '). See Import Report for the row-level message.'
                                             AS debug_disposition
    FROM   pjf_project_parties_int tm
    WHERE  tm.load_request_id = :P_LOAD_REQUEST_ID

    UNION ALL

    -- TxnControls tier : BASE (positive LOADED confirmation).
    -- Transaction controls DO land in a queryable Fusion base table on this
    -- instance: PJC_TRANSACTION_CONTROLS, one row per loaded control with a real id
    -- (TXN_CONTROL_ID) and the source TXN_CTRL_REFERENCE, keyed to the project via
    -- PROJECT_ID. Confirmed live 2026-09-21 (run 325 / prefix 10265):
    -- RT-TXC-RTPRJ001 -> TXN_CONTROL_ID 100002642117705, RT-TXC-RTPRJ002 ->
    -- 100002642117706. The base table carries no project number, so join to
    -- PJF_PROJECTS_ALL_B for the prefix filter and the RECORD_KEY (PROJECT_NUMBER ||
    -- '/TC/' || TXN_CTRL_REFERENCE), which matches the transform's RECON_KEY exactly.
    -- FUSION_ID = TXN_CONTROL_ID so the reconciler marks the TFM row LOADED with a
    -- real Fusion base id -- Rule #1 satisfied the same way every other object is.
    SELECT
        'TxnControls'                        AS object_type,
        p.segment1 || '/TC/' || tc.txn_ctrl_reference AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        tc.txn_control_id                    AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)        AS load_request_id,
        p.segment1 || '/TC/' || tc.txn_ctrl_reference AS source_ref,
        p.segment1 || '/TC/' || tc.txn_ctrl_reference AS dmt_reference,
        CAST(NULL AS VARCHAR2(4000))         AS debug_disposition
    FROM   pjc_transaction_controls tc
    JOIN   pjf_projects_all_b        p ON p.project_id = tc.project_id
    WHERE  :P_RUN_ID IS NOT NULL AND :P_WQ_ID IS NOT NULL
    AND    p.pm_project_reference LIKE :P_RUN_ID || ':' || :P_WQ_ID || ':%'

    UNION ALL

    -- TxnControls tier : INTERFACE (rejections left in staging).
    -- Anything still sitting in the staging table after import is a rejection (the
    -- staging rows are emptied on success). The staging table carries no per-row
    -- error text, so return the '#IMPORT_REPORT#' marker and let the reconciler
    -- overlay the true Fusion message from the child report. Keyed by project number
    -- + control reference.
    SELECT
        'TxnControls'                        AS object_type,
        tc.project_number || '/TC/' || tc.txn_ctrl_reference AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '#IMPORT_REPORT#'                    AS error_message,
        tc.load_request_id                   AS load_request_id,
        tc.project_number || '/TC/' || tc.txn_ctrl_reference AS source_ref,
        tc.project_number || '/TC/' || tc.txn_ctrl_reference AS dmt_reference,
        '[TXNCONTROL] Left in staging after import (LOAD_STATUS='
             || NVL(tc.load_status,'?')
             || '). See Import Report for the row-level message.'
                                             AS debug_disposition
    FROM   pjc_txn_controls_stage tc
    WHERE  tc.load_request_id = :P_LOAD_REQUEST_ID
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start". On later pages P_AFTER_KEY
-- carries the previous page's last RECORD_KEY; only greater keys return.
-- The ordering and the comparison are both pinned to BINARY so they agree.
WHERE  (:P_AFTER_KEY IS NULL
        OR NLSSORT(record_key, 'NLS_SORT=BINARY') > NLSSORT(:P_AFTER_KEY, 'NLS_SORT=BINARY'))
ORDER BY NLSSORT(record_key, 'NLS_SORT=BINARY')
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
      
