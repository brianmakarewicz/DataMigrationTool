-- PACKAGE BODY DMT_PROJECT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PROJECT_RESULTS_PKG"
AS
-- ============================================================
-- DMT_PROJECT_RESULTS_PKG body
-- Projects post-load reconciliation — Contract v1, MULTI-TIER template.
--
-- Migrated 2026-09-20 to the proven multi-tier template (Requisitions PR #364 /
-- Workers DMT_WORKER_RESULTS_PKG). It reuses the ONE shared Contract v1 fetch,
-- DMT_RECON_CONTRACT_PKG.FETCH_ROWS. A single FETCH_ROWS call runs the Projects
-- Contract v1 report (nine columns, keyset paginated) over BIP and returns ALL
-- four tiers' rows in one collection; each row's OBJECT_TYPE says which tier it
-- belongs to.
--
-- The APPLY is STATIC SQL against the compile-time-known TFM tables (Option A,
-- owner decision on PR #248): one MERGE-style pair PER TIER, filtering the report
-- rows by OBJECT_TYPE and joining that tier's TFM table on RECON_KEY = RECORD_KEY.
--
--   Tier          OBJECT_TYPE literal   TFM table                       FUSION_ID column
--   -----------   -------------------   -----------------------------   ----------------------
--   Projects      'Projects'            DMT_PJF_PROJECTS_TFM_TBL        FUSION_PROJECT_ID
--   Tasks         'Tasks'               DMT_PJF_TASKS_TFM_TBL           FUSION_TASK_ID
--   TeamMembers   'TeamMembers'         DMT_PJF_TEAM_MEMBERS_TFM_TBL    FUSION_PROJECT_PARTY_ID
--                 (BASE = PJT_PROJECT_RESOURCE.PROJ_RESOURCE_ID)
--   TxnControls   'TxnControls'         DMT_PJC_TXN_CONTROLS_TFM_TBL    FUSION_TXN_CONTROL_ID
--
-- Per tier the rule is the shared Contract v1 apply rule:
--   * BASE / SUCCESS / FUSION_ID NOT NULL -> LOADED, stamp FUSION_ID.
--   * FUSION_STATUS = ERROR with a real ERROR_MESSAGE -> FAILED, message appended
--     as '[FUSION_ERROR] ' || message (never composed).
--   * Everything else is left GENERATED for the shared unaccounted sweep;
--     INTERFACE/SUCCESS corroborates but is never sufficient for LOADED.
--
-- #IMPORT_REPORT# HANDLING (Projects-specific):
--   The Projects interface tables carry NO error-text column, so the Contract v1
--   data model emits the LITERAL marker '#IMPORT_REPORT#' as ERROR_MESSAGE on
--   every ERROR (INTERFACE) row (DMT_PROJECT_RECON_DM.xdm, fixed in PR #334). The
--   marker is a wire-time signal, NOT a real Fusion error, so the per-tier apply
--   must NOT mark those rows FAILED with the marker. A tier row is only FAILED
--   here when FUSION_STATUS='ERROR' AND ERROR_MESSAGE IS NOT NULL AND
--   ERROR_MESSAGE != '#IMPORT_REPORT#'. Marker rows are left GENERATED for the
--   import-report harvest path (apply_import_report) which downloads the child
--   ImportProjectReportJob XML and overlays the true per-row Fusion message. That
--   harvest path is preserved unchanged in RECONCILE_BATCH.
--
-- The RECON_KEY on each tier's TFM row is stamped by DMT_PROJECT_TRANSFORM_PKG to
-- equal that tier's report RECORD_KEY (Projects = PROJECT_NUMBER; Tasks =
-- PROJECT_NUMBER||'/'||TASK_NUMBER; TeamMembers =
-- PROJECT_NAME||'/TM/'||TEAM_MEMBER_NAME; TxnControls =
-- PROJECT_NUMBER||'/TC/'||TXN_CTRL_REFERENCE). That coupling is what makes the
-- join hit.
--
-- Outcomes are written to the four TFM tables only; nothing is written back to
-- staging (the TFM row is the sole record of the Fusion outcome). NO COMMIT —
-- the orchestrator owns the transaction boundary.
--
-- REVISIONS:
--   2026-10-09  BM  Task and transaction-control own-row match (backlog #655): run
--                   349 proved their report rows are matched on '/' tokens, like
--                   team members.
--   2026-10-09  BM  Upward cross-grain propagation (backlog #545). Live run 343
--                   (prefix 93393, project RTPRJ-XG1) proved Import Projects
--                   rejects a valid project when one child fails: the report lists
--                   the team member's own error ("The specified resource doesn't
--                   exist.") and the project only with a pointer ("The project
--                   wasn't imported because import errors exist for the project
--                   team members."). A child's own error now goes to its project
--                   and to its siblings; the team-member report row is matched on
--                   its project-name and member-name tokens.
--   2026-10-08  BM  Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS, backlog
--                   #170): a rejected project's real error is quoted onto its
--                   tasks, team members and transaction controls.
--   2026-10-07  BM  Report V2 (DMT_PROJECT_RECON_V2_DM), owner-approved exception
--                   (design section 5): called once per work item with its own
--                   load id, import id and work-queue id. Base projects are found
--                   by PM_PROJECT_REFERENCE LIKE '<run_id>:<work_queue_id>:%' (the
--                   reference the transform stamps; Fusion stamps no job id on the
--                   project base tables); tasks, team members and transaction
--                   controls through their project; interface rows by
--                   LOAD_REQUEST_ID. Never by the run prefix.
-- ============================================================

    C_PKG    CONSTANT VARCHAR2(50) := 'DMT_PROJECT_RESULTS_PKG';
    C_CEMLI  CONSTANT VARCHAR2(30) := 'Projects';
    C_MARKER CONSTANT VARCHAR2(20) := '#IMPORT_REPORT#';

    -- Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS).
    -- Working set: "the project DOC_NUMBER / DOC_NAME was rejected with its own
    -- real Fusion error, so every task, team member and transaction control of
    -- that project must carry QUOTED_ERROR".
    TYPE T_DOC_PAIR IS RECORD (
        DOC_NUMBER   DMT_PJF_PROJECTS_TFM_TBL.PROJECT_NUMBER%TYPE,  -- the project
        DOC_NAME     DMT_PJF_PROJECTS_TFM_TBL.PROJECT_NAME%TYPE,    -- team members key on it
        SOURCE_KIND  VARCHAR2(10),     -- PROJECT / TASK / MEMBER / CONTROL: the grain that failed
        SOURCE_SEQ   NUMBER,           -- TFM_SEQUENCE_ID of the failed row (never quoted onto itself)
        QUOTED_ERROR VARCHAR2(4000)    -- DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(...)
    );
    TYPE T_DOC_PAIR_TBL IS TABLE OF T_DOC_PAIR;

    -- Per-tier base-table evidence, confirmed live against the demo pod 2026-09-21
    -- for run 325 / prefix 10265 (two loaded projects, ids 300000333828672 and
    -- 300000333828697):
    --   TxnControls  -> HAS a real, queryable Fusion base table. PJC_TRANSACTION_
    --                   CONTROLS holds one row per loaded control with a real id
    --                   (TXN_CONTROL_ID) and the source TXN_CTRL_REFERENCE, keyed
    --                   to the project via PROJECT_ID. Confirmed: RT-TXC-RTPRJ001
    --                   -> TXN_CONTROL_ID 100002642117705, RT-TXC-RTPRJ002 ->
    --                   100002642117706. The recon data model now emits a proper
    --                   BASE/SUCCESS row for this tier (see DMT_PROJECT_RECON_DM.xdm)
    --                   and the shared Contract v1 apply below marks it LOADED with
    --                   that real id -- Rule #1 satisfied exactly like every other
    --                   object. No import-report success harvest is needed.
    --   TeamMembers  -> HAS a real, queryable Fusion base table. PJT_PROJECT_RESOURCE
    --                   (Project Management team-member assignments) holds one row per
    --                   loaded member with a real id (PROJ_RESOURCE_ID), keyed to the
    --                   project via PROJECT_ID and to the person via RESOURCE_ID. The
    --                   earlier "no base table" claim only checked the FINANCIAL
    --                   project-parties view PJF_PROJECT_PARTIES, a different
    --                   representation that is empty for every DMT-migrated project;
    --                   PJT_PROJECT_RESOURCE is where Import Project actually persists
    --                   the accepted members. Confirmed live 2026-09-21 (run 327 /
    --                   prefix 10267): Alan Cook -> PROJ_RESOURCE_ID 300000333829040,
    --                   Mandy Steward -> 300000333829065. The recon data model now
    --                   emits a proper BASE/SUCCESS row for this tier (see
    --                   DMT_PROJECT_RECON_DM.xdm) and the shared Contract v1 apply
    --                   below marks it LOADED, stamping FUSION_PROJECT_PARTY_ID with
    --                   that real id -- Rule #1 satisfied exactly like every other
    --                   tier. No import-report success harvest is needed.

    -- --------------------------------------------------------
    -- Private: resolve the CHILD Import Projects report job id.
    --
    -- Fusion's ImportProjectJobDef (the "import" ESS job the loader passes as
    -- p_import_ess_id) is only an async submit wrapper. Its own ESS output is an
    -- essentially empty XML (~4 bytes). The real per-row accept/reject report
    -- lives in a SEPARATE child job, ImportProjectReportJob, which the wrapper
    -- spawns. Reading the wrapper always yields zero errors and leaves every
    -- rejected row unaccounted (run 234, "10115RT Project Bad-1").
    --
    -- The loader calls DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB before
    -- reconciliation; that resolves the child request id (via the seeded
    -- REPORT_JOB_DEF = 'ImportProjectReportJob') and stores it in DMT_ESS_JOB_TBL
    -- with PARENT_REQUEST_ID = the wrapper import id and JOB_SHORT_NAME /
    -- JOB_DEFINITION = 'ImportProjectReportJob'. This helper reads that persisted
    -- linkage back. Returns the child request id, or NULL if none was captured —
    -- in which case the caller must NOT invent a report: it downloads nothing and
    -- the affected rows stay unaccounted (never a fabricated FAILED).
    -- --------------------------------------------------------
    FUNCTION resolve_report_ess_id (
        p_run_id        IN NUMBER,
        p_import_ess_id IN NUMBER
    ) RETURN NUMBER IS
        l_report_id NUMBER;
    BEGIN
        IF p_import_ess_id IS NULL THEN
            RETURN NULL;
        END IF;

        BEGIN
            SELECT REQUEST_ID
            INTO   l_report_id
            FROM   DMT_ESS_JOB_TBL
            WHERE  PARENT_REQUEST_ID = p_import_ess_id
            AND    (RUN_ID = p_run_id OR RUN_ID IS NULL)
            AND    UPPER(NVL(JOB_SHORT_NAME, JOB_DEFINITION)) LIKE '%IMPORTPROJECTREPORTJOB%'
            AND    REQUEST_ID <> p_import_ess_id
            ORDER  BY REQUEST_ID DESC
            FETCH FIRST 1 ROW ONLY;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_report_id := NULL;
        END;

        -- If nothing was captured yet, capture it now — the reconcile path does
        -- NOT pre-capture the report child, so relying on a prior loader capture
        -- leaves every rejected row unaccounted (run 234/235 "RT Project Bad-1").
        -- This mirrors DMT_BILLING_EVENT_RESULTS_PKG and DMT_GRANTS_RESULTS_PKG,
        -- which capture the report child lazily inside their own reconcile.
        -- CAPTURE_REPORT_ESS_JOB is idempotent and returns the report request id
        -- (or NULL if this run genuinely produced no report, in which case the
        -- caller downloads nothing and rows stay unaccounted — never a fabricated
        -- FAILED).
        IF l_report_id IS NULL THEN
            l_report_id := DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB(
                p_run_id        => p_run_id,
                p_import_ess_id => p_import_ess_id,
                p_cemli_code    => C_CEMLI);
        END IF;

        RETURN l_report_id;
    END resolve_report_ess_id;

    -- --------------------------------------------------------
    -- Private: apply Import Report per-row errors to the four TFM tables, routing
    -- by error_source. Writes TFM only. This is the Projects import-report HARVEST
    -- path — the ONLY source of real per-row Fusion error text for this object
    -- (the interface tables have no error-text column; the Contract v1 report emits
    -- the '#IMPORT_REPORT#' marker in its place). It overlays the true message onto
    -- the marker rows that the Contract v1 apply left GENERATED.
    --
    -- p_import_ess_id is the WRAPPER import job. We first resolve the child
    -- ImportProjectReportJob (see resolve_report_ess_id) and download the report
    -- XML from THAT job — the wrapper's own XML is empty. If no child was captured,
    -- we do NOT fall back to the (empty) wrapper: there is no real report to read,
    -- so we match nothing and the rows stay GENERATED (unaccounted), never a
    -- fabricated FAILED.
    -- --------------------------------------------------------
    PROCEDURE apply_import_report (
        p_run_id        IN  NUMBER,
        p_import_ess_id IN  NUMBER,
        x_matched       OUT NUMBER
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'APPLY_IMPORT_REPORT';
        l_ir_errors DMT_IMPORT_REPORT_PKG.t_error_list;
        l_ir_xml    CLOB;
        l_src       VARCHAR2(100);
        l_report_id NUMBER;
    BEGIN
        x_matched := 0;
        IF p_import_ess_id IS NULL THEN
            RETURN;
        END IF;

        -- Resolve the child report job. If it was not captured, there is no real
        -- per-row report to read (the wrapper's XML is empty), so we stop here
        -- rather than reading the wrapper and finding "0 errors" — which would
        -- leave a genuine rejection unaccounted.
        l_report_id := resolve_report_ess_id(p_run_id, p_import_ess_id);

        IF l_report_id IS NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id  => p_run_id,
                p_message => C_PROC || ': No ImportProjectReportJob child captured for import ESS ' ||
                             p_import_ess_id || '. The wrapper job holds no per-row report; skipping'
                             || ' Import Report parse (rows left unaccounted, not fabricated FAILED).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RETURN;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ': Reading Import Projects report from child job ' || l_report_id ||
                         ' (wrapper import ESS ' || p_import_ess_id || ').',
            p_package   => C_PKG,
            p_procedure => C_PROC);

        BEGIN
            l_ir_xml := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(p_request_id => l_report_id, p_cemli_code => C_CEMLI);
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(
                    p_run_id  => p_run_id,
                    p_message => C_PROC || ': Failed to download ESS output XML for report request ' ||
                                 l_report_id || ': ' || SQLERRM,
                    p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                    p_package   => C_PKG,
                    p_procedure => C_PROC);
                l_ir_xml := NULL;
        END;

        IF l_ir_xml IS NULL OR DBMS_LOB.GETLENGTH(l_ir_xml) = 0 THEN
            RETURN;
        END IF;

        l_ir_errors := DMT_IMPORT_REPORT_PKG.PARSE_ERRORS(l_ir_xml);

        FOR i IN 1 .. l_ir_errors.COUNT LOOP
            IF l_ir_errors(i).row_identifier IS NULL THEN
                CONTINUE;
            END IF;

            l_src := UPPER(NVL(l_ir_errors(i).error_source, ''));

            -- Static UPDATEs, one per error_source. Each branch keeps its own
            -- static match predicate (compound child/parent key, or the project
            -- INSTR token match) — no dynamic SQL. ERROR_TEXT is built by the
            -- shared ERROR_TEXT_FOR helper, which returns the REAL Fusion
            -- message or NULL (never an invented default). The FAILED UPDATE is
            -- guarded on l_ir_errors(i).error_message IS NOT NULL so a report
            -- error row with no real message does NOT fabricate a verdict — the
            -- TFM row is left GENERATED for the honest unaccounted sweep.
            IF l_ir_errors(i).error_message IS NULL THEN
                CONTINUE;
            END IF;

            IF l_src LIKE '%TASK%' THEN
                UPDATE DMT_PJF_TASKS_TFM_TBL
                SET    TFM_STATUS = 'FAILED',
                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           DMT_IMPORT_REPORT_PKG.ERROR_TEXT_FOR(l_ir_errors(i).error_message)),
                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                AND    (TASK_NAME = l_ir_errors(i).row_identifier
                        OR PROJECT_NUMBER || '/' || TASK_NAME = l_ir_errors(i).row_identifier
                        -- LIST_TASK_ERROR row (run 349): the parser joins
                        -- TERROR_PROJECT_NAME, TERROR_PROJECT_NUMBER, ERROR_TASK_NUMBER,
                        -- ERROR_TASK_NAME with '/', empty ones included
                        -- ("<project name>//<task number>/<task name>"), so match the
                        -- task number and the project name or number as '/' tokens.
                        OR (INSTR('/' || l_ir_errors(i).row_identifier || '/',
                                  '/' || TASK_NUMBER || '/') > 0
                            AND (INSTR('/' || l_ir_errors(i).row_identifier || '/',
                                       '/' || PROJECT_NAME || '/') > 0
                                 OR INSTR('/' || l_ir_errors(i).row_identifier || '/',
                                          '/' || PROJECT_NUMBER || '/') > 0)));
                x_matched := x_matched + SQL%ROWCOUNT;

            ELSIF l_src LIKE '%TEAM%' OR l_src LIKE '%PART%' OR l_src LIKE '%MEMBER%' THEN
                UPDATE DMT_PJF_TEAM_MEMBERS_TFM_TBL
                SET    TFM_STATUS = 'FAILED',
                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           DMT_IMPORT_REPORT_PKG.ERROR_TEXT_FOR(l_ir_errors(i).error_message)),
                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                AND    (TEAM_MEMBER_NAME = l_ir_errors(i).row_identifier
                        OR PROJECT_NAME || '/' || TEAM_MEMBER_NAME = l_ir_errors(i).row_identifier
                        -- LIST_TEAM_MEMBER_ERROR row (run 343): the parser joins
                        -- TM_ERROR_PROJECT_NAME, _PROJECT_NUMBER, _TM_NAME, _TM_NUMBER
                        -- with '/', empty ones included ("<project>//<member>/"), so
                        -- match the project name and member name as '/' tokens.
                        OR (INSTR('/' || l_ir_errors(i).row_identifier || '/',
                                  '/' || PROJECT_NAME || '/') > 0
                            AND INSTR('/' || l_ir_errors(i).row_identifier || '/',
                                      '/' || TEAM_MEMBER_NAME || '/') > 0));
                x_matched := x_matched + SQL%ROWCOUNT;

            ELSIF l_src LIKE '%TXN%' OR l_src LIKE '%CONTROL%' THEN
                UPDATE DMT_PJC_TXN_CONTROLS_TFM_TBL
                SET    TFM_STATUS = 'FAILED',
                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           DMT_IMPORT_REPORT_PKG.ERROR_TEXT_FOR(l_ir_errors(i).error_message)),
                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                AND    (TXN_CTRL_REFERENCE = l_ir_errors(i).row_identifier
                        OR PROJECT_NUMBER || '/' || TXN_CTRL_REFERENCE = l_ir_errors(i).row_identifier
                        -- LIST_TXN_CTRL_ERROR row (run 349): the parser joins
                        -- TC_ERR_PROJECT_NAME, _PROJECT_NUMBER, _TASK_NAME, _TASK_NUMBER,
                        -- _SOURCE_REFERENCE with '/', empty ones included
                        -- ("<project name>////<reference>"), so match the control
                        -- reference and the project name or number as '/' tokens.
                        OR (INSTR('/' || l_ir_errors(i).row_identifier || '/',
                                  '/' || TXN_CTRL_REFERENCE || '/') > 0
                            AND (INSTR('/' || l_ir_errors(i).row_identifier || '/',
                                       '/' || PROJECT_NAME || '/') > 0
                                 OR INSTR('/' || l_ir_errors(i).row_identifier || '/',
                                          '/' || PROJECT_NUMBER || '/') > 0)));
                x_matched := x_matched + SQL%ROWCOUNT;

            ELSE
                -- The report's per-project identifier can be a composite of the
                -- project name and number joined by '/' (ImportProjectReportDm emits
                -- ERROR_PROJECT_NAME then ERROR_PROJECT_NUMBER, and the generic parser
                -- concatenates the identifier-like fields). Match the exact value OR
                -- the project number as a '/'-delimited token inside it, so
                -- "10118RT Project Bad-1/10118RTPRJ-BAD1" still resolves to the row
                -- keyed 10118RTPRJ-BAD1 (and never to the good projects).
                UPDATE DMT_PJF_PROJECTS_TFM_TBL
                SET    TFM_STATUS = 'FAILED',
                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           DMT_IMPORT_REPORT_PKG.ERROR_TEXT_FOR(l_ir_errors(i).error_message, 'Import error')),
                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                AND    (PROJECT_NUMBER = l_ir_errors(i).row_identifier
                        OR INSTR('/' || l_ir_errors(i).row_identifier || '/',
                                 '/' || PROJECT_NUMBER || '/') > 0);
                x_matched := x_matched + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ': Import Report parsed: ' || l_ir_errors.COUNT ||
                         ' errors, ' || x_matched || ' matched to TFM rows.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

        IF l_ir_xml IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_ir_xml) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_ir_xml);
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            -- A malformed Import Report (PARSE_ERRORS throws) must NOT abort
            -- reconciliation: log a WARN and return what we matched. Unmatched
            -- GENERATED rows are left for the honest unaccounted sweep.
            IF l_ir_xml IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_ir_xml) = 1 THEN
                DBMS_LOB.FREETEMPORARY(l_ir_xml);
            END IF;
            DMT_UTIL_PKG.LOG(
                p_run_id  => p_run_id,
                p_message => C_PROC || ': Import Report parse/apply failed (' || SQLERRM ||
                             '); ' || x_matched || ' rows matched before the error.',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
    END apply_import_report;

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_PROJECTS (private)
    -- The Contract v1 apply for all four Projects tiers, Option A shape. One
    -- shared FETCH_ROWS call returns every tier's rows; the apply is STATIC SQL,
    -- one pair of UPDATEs per tier, discriminated by OBJECT_TYPE and joined on
    -- RECON_KEY = RECORD_KEY.
    --
    -- CRITICAL: the FAILED branch is guarded on ERROR_MESSAGE != '#IMPORT_REPORT#'
    -- so the Projects import-report marker rows are LEFT GENERATED for the
    -- apply_import_report harvest path (which supplies the real Fusion text). They
    -- are never marked FAILED carrying the marker.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_PROJECTS (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER,
        p_work_queue_id IN NUMBER
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_PROJECTS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_prj_loaded NUMBER := 0;  l_prj_failed NUMBER := 0;
        l_tsk_loaded NUMBER := 0;  l_tsk_failed NUMBER := 0;
        l_tm_loaded  NUMBER := 0;  l_tm_failed  NUMBER := 0;
        l_tc_loaded  NUMBER := 0;  l_tc_failed  NUMBER := 0;
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
    BEGIN
        -- Generated-row count across all four tiers drives the shared fetch's
        -- keyset page-count cap. Done statically here (not in the shared pkg).
        SELECT (SELECT COUNT(*) FROM DMT_PJF_PROJECTS_TFM_TBL     WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_PJF_TASKS_TFM_TBL        WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_PJF_TEAM_MEMBERS_TFM_TBL WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_PJC_TXN_CONTROLS_TFM_TBL WHERE RUN_ID = p_run_id)
        INTO   l_gen_count
        FROM   dual;

        -- Report V2 finds this work item's rows only: base projects by the
        -- reference the transform stamped ('<run_id>:<work_queue_id>:...', the
        -- owner-approved exception -- Fusion stamps no job id on the project base
        -- tables), the other base tiers through their project, interface rows by
        -- the load job's LOAD_REQUEST_ID. P_WQ_ID is sent for Projects only.
        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code    => C_CEMLI,
            p_run_id        => p_run_id,
            p_load_ess_id   => p_load_ess_id,
            p_import_ess_id => p_import_ess_id,
            p_row_cap       => l_gen_count,
            x_rows          => l_rows,
            x_error_code    => l_err_code,
            p_work_queue_id => p_work_queue_id);

        -- A transport / SOAP failure raises loudly (design section 5: never a
        -- silent retry, never a zero-row "success"); the fetch already logged detail.
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20094,
                C_PROC || ': Contract v1 fetch failed for Projects '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the import-report harvest + unaccounted
            -- sweep in RECONCILE_BATCH.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': Projects recon report returned zero rows; '
                               || 'GENERATED rows left for the import-report harvest '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            -- Backlog #65 three-tier match (owner order on PR #481). Tier 1 is the
            -- stamped recon key (RECON_KEY = RECORD_KEY, exactly as before). Tier 2
            -- (the Slot C DFF stamp: TFM_SEQUENCE_ID = the trailing numeric segment of
            -- DFF_KEY) is kept uniform with the shared template; Projects' DMT_REFERENCE
            -- is the composite record-key string, not a numeric carrier, so tier 2 is
            -- normally a no-op. There is NO tier 3 for the Projects tiers: the Projects
            -- recon DM returns SOURCE_REF (the business key) IDENTICAL to RECORD_KEY (the
            -- composite PROJECT_NUMBER / PROJECT_NUMBER '/' TASK_NUMBER / PROJECT_NAME
            -- '/TM/' member / PROJECT_NUMBER '/TC/' ref), and no distinct single
            -- source-business-key column exists on these TFM tables, so a tier-3
            -- fall-through would be byte-redundant with tier 1. Every tier-1 hit
            -- short-circuits, so loaded outcomes are identical to before. Static UPDATEs.
            FOR i IN 1 .. l_rows.COUNT LOOP
                l_rc   := 0;     -- backlog #65: reset per row so a prior row's tier
                l_tier := NULL;  -- cannot mislabel this row's audit log line.
                -- ===== TIER: PROJECTS (OBJECT_TYPE = 'Projects') =====
                IF l_rows(i).OBJECT_TYPE = 'Projects' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_PJF_PROJECTS_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_PROJECT_ID    = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;
                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_PJF_PROJECTS_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_PROJECT_ID    = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;
                        l_prj_loaded := l_prj_loaded + l_rc;
                        IF l_tier = 'TIER2' THEN
                            DMT_UTIL_PKG.LOG(p_run_id, C_PROC
                                || ': matched a LOADED project via TIER2 fallback '
                                || '(tier 1 stamped key did not resolve). PROJECT_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                          AND l_rows(i).ERROR_MESSAGE != C_MARKER THEN
                        UPDATE DMT_PJF_PROJECTS_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_prj_failed := l_prj_failed + SQL%ROWCOUNT;
                    END IF;
                    -- ERROR + '#IMPORT_REPORT#' marker: left GENERATED for the
                    -- import-report harvest path (which supplies the real text).

                -- ===== TIER: TASKS (OBJECT_TYPE = 'Tasks') =====
                ELSIF l_rows(i).OBJECT_TYPE = 'Tasks' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_PJF_TASKS_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_TASK_ID       = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;
                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_PJF_TASKS_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_TASK_ID       = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;
                        l_tsk_loaded := l_tsk_loaded + l_rc;
                        IF l_tier = 'TIER2' THEN
                            DMT_UTIL_PKG.LOG(p_run_id, C_PROC
                                || ': matched a LOADED task via TIER2 fallback '
                                || '(tier 1 stamped key did not resolve). TASK_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                          AND l_rows(i).ERROR_MESSAGE != C_MARKER THEN
                        UPDATE DMT_PJF_TASKS_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_tsk_failed := l_tsk_failed + SQL%ROWCOUNT;
                    END IF;

                -- ===== TIER: TEAM MEMBERS (OBJECT_TYPE = 'TeamMembers') =====
                ELSIF l_rows(i).OBJECT_TYPE = 'TeamMembers' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_PJF_TEAM_MEMBERS_TFM_TBL
                        SET    TFM_STATUS              = 'LOADED',
                               FUSION_PROJECT_PARTY_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE    = SYSDATE,
                               LAST_UPDATED_DATE       = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;
                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_PJF_TEAM_MEMBERS_TFM_TBL
                                SET    TFM_STATUS              = 'LOADED',
                                       FUSION_PROJECT_PARTY_ID = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE    = SYSDATE,
                                       LAST_UPDATED_DATE       = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;
                        l_tm_loaded := l_tm_loaded + l_rc;
                        IF l_tier = 'TIER2' THEN
                            DMT_UTIL_PKG.LOG(p_run_id, C_PROC
                                || ': matched a LOADED team member via TIER2 fallback '
                                || '(tier 1 stamped key did not resolve). PROJECT_PARTY_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                          AND l_rows(i).ERROR_MESSAGE != C_MARKER THEN
                        UPDATE DMT_PJF_TEAM_MEMBERS_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_tm_failed := l_tm_failed + SQL%ROWCOUNT;
                    END IF;

                -- ===== TIER: TXN CONTROLS (OBJECT_TYPE = 'TxnControls') =====
                ELSIF l_rows(i).OBJECT_TYPE = 'TxnControls' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_PJC_TXN_CONTROLS_TFM_TBL
                        SET    TFM_STATUS            = 'LOADED',
                               FUSION_TXN_CONTROL_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE  = SYSDATE,
                               LAST_UPDATED_DATE     = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;
                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_PJC_TXN_CONTROLS_TFM_TBL
                                SET    TFM_STATUS            = 'LOADED',
                                       FUSION_TXN_CONTROL_ID = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE  = SYSDATE,
                                       LAST_UPDATED_DATE     = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;
                        l_tc_loaded := l_tc_loaded + l_rc;
                        IF l_tier = 'TIER2' THEN
                            DMT_UTIL_PKG.LOG(p_run_id, C_PROC
                                || ': matched a LOADED txn control via TIER2 fallback '
                                || '(tier 1 stamped key did not resolve). TXN_CONTROL_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                          AND l_rows(i).ERROR_MESSAGE != C_MARKER THEN
                        UPDATE DMT_PJC_TXN_CONTROLS_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_tc_failed := l_tc_failed + SQL%ROWCOUNT;
                    END IF;
                END IF;
            END LOOP;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | Projects LOADED/FAILED: ' || l_prj_loaded || '/' || l_prj_failed
                           || ' | Tasks LOADED/FAILED: '    || l_tsk_loaded || '/' || l_tsk_failed
                           || ' | TeamMembers LOADED/FAILED: ' || l_tm_loaded || '/' || l_tm_failed
                           || ' | TxnControls LOADED/FAILED: ' || l_tc_loaded || '/' || l_tc_failed
                           || '. Marker/unmatched rows left for the import-report harvest.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END APPLY_CONTRACT_V1_PROJECTS;

    -- --------------------------------------------------------
    -- PROPAGATE_DOCUMENT_ERRORS (private)
    -- Design section 5, "Whole-document rejection carries the real error to every
    -- grain" (decided 2026-10-07). The Fusion document is the project: when
    -- Import Projects rejects a project, its tasks, team members and transaction
    -- controls are rejected with it, but the import report writes the error only
    -- under the project (backlog #170, docs/findings/cross_grain_conformance_review.md).
    -- The children come back from the recon report only as INTERFACE rows carrying
    -- the '#IMPORT_REPORT#' marker, which the apply skips, so without this step
    -- they stay GENERATED and the shared sweep marks them UNACCOUNTED.
    --
    -- Direction: both ways (backlog #545). Live run 343 proved Import Projects
    -- rejects a valid project when one of its children fails, and names the child
    -- with its own error while the project gets only a pointer ("The project
    -- wasn't imported because import errors exist for the project team members.").
    --
    -- Sources: rows of this run and work item with TFM_STATUS = 'FAILED' carrying
    --   their OWN real Fusion error -- ERROR_TEXT contains '[FUSION_ERROR] '
    --   (Contract v1 apply) or '[IMPORT_REPORT] ' (the import-report harvest) and
    --   does NOT contain C_DOC_ERROR_MARKER (a quote is never re-quoted):
    --   * a task, team member or transaction control (the child that caused the
    --     rejection): its error is quoted onto its project and onto the project's
    --     other children, naming the child, e.g. "project <number> (team member
    --     <name>): <message>";
    --   * a project, only when none of its children carries an own error: then the
    --     project's error is the cause and is quoted onto its children. When a child
    --     failed, the project's own report text is only the pointer to it, so the
    --     child's error is the one quoted.
    -- Targets: every task / transaction control of the same project (PROJECT_NUMBER;
    --   PROJECT_NAME when the child carries no number) and every team member of the
    --   same project (PROJECT_NAME -- team members carry no project number) that
    --   Fusion received (FBDI_CSV_ID stamped at generation, not STAGED), is not
    --   LOADED (LOADED rows are never touched) and does not already carry the exact
    --   quote. The quote is appended (APPEND_ERROR, never overwrite) and the row
    --   set FAILED. A project with no own error is untouched -- its children fall
    --   to the shared UNACCOUNTED sweep.
    -- Idempotent: the "already carries the exact quote" guard means a second
    --   reconcile pass adds nothing.
    -- One collection of (project, quote) pairs is built by ONE static SELECT, then
    -- ONE static bulk UPDATE (FORALL) per target table: a MERGE cannot read a
    -- PL/SQL record collection through TABLE() (ORA-00902, AR run 248). NO dynamic
    -- SQL; NO COMMIT (caller owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PROPAGATE_DOCUMENT_ERRORS (
        p_run_id        IN NUMBER,
        p_work_queue_id IN NUMBER
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'PROPAGATE_DOCUMENT_ERRORS';
        -- The two tags a project's own real Fusion error is written with.
        C_TAG_RX   CONSTANT VARCHAR2(40) := '\[(FUSION_ERROR|IMPORT_REPORT)\] ';
        l_marker   VARCHAR2(30) := DMT_UTIL_PKG.C_DOC_ERROR_MARKER;
        l_pairs    T_DOC_PAIR_TBL;
        l_projects NUMBER := 0;
        l_tasks    NUMBER := 0;
        l_members  NUMBER := 0;
        l_controls NUMBER := 0;
        l_step     VARCHAR2(200);
    BEGIN
        l_step := 'collecting rejected-project (source, quote) pairs for run ' || p_run_id;
        -- The quoted message is the source's own error from its first real tag on,
        -- with that leading tag removed (FORMAT_DOCUMENT_ERROR adds its own).
        -- Work-item scope everywhere, as the shared sweep scopes it: rows stamped
        -- with another work item are excluded; unstamped rows are run-scoped.
        WITH own_err AS (
            -- children failed with their OWN real error, keyed to their project
            SELECT 'TASK' AS KIND, t.TFM_SEQUENCE_ID AS SEQ,
                   t.PROJECT_NUMBER AS DOC_NUMBER, t.PROJECT_NAME AS DOC_NAME,
                   'task ' || t.TASK_NUMBER AS GRAIN_KEY, t.ERROR_TEXT
            FROM   DMT_PJF_TASKS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
            AND    t.TFM_STATUS = 'FAILED'
            AND    REGEXP_INSTR(t.ERROR_TEXT, C_TAG_RX) > 0
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0
            UNION ALL
            -- team members carry no project number: take it from the project row
            SELECT 'MEMBER', m.TFM_SEQUENCE_ID,
                   (SELECT MAX(p.PROJECT_NUMBER) FROM DMT_PJF_PROJECTS_TFM_TBL p
                    WHERE  p.RUN_ID = m.RUN_ID AND p.PROJECT_NAME = m.PROJECT_NAME),
                   m.PROJECT_NAME,
                   'team member ' || m.TEAM_MEMBER_NAME, m.ERROR_TEXT
            FROM   DMT_PJF_TEAM_MEMBERS_TFM_TBL m
            WHERE  m.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR m.WORK_QUEUE_ID IS NULL
                    OR m.WORK_QUEUE_ID = p_work_queue_id)
            AND    m.TFM_STATUS = 'FAILED'
            AND    REGEXP_INSTR(m.ERROR_TEXT, C_TAG_RX) > 0
            AND    DBMS_LOB.INSTR(m.ERROR_TEXT, l_marker) = 0
            UNION ALL
            SELECT 'CONTROL', c.TFM_SEQUENCE_ID,
                   c.PROJECT_NUMBER, c.PROJECT_NAME,
                   'transaction control ' || c.TXN_CTRL_REFERENCE, c.ERROR_TEXT
            FROM   DMT_PJC_TXN_CONTROLS_TFM_TBL c
            WHERE  c.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR c.WORK_QUEUE_ID IS NULL
                    OR c.WORK_QUEUE_ID = p_work_queue_id)
            AND    c.TFM_STATUS = 'FAILED'
            AND    REGEXP_INSTR(c.ERROR_TEXT, C_TAG_RX) > 0
            AND    DBMS_LOB.INSTR(c.ERROR_TEXT, l_marker) = 0
        )
        SELECT e.DOC_NUMBER,
               e.DOC_NAME,
               e.KIND,
               e.SEQ,
               DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                   'project', e.DOC_NUMBER || ' (' || e.GRAIN_KEY || ')',
                   REGEXP_REPLACE(
                       DBMS_LOB.SUBSTR(e.ERROR_TEXT, 3800, REGEXP_INSTR(e.ERROR_TEXT, C_TAG_RX)),
                       '^' || C_TAG_RX))
        BULK COLLECT INTO l_pairs
        FROM   own_err e
        WHERE  e.DOC_NUMBER IS NOT NULL
        UNION ALL
        SELECT p.PROJECT_NUMBER,
               p.PROJECT_NAME,
               'PROJECT',
               p.TFM_SEQUENCE_ID,
               DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                   'project', p.PROJECT_NUMBER,
                   REGEXP_REPLACE(
                       DBMS_LOB.SUBSTR(p.ERROR_TEXT, 3800, REGEXP_INSTR(p.ERROR_TEXT, C_TAG_RX)),
                       '^' || C_TAG_RX))
        FROM   DMT_PJF_PROJECTS_TFM_TBL p
        WHERE  p.RUN_ID = p_run_id
        AND    (p_work_queue_id IS NULL OR p.WORK_QUEUE_ID IS NULL
                OR p.WORK_QUEUE_ID = p_work_queue_id)
        AND    p.TFM_STATUS = 'FAILED'
        AND    REGEXP_INSTR(p.ERROR_TEXT, C_TAG_RX) > 0
        AND    DBMS_LOB.INSTR(p.ERROR_TEXT, l_marker) = 0
        AND    p.PROJECT_NUMBER IS NOT NULL
        -- a failed child is the cause; the project's own text is then a pointer
        AND    NOT EXISTS (SELECT 1 FROM own_err e
                           WHERE  e.DOC_NUMBER = p.PROJECT_NUMBER
                           OR     e.DOC_NAME   = p.PROJECT_NAME);

        -- One bulk UPDATE per child table (FORALL over the pairs). Each pair
        -- appends its quote only when the row does not already carry it, so a
        -- second reconcile pass adds nothing.
        -- The project a failed child brought down carries that child's error.
        l_step := 'appending quoted child errors to their projects';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_PJF_PROJECTS_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
            AND    l_pairs(i).SOURCE_KIND <> 'PROJECT'
            AND    t.PROJECT_NUMBER = l_pairs(i).DOC_NUMBER
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_projects := SQL%ROWCOUNT;

        l_step := 'appending quoted project errors to tasks';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_PJF_TASKS_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
            AND    (t.PROJECT_NUMBER = l_pairs(i).DOC_NUMBER
                    OR (t.PROJECT_NUMBER IS NULL AND t.PROJECT_NAME = l_pairs(i).DOC_NAME))
            AND    NOT (l_pairs(i).SOURCE_KIND = 'TASK'
                        AND t.TFM_SEQUENCE_ID = l_pairs(i).SOURCE_SEQ)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_tasks := SQL%ROWCOUNT;

        l_step := 'appending quoted project errors to team members';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_PJF_TEAM_MEMBERS_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
            AND    t.PROJECT_NAME = l_pairs(i).DOC_NAME
            AND    NOT (l_pairs(i).SOURCE_KIND = 'MEMBER'
                        AND t.TFM_SEQUENCE_ID = l_pairs(i).SOURCE_SEQ)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_members := SQL%ROWCOUNT;

        l_step := 'appending quoted project errors to transaction controls';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_PJC_TXN_CONTROLS_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
            AND    (t.PROJECT_NUMBER = l_pairs(i).DOC_NUMBER
                    OR (t.PROJECT_NUMBER IS NULL AND t.PROJECT_NAME = l_pairs(i).DOC_NAME))
            AND    NOT (l_pairs(i).SOURCE_KIND = 'CONTROL'
                        AND t.TFM_SEQUENCE_ID = l_pairs(i).SOURCE_SEQ)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_controls := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rejection sources: ' || l_pairs.COUNT
                           || ' | rows given a quoted document error: projects ' || l_projects
                           || ', tasks ' || l_tasks
                           || ', team members ' || l_members
                           || ', transaction controls ' || l_controls || '.',
            p_package   => C_PKG,
            p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed while ' || l_step || '.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END PROPAGATE_DOCUMENT_ERRORS;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH — entry point (signature unchanged). Calls the shared
    -- Contract v1 apply, then runs the Projects import-report harvest to overlay
    -- the real per-row Fusion error text onto the '#IMPORT_REPORT#' marker rows
    -- the apply left GENERATED (the interface tables carry no error-text column,
    -- so this harvest is the ONLY source of real per-row error detail). The
    -- report is called once for ONE work item, with that item's own load id,
    -- import id and work-queue id; the run prefix is never a search value.
    -- The work-queue id is p_work_queue_id when the queue passes it (the async
    -- reconcile and the reconcile-only rerun always do), else the id of the work
    -- item running now (DMT_LOADER_PKG.g_gen_queue_id, the same value the
    -- transform stamped into the source reference on the inline path).
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id         IN NUMBER,
        p_load_ess_id    IN NUMBER,
        p_import_ess_id  IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
        l_ir_matched NUMBER := 0;
        l_still_gen  NUMBER := 0;
        l_wq_id      NUMBER := NVL(p_work_queue_id, DMT_LOADER_PKG.g_gen_queue_id);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' start. load_ess_id: ' || p_load_ess_id ||
                         ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL') ||
                         ' | work_queue_id: ' || NVL(TO_CHAR(l_wq_id), 'NULL'),
            p_package   => C_PKG,
            p_procedure => C_PROC);

        -- Contract v1 fetch + per-tier apply: BASE/SUCCESS rows -> LOADED (stamp
        -- FUSION_ID); real Fusion ERROR rows -> FAILED. The '#IMPORT_REPORT#'
        -- marker rows are intentionally left GENERATED.
        APPLY_CONTRACT_V1_PROJECTS(
            p_run_id        => p_run_id,
            p_load_ess_id   => p_load_ess_id,
            p_import_ess_id => p_import_ess_id,
            p_work_queue_id => l_wq_id);

        -- Import-report harvest: overlay the real per-row Fusion message onto the
        -- marker rows (and any other still-GENERATED row) from the child
        -- ImportProjectReportJob XML. This is the ONLY source of real per-row error
        -- text for Projects. Run whenever rows remain GENERATED and an import ESS
        -- id is available.
        SELECT (SELECT COUNT(*) FROM DMT_PJF_PROJECTS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED')
             + (SELECT COUNT(*) FROM DMT_PJF_TASKS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED')
             + (SELECT COUNT(*) FROM DMT_PJF_TEAM_MEMBERS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED')
             + (SELECT COUNT(*) FROM DMT_PJC_TXN_CONTROLS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED')
        INTO l_still_gen FROM DUAL;

        IF l_still_gen > 0 AND p_import_ess_id IS NOT NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id  => p_run_id,
                p_message => C_PROC || ': ' || l_still_gen ||
                             ' rows still GENERATED after the Contract v1 apply. Running Import'
                             || ' Report harvest (ESS ' || p_import_ess_id || ').',
                p_package   => C_PKG,
                p_procedure => C_PROC);
            apply_import_report(p_run_id, p_import_ess_id, l_ir_matched);
        END IF;

        -- Whole-document rejection (design section 5): the tasks, team members
        -- and transaction controls of a project Import Projects rejected carry the
        -- project's real error. Runs after the per-row apply and the import-report
        -- harvest and BEFORE the shared unaccounted sweep
        -- (DMT_QUEUE_WORKER_PKG.RECONCILE_ONE). Backlog #170.
        PROPAGATE_DOCUMENT_ERRORS(p_run_id, l_wq_id);

        -- TxnControls now reconcile through the shared Contract v1 apply above: the
        -- recon data model emits a real BASE/SUCCESS row over PJC_TRANSACTION_CONTROLS
        -- (id TXN_CONTROL_ID), so the apply stamps FUSION_TXN_CONTROL_ID and marks the
        -- row LOADED against a real Fusion base row -- the same Rule #1 path every
        -- other object uses. The former import-report SUCCESS harvest for this tier is
        -- removed (it invented a LOADED with no base id and was blocked in review).
        --
        -- TeamMembers now reconcile through the shared Contract v1 apply above too:
        -- the recon data model emits a real BASE/SUCCESS row over PJT_PROJECT_RESOURCE
        -- (id PROJ_RESOURCE_ID), so the apply stamps FUSION_PROJECT_PARTY_ID and marks
        -- the row LOADED against a real Fusion base row -- the same Rule #1 path every
        -- other tier uses. The earlier "no base table" claim only checked the FINANCIAL
        -- project-parties view PJF_PROJECT_PARTIES (empty for every DMT project);
        -- PJT_PROJECT_RESOURCE is where Import Project actually persists the members.

        -- Unresolved records are intentionally left GENERATED (unaccounted). No
        -- fabricated FAILED: the accounting gate reports the object not-DONE and
        -- the funnel surfaces these as UNRECONCILED. NO COMMIT — the orchestrator
        -- owns the transaction boundary.

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' complete. IR_MATCHED: ' || l_ir_matched || '.',
            p_package   => C_PKG,
            p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id  => p_run_id,
                p_message => C_PROC || ' failed.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END RECONCILE_BATCH;


    -- --------------------------------------------------------
    -- RESET_UNACCOUNTED (backlog #95) -- see spec. Static UPDATE(s) over the
    -- compile-time-known Projects TFM table(s). Flips this run's UNACCOUNTED rows
    -- back to GENERATED and strips the trailing [UNACCOUNTED] tag from ERROR_TEXT
    -- (CLOB-safe REGEXP_REPLACE -- plain REPLACE raises ORA-22849), preserving any
    -- prior real error. Scoped by run, and by work-queue item when given. NO
    -- dynamic SQL; NO COMMIT.
    -- --------------------------------------------------------
    PROCEDURE RESET_UNACCOUNTED (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER   DEFAULT NULL,
        p_import_ess_id IN NUMBER   DEFAULT NULL,
        p_work_queue_id IN NUMBER   DEFAULT NULL
    ) IS
        C_PROC  CONSTANT VARCHAR2(30) := 'RESET_UNACCOUNTED';
        l_reset NUMBER := 0;
    BEGIN
        UPDATE DMT_PJF_PROJECTS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_PJF_TASKS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_PJF_TEAM_MEMBERS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_PJC_TXN_CONTROLS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED Projects row(s) to GENERATED '
            || 'for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT -- the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_PROJECT_RESULTS_PKG;
/
