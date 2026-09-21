-- ============================================================
-- Projects reconciliation query -- BIP reconciliation report
-- contract v1 (nine columns, keyset pagination, six standard
-- parameters). Mirrors the SQL embedded in DMT_PROJECT_RECON_DM.xdm
-- for review; the .xdm is authoritative.
--
-- NINE response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE.
--
-- SIX parameters (Contract v1): P_RUN_ID, P_LOAD_REQUEST_ID,
--   P_IMPORT_ESS_ID, P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY.
--   No P_OFFSET / P_LIMIT.
--
-- KEYSET pagination: rows are ordered by RECORD_KEY and only rows
-- whose RECORD_KEY sorts AFTER :P_AFTER_KEY are returned, at most
-- :P_CHUNK_SIZE of them. The reconciler's shared fetch loop calls
-- with an empty cursor first, then passes the last RECORD_KEY it
-- received on each next call, until a page returns fewer than
-- P_CHUNK_SIZE rows. An empty :P_AFTER_KEY selects from the start
-- (every non-null RECORD_KEY sorts after the empty string).
--
-- Projects is ONE object loaded by one FBDI zip / one Import ESS job,
-- carrying four record types. OBJECT_TYPE discriminates the tier so
-- the reconciler knows which TFM table each row belongs to:
--   Projects, Tasks, TeamMembers, TxnControls.
--
-- ROW SELECTION -- what actually works on this instance (proven live,
-- confirmed 2026-09-20 against loaded prefix 10061):
--   The FBDI reference columns the contract prefers are NOT populated
--   for Projects on this demo: PJF_PROJECTS_ALL_B.REQUEST_ID is NULL
--   after import (so base->interface on :P_LOAD_REQUEST_ID cannot
--   match a base row), and PM_PROJECT_REFERENCE / ATTRIBUTE1 /
--   ATTRIBUTE_CATEGORY come back empty (so neither the DFF nor the
--   native source-ref path finds anything). The only reliable base
--   identity is the run prefix stamped into PROJECT_NUMBER (SEGMENT1).
--   This matches the object's proven reconciler (README DB-17).
--   So:
--     BASE  rows  -> matched by SEGMENT1 LIKE :P_PREFIX || '%'
--                    (positive LOADED confirmation).
--     INTERFACE   -> the interface rows the Import ESS job left behind,
--                    carrying :P_LOAD_REQUEST_ID. Import purges the
--                    successfully-imported rows, so anything still
--                    present is a rejection (IMPORT_STATUS / LOAD_STATUS
--                    carry the disposition; there is no per-row error
--                    text column -- see below).
--   :P_RUN_ID and :P_IMPORT_ESS_ID are declared for contract symmetry.
--
-- FUSION_STATUS is normalized to exactly SUCCESS / ERROR here:
--   BASE (row exists in the Fusion base table)     => SUCCESS
--   INTERFACE (rejection left behind by Import)     => ERROR
--
-- FUSION_ID:
--   Projects    BASE => PJF_PROJECTS_ALL_B.PROJECT_ID
--   Tasks       BASE => PJF_PROJ_ELEMENTS_B.PROJ_ELEMENT_ID
--   TxnControls BASE => PJC_TRANSACTION_CONTROLS.TXN_CONTROL_ID
--   INTERFACE rows have no Fusion id yet (NULL).
--   TeamMembers has no queryable base row on this instance, so it emits
--   only INTERFACE rows; a loaded team member is left UNACCOUNTED
--   (never fabricated LOADED).
--
-- ERROR_MESSAGE: the Projects interface tables carry NO error-text
--   column (confirmed: PJF_PROJECTS_ALL_XFACE has only IMPORT_STATUS /
--   LOAD_STATUS, no MESSAGE_TEXT / ERROR_MESSAGE). The real per-row
--   rejection message lives only in the Import Report XML that the
--   reconciler package pulls from the child ImportProjectReportJob.
--   Per Contract v1, an ERROR row therefore returns the literal marker
--   '#IMPORT_REPORT#' -- a wire-time signal telling the reconciler to
--   invoke the import-report fallback and overlay the true Fusion
--   message. The human-readable interface disposition (IMPORT_STATUS /
--   LOAD_STATUS) is kept for troubleshooting in DEBUG_DISPOSITION, a
--   debug-only tenth column PAST the nine contract columns; it is not
--   mapped into the report output.
--
-- SOURCE_REF / DMT_REFERENCE: the FBDI SOURCE_PROJECT_REFERENCE and
--   ATTRIBUTE1 the pipeline sends are not read back on this instance
--   (empty in the base table), so the reliable, always-present source
--   reference is PROJECT_NUMBER itself. SOURCE_REF = the record's
--   business key; DMT_REFERENCE = PROJECT_NUMBER (the prefix-scoped run
--   key). Both are populated on every row so the reconciler always has
--   a handle back to the originating record.
--
-- Keys per tier (RECORD_KEY, ordered, unique within a run):
--   Projects    : PROJECT_NUMBER
--   Tasks       : PROJECT_NUMBER || '/' || TASK_NUMBER
--   TeamMembers : PROJECT_NUMBER || '/TM/' || <party/member key>
--   TxnControls : PROJECT_NUMBER || '/TC/' || <control key>
-- ============================================================
-- The nine contract columns are selected by the report. DEBUG_DISPOSITION
-- is a tenth, debug-only column carried in the SQL for troubleshooting; it
-- is NOT mapped as a report element and never reaches the contract output.
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference,
    debug_disposition
FROM (
    -- ---- Projects tier : BASE (positive LOADED confirmation) --------
    -- Matched by run prefix on SEGMENT1; REQUEST_ID is NULL on the base
    -- table so the prefix is the only reliable base identity.
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
    WHERE  :P_PREFIX IS NOT NULL
    AND    p.segment1 LIKE :P_PREFIX || '%'

    UNION ALL

    -- ---- Projects tier : INTERFACE (rejections left behind) ---------
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

    -- ---- Tasks tier : BASE ------------------------------------------
    -- PJF_PROJ_ELEMENTS_B holds one PJF_STRUCTURES row per project and
    -- one PJF_TASKS row per task; only PJF_TASKS rows are real tasks.
    -- The base table has no project number, so join to the project for
    -- the prefix filter and the record key.
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
    WHERE  :P_PREFIX IS NOT NULL
    AND    p.segment1 LIKE :P_PREFIX || '%'
    AND    e.object_type = 'PJF_TASKS'

    UNION ALL

    -- ---- Tasks tier : INTERFACE (rejections left behind) ------------
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

    -- ---- TeamMembers tier : INTERFACE only --------------------------
    -- Team members have NO queryable Fusion base row on this instance.
    -- Confirmed live 2026-09-21 (run 325 / prefix 10265, project ids
    -- 300000333828672 and 300000333828697): PJF_PROJECT_PARTIES held zero
    -- rows for either loaded project -- and zero for ANY DMT-migrated
    -- project across all prefixes -- even after the async provisioning
    -- window had passed, while the interface table was also empty (Import
    -- accepted and purged the members). With no accessible base id, this
    -- data model cannot emit a BASE/SUCCESS row for a loaded team member,
    -- so a LOADED team member is honestly left UNACCOUNTED (the TFM row
    -- stays GENERATED); we do not fabricate a LOADED without base evidence.
    -- This INTERFACE block still catches rejections. Keyed by project name
    -- + member name (the interface table carries no project number).
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

    -- ---- TxnControls tier : BASE (positive LOADED confirmation) -----
    -- Transaction controls DO land in a queryable Fusion base table on this
    -- instance: PJC_TRANSACTION_CONTROLS, one row per loaded control with a
    -- real id (TXN_CONTROL_ID) and the source TXN_CTRL_REFERENCE, keyed to
    -- the project via PROJECT_ID. Confirmed live 2026-09-21 (run 325 /
    -- prefix 10265): RT-TXC-RTPRJ001 -> TXN_CONTROL_ID 100002642117705,
    -- RT-TXC-RTPRJ002 -> 100002642117706. The base table carries no project
    -- number, so join to PJF_PROJECTS_ALL_B for the prefix filter and the
    -- RECORD_KEY (PROJECT_NUMBER || '/TC/' || TXN_CTRL_REFERENCE), which
    -- matches the transform's RECON_KEY exactly. FUSION_ID = TXN_CONTROL_ID
    -- so the reconciler marks the TFM row LOADED with a real Fusion base id
    -- -- Rule #1 satisfied the same way every other object satisfies it.
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
    WHERE  :P_PREFIX IS NOT NULL
    AND    p.segment1 LIKE :P_PREFIX || '%'

    UNION ALL

    -- ---- TxnControls tier : INTERFACE (rejections left in staging) --
    -- Anything still sitting in the staging table after import is a
    -- rejection (the staging rows are emptied on success). Keyed by
    -- project number + control reference. The staging table carries no
    -- per-row error text, so return the '#IMPORT_REPORT#' marker and let
    -- the reconciler overlay the true Fusion message from the child report.
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
-- BIP, so treat NULL as "from the start": return every row. On later
-- pages P_AFTER_KEY carries the previous page's last RECORD_KEY and only
-- greater keys are returned. RECORD_KEY is compared as text.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
