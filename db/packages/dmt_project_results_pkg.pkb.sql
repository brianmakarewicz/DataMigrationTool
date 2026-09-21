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
-- ============================================================

    C_PKG    CONSTANT VARCHAR2(50) := 'DMT_PROJECT_RESULTS_PKG';
    C_CEMLI  CONSTANT VARCHAR2(30) := 'Projects';
    C_MARKER CONSTANT VARCHAR2(20) := '#IMPORT_REPORT#';

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
            l_ir_xml := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(l_report_id);
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
            -- INSTR token match) — no dynamic SQL. The composed [IMPORT_REPORT]
            -- message is built by the shared ERROR_TEXT_FOR helper with the
            -- Project default literal 'Import error'.
            IF l_src LIKE '%TASK%' THEN
                UPDATE DMT_PJF_TASKS_TFM_TBL
                SET    TFM_STATUS = 'FAILED',
                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           DMT_IMPORT_REPORT_PKG.ERROR_TEXT_FOR(l_ir_errors(i).error_message, 'Import error')),
                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                AND    (TASK_NAME = l_ir_errors(i).row_identifier
                        OR PROJECT_NUMBER || '/' || TASK_NAME = l_ir_errors(i).row_identifier);
                x_matched := x_matched + SQL%ROWCOUNT;

            ELSIF l_src LIKE '%TEAM%' OR l_src LIKE '%PART%' OR l_src LIKE '%MEMBER%' THEN
                UPDATE DMT_PJF_TEAM_MEMBERS_TFM_TBL
                SET    TFM_STATUS = 'FAILED',
                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           DMT_IMPORT_REPORT_PKG.ERROR_TEXT_FOR(l_ir_errors(i).error_message, 'Import error')),
                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                AND    (TEAM_MEMBER_NAME = l_ir_errors(i).row_identifier
                        OR PROJECT_NAME || '/' || TEAM_MEMBER_NAME = l_ir_errors(i).row_identifier);
                x_matched := x_matched + SQL%ROWCOUNT;

            ELSIF l_src LIKE '%TXN%' OR l_src LIKE '%CONTROL%' THEN
                UPDATE DMT_PJC_TXN_CONTROLS_TFM_TBL
                SET    TFM_STATUS = 'FAILED',
                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           DMT_IMPORT_REPORT_PKG.ERROR_TEXT_FOR(l_ir_errors(i).error_message, 'Import error')),
                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                AND    (TXN_CTRL_REFERENCE = l_ir_errors(i).row_identifier
                        OR PROJECT_NUMBER || '/' || TXN_CTRL_REFERENCE = l_ir_errors(i).row_identifier);
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
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_PROJECTS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_prj_loaded NUMBER := 0;  l_prj_failed NUMBER := 0;
        l_tsk_loaded NUMBER := 0;  l_tsk_failed NUMBER := 0;
        l_tm_loaded  NUMBER := 0;  l_tm_failed  NUMBER := 0;
        l_tc_loaded  NUMBER := 0;  l_tc_failed  NUMBER := 0;
    BEGIN
        -- Generated-row count across all four tiers drives the shared fetch's
        -- keyset page-count cap. Done statically here (not in the shared pkg).
        SELECT (SELECT COUNT(*) FROM DMT_PJF_PROJECTS_TFM_TBL     WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_PJF_TASKS_TFM_TBL        WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_PJF_TEAM_MEMBERS_TFM_TBL WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_PJC_TXN_CONTROLS_TFM_TBL WHERE RUN_ID = p_run_id)
        INTO   l_gen_count
        FROM   dual;

        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code  => C_CEMLI,
            p_run_id      => p_run_id,
            p_load_ess_id => TO_NUMBER(p_request_id),
            p_row_cap     => l_gen_count,
            x_rows        => l_rows,
            x_error_code  => l_err_code);

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
            FOR i IN 1 .. l_rows.COUNT LOOP
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
                        l_prj_loaded := l_prj_loaded + SQL%ROWCOUNT;
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
                        l_tsk_loaded := l_tsk_loaded + SQL%ROWCOUNT;
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
                        l_tm_loaded := l_tm_loaded + SQL%ROWCOUNT;
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
                        l_tc_loaded := l_tc_loaded + SQL%ROWCOUNT;
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
    -- RECONCILE_BATCH — entry point (signature unchanged). Calls the shared
    -- Contract v1 apply, then runs the Projects import-report harvest to overlay
    -- the real per-row Fusion error text onto the '#IMPORT_REPORT#' marker rows
    -- the apply left GENERATED (the interface tables carry no error-text column,
    -- so this harvest is the ONLY source of real per-row error detail). The
    -- Projects load ESS id is the Contract v1 P_LOAD_REQUEST_ID; the report's
    -- run-scoped selectors (P_RUN_ID, P_PREFIX) pick up the whole run.
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
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' start. load_ess_id: ' || p_load_ess_id ||
                         ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            p_package   => C_PKG,
            p_procedure => C_PROC);

        -- Contract v1 fetch + per-tier apply: BASE/SUCCESS rows -> LOADED (stamp
        -- FUSION_ID); real Fusion ERROR rows -> FAILED. The '#IMPORT_REPORT#'
        -- marker rows are intentionally left GENERATED.
        APPLY_CONTRACT_V1_PROJECTS(p_run_id, TO_CHAR(p_load_ess_id));

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

END DMT_PROJECT_RESULTS_PKG;
/
