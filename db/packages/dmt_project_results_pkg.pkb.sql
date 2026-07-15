-- PACKAGE BODY DMT_PROJECT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PROJECT_RESULTS_PKG"
AS
-- ============================================================
-- DMT_PROJECT_RESULTS_PKG body
-- Projects BIP reconciliation — one object, four record types.
--
-- Ported to the accepted architecture 2026-07-09:
--   * Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no
--     private UTL_HTTP copy, no raw envelope logging — the shared
--     transport never logs the request envelope, which carries
--     credentials).
--   * Contract v1 parameters: P_RUN_ID / P_LOAD_REQUEST_ID /
--     P_IMPORT_ESS_ID / P_PREFIX (P_BATCH_ID retired).
--   * Outcomes are written to the four TFM tables only; nothing is
--     written back to staging — the TFM row is the sole record of
--     the Fusion outcome.
--
-- BIP query returns an OBJECT_TYPE discriminator that routes each
-- row to the correct TFM table:
--   Projects    -> PJF_PROJECTS_ALL_XFACE (Tier 1) + PJF_PROJECTS_ALL_B (Tier 2)
--   Tasks       -> PJF_PROJ_ELEMENTS_XFACE (Tier 1 only)
--   TeamMembers -> PJF_PROJECT_PARTIES_INT (Tier 1 only)
--   TxnControls -> PJC_TXN_CONTROLS_STAGE (Tier 1 only)
--
-- Import Report XML (ESS output) provides per-row error detail,
-- routed to the correct TFM table by error_source.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_PROJECT_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Projects';

    -- --------------------------------------------------------
    -- FETCH_BIP_RESULTS
    -- Delegates to DMT_UTIL_PKG.RUN_BIP_REPORT with the Contract v1
    -- parameters. PROCEDURE per the accepted error-code contract:
    -- x_report_xml NULL with x_error_code = C_SUCCESS = zero rows;
    -- failures are logged and reported via x_error_code — exceptions
    -- never escape.
    -- --------------------------------------------------------
    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id         IN  NUMBER,
        p_load_ess_id    IN  NUMBER,
        x_report_xml     OUT XMLTYPE,
        x_error_code     OUT NUMBER,
        p_import_ess_id  IN  NUMBER DEFAULT NULL
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'FETCH_BIP_RESULTS';
        l_step   VARCHAR2(500);
        l_prefix VARCHAR2(20);
    BEGIN
        x_report_xml := NULL;
        x_error_code := DMT_UTIL_PKG.C_ERROR;   -- pessimistic until proven

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => 'FETCH_BIP_RESULTS start. CEMLI: ' || C_CEMLI ||
                         ' | P_RUN_ID: ' || p_run_id ||
                         ' | P_LOAD_REQUEST_ID: ' || p_load_ess_id ||
                         ' | P_IMPORT_ESS_ID: ' || NVL(TO_CHAR(p_import_ess_id), '(null)'),
            p_package   => C_PKG,
            p_procedure => C_PROC);

        l_step := 'reading run prefix for run ' || p_run_id;
        SELECT PREFIX INTO l_prefix
        FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;

        -- Shared transport: resolves REPORT_CATALOG_PATH from
        -- DMT_BIP_REPORT_TBL; HTTP/SOAP/decode failures are logged by
        -- RUN_BIP_REPORT and surfaced through x_error_code. It never
        -- logs the request envelope (credentials never reach DMT_LOG_TBL).
        l_step := 'running Contract v1 reconciliation report for ' || C_CEMLI;
        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id     => p_run_id,
            p_cemli_code => C_CEMLI,
            p_params     => 'P_RUN_ID|'           || TO_CHAR(p_run_id) ||
                            '~P_LOAD_REQUEST_ID|' || TO_CHAR(p_load_ess_id) ||
                            '~P_IMPORT_ESS_ID|'   || TO_CHAR(p_import_ess_id) ||
                            '~P_PREFIX|'          || l_prefix,
            x_report_xml => x_report_xml,
            x_error_code => x_error_code);

        IF x_error_code != DMT_UTIL_PKG.C_SUCCESS THEN
            DMT_UTIL_PKG.LOG(
                p_run_id  => p_run_id,
                p_message => 'FETCH_BIP_RESULTS failed while ' || l_step ||
                             ' (detail logged by RUN_BIP_REPORT).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_ERROR,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RETURN;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => 'FETCH_BIP_RESULTS complete. CEMLI: ' || C_CEMLI ||
                         CASE WHEN x_report_xml IS NULL
                              THEN ' | Report returned zero rows.'
                              ELSE ' | Report data received.'
                         END,
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            x_report_xml := NULL;
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id  => p_run_id,
                p_message => 'FETCH_BIP_RESULTS failed while ' || l_step ||
                             ' | CEMLI: ' || C_CEMLI,
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
    END FETCH_BIP_RESULTS;

    -- --------------------------------------------------------
    -- Private: apply Import Report per-row errors to the four TFM
    -- tables, routing by error_source. Writes TFM only.
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
    BEGIN
        x_matched := 0;
        IF p_import_ess_id IS NULL THEN
            RETURN;
        END IF;

        BEGIN
            l_ir_xml := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(p_import_ess_id);
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(
                    p_run_id  => p_run_id,
                    p_message => C_PROC || ': Failed to download ESS output XML for request ' ||
                                 p_import_ess_id || ': ' || SQLERRM,
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

            IF l_src LIKE '%TASK%' THEN
                UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL
                SET    TFM_STATUS = 'FAILED',
                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           '[IMPORT_REPORT] ' || NVL(l_ir_errors(i).error_message, 'Import error')),
                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                AND    (TASK_NAME = l_ir_errors(i).row_identifier
                        OR PROJECT_NUMBER || '/' || TASK_NAME = l_ir_errors(i).row_identifier);
                x_matched := x_matched + SQL%ROWCOUNT;

            ELSIF l_src LIKE '%TEAM%' OR l_src LIKE '%PART%' OR l_src LIKE '%MEMBER%' THEN
                UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL
                SET    TFM_STATUS = 'FAILED',
                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           '[IMPORT_REPORT] ' || NVL(l_ir_errors(i).error_message, 'Import error')),
                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                AND    (TEAM_MEMBER_NAME = l_ir_errors(i).row_identifier
                        OR PROJECT_NAME || '/' || TEAM_MEMBER_NAME = l_ir_errors(i).row_identifier);
                x_matched := x_matched + SQL%ROWCOUNT;

            ELSIF l_src LIKE '%TXN%' OR l_src LIKE '%CONTROL%' THEN
                UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL
                SET    TFM_STATUS = 'FAILED',
                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           '[IMPORT_REPORT] ' || NVL(l_ir_errors(i).error_message, 'Import error')),
                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                AND    (TXN_CTRL_REFERENCE = l_ir_errors(i).row_identifier
                        OR PROJECT_NUMBER || '/' || TXN_CTRL_REFERENCE = l_ir_errors(i).row_identifier);
                x_matched := x_matched + SQL%ROWCOUNT;

            ELSE
                UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
                SET    TFM_STATUS = 'FAILED',
                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           '[IMPORT_REPORT] ' || NVL(l_ir_errors(i).error_message, 'Import error')),
                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                AND    PROJECT_NUMBER = l_ir_errors(i).row_identifier;
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
            -- reconciliation: degrade to the caller's final FAILED sweep so
            -- unmatched GENERATED rows still reach FAILED with a reportable
            -- error (Rule #1 intent). Log a WARN and return what we matched.
            IF l_ir_xml IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_ir_xml) = 1 THEN
                DBMS_LOB.FREETEMPORARY(l_ir_xml);
            END IF;
            DMT_UTIL_PKG.LOG(
                p_run_id  => p_run_id,
                p_message => C_PROC || ': Import Report parse/apply failed (' || SQLERRM ||
                             '); ' || x_matched || ' rows matched before the error. Falling'
                             || ' back to the final reconcile sweep.',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
    END apply_import_report;

    -- --------------------------------------------------------
    -- PARSE_AND_UPDATE — Two-tier reconciliation + child objects.
    -- Reads the already-decoded report XML and updates the four TFM
    -- tables. TFM only — nothing is written back to staging.
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id         IN NUMBER,
        p_report_xml     IN XMLTYPE,
        p_import_ess_id  IN NUMBER DEFAULT NULL
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_prj_loaded NUMBER := 0;
        l_prj_failed NUMBER := 0;
        l_tsk_loaded NUMBER := 0;
        l_tsk_failed NUMBER := 0;
        l_tm_loaded  NUMBER := 0;
        l_tm_failed  NUMBER := 0;
        l_tc_loaded  NUMBER := 0;
        l_tc_failed  NUMBER := 0;
        l_not_recon  NUMBER := 0;
        l_ir_matched NUMBER := 0;
        l_still_gen  NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' start.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

        IF p_report_xml IS NULL THEN
            -- BIP returned zero rows from BOTH tiers. Try the Import
            -- Report fallback before marking everything FAILED.
            DMT_UTIL_PKG.LOG(
                p_run_id  => p_run_id,
                p_message => C_PROC || ': BIP returned zero rows. Attempting Import Report fallback.',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);

            apply_import_report(p_run_id, p_import_ess_id, l_ir_matched);

            -- Mark remaining GENERATED rows FAILED across all four TFM tables.
            UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            l_not_recon := SQL%ROWCOUNT;
            UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            l_not_recon := l_not_recon + SQL%ROWCOUNT;
            UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            l_not_recon := l_not_recon + SQL%ROWCOUNT;
            UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            l_not_recon := l_not_recon + SQL%ROWCOUNT;

            DMT_UTIL_PKG.LOG(
                p_run_id  => p_run_id,
                p_message => C_PROC || ': zero-row path complete. IR_MATCHED: ' || l_ir_matched ||
                             ', NOT_RECONCILED: ' || l_not_recon || '.',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RETURN;
        END IF;

        -- ================================================================
        -- Per-object-type reconciliation from the BIP XML. OBJECT_TYPE
        -- routes each row to the correct TFM table.
        -- Projects: Tier 1 (INTERFACE) + Tier 2 (BASE).
        -- Tasks/TeamMembers/TxnControls: Tier 1 (INTERFACE) only —
        --   successful child rows are purged from the interface tables;
        --   only rejected/unprocessed rows remain.
        -- ================================================================
        FOR r IN (
            SELECT UPPER(x.object_type)    AS object_type,
                   x.project_name,
                   x.project_number,
                   x.task_name,
                   x.team_member_name,
                   x.txn_ctrl_reference,
                   UPPER(x.source_type)    AS source_type,
                   UPPER(x.import_status)  AS import_status,
                   UPPER(x.load_status)    AS load_status,
                   x.fusion_id,
                   x.error_msg
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                COLUMNS
                    object_type        VARCHAR2(30)   PATH 'OBJECT_TYPE',
                    project_name       VARCHAR2(240)  PATH 'PROJECT_NAME',
                    project_number     VARCHAR2(25)   PATH 'PROJECT_NUMBER',
                    task_name          VARCHAR2(240)  PATH 'TASK_NAME',
                    team_member_name   VARCHAR2(240)  PATH 'TEAM_MEMBER_NAME',
                    txn_ctrl_reference VARCHAR2(240)  PATH 'TXN_CTRL_REFERENCE',
                    source_type        VARCHAR2(20)   PATH 'SOURCE_TYPE',
                    import_status      VARCHAR2(50)   PATH 'IMPORT_STATUS',
                    load_status        VARCHAR2(50)   PATH 'LOAD_STATUS',
                    fusion_id          NUMBER         PATH 'FUSION_ID',
                    error_msg          VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
        ) LOOP

            -- ---- PROJECTS ----
            IF r.object_type = 'PROJECTS' THEN
                IF r.source_type = 'BASE' THEN
                    -- Tier 2: found in base table = positively LOADED.
                    UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           FUSION_PROJECT_ID    = r.fusion_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID         = p_run_id
                    AND    PROJECT_NUMBER = r.project_number
                    AND    TFM_STATUS     NOT IN ('LOADED','FAILED');
                    l_prj_loaded := l_prj_loaded + SQL%ROWCOUNT;

                ELSIF r.source_type = 'INTERFACE' THEN
                    IF r.import_status IN ('COMPLETED','IMPORTED','Y','PROCESSED','SUCCESS','P') THEN
                        UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_PROJECT_ID    = r.fusion_id,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID         = p_run_id
                        AND    PROJECT_NUMBER = r.project_number
                        AND    TFM_STATUS     NOT IN ('LOADED','FAILED');
                        l_prj_loaded := l_prj_loaded + SQL%ROWCOUNT;
                    ELSIF r.import_status IN ('ERROR','REJECTED','FAILED','FAILURE','N','SUBMITTED') THEN
                        -- SUBMITTED = loaded but not processed (e.g. parent missing).
                        UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                   '[FUSION_ERROR] ' || NVL(r.error_msg, 'Interface status: ' || r.import_status)),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID         = p_run_id
                        AND    PROJECT_NUMBER = r.project_number
                        AND    TFM_STATUS     NOT IN ('LOADED','FAILED');
                        l_prj_failed := l_prj_failed + SQL%ROWCOUNT;
                    ELSE
                        UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                   '[FUSION_ERROR] Unrecognized interface status: ' || NVL(r.import_status, 'NULL')),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID         = p_run_id
                        AND    PROJECT_NUMBER = r.project_number
                        AND    TFM_STATUS     NOT IN ('LOADED','FAILED');
                        l_prj_failed := l_prj_failed + SQL%ROWCOUNT;
                    END IF;
                END IF;

            -- ---- TASKS ----
            ELSIF r.object_type = 'TASKS' THEN
                IF r.import_status IN ('ERROR','REJECTED','FAILED','FAILURE','N','SUBMITTED') THEN
                    UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL
                    SET    TFM_STATUS           = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                               '[FUSION_ERROR] Task rejected by Fusion. Project: ' || r.project_number ||
                               '. Interface status: ' || r.import_status),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID         = p_run_id
                    AND    TASK_NAME      = r.task_name
                    AND    PROJECT_NUMBER = r.project_number
                    AND    TFM_STATUS     NOT IN ('LOADED','FAILED');
                    l_tsk_failed := l_tsk_failed + SQL%ROWCOUNT;
                ELSIF r.import_status IN ('COMPLETED','IMPORTED','Y','PROCESSED','SUCCESS','P') THEN
                    UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID         = p_run_id
                    AND    TASK_NAME      = r.task_name
                    AND    PROJECT_NUMBER = r.project_number
                    AND    TFM_STATUS     NOT IN ('LOADED','FAILED');
                    l_tsk_loaded := l_tsk_loaded + SQL%ROWCOUNT;
                ELSE
                    UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL
                    SET    TFM_STATUS           = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                               '[FUSION_ERROR] Task unrecognized status: ' || NVL(r.import_status, 'NULL')),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID         = p_run_id
                    AND    TASK_NAME      = r.task_name
                    AND    PROJECT_NUMBER = r.project_number
                    AND    TFM_STATUS     NOT IN ('LOADED','FAILED');
                    l_tsk_failed := l_tsk_failed + SQL%ROWCOUNT;
                END IF;

            -- ---- TEAM MEMBERS ----
            ELSIF r.object_type = 'TEAMMEMBERS' THEN
                IF r.import_status IN ('ERROR','REJECTED','FAILED','FAILURE','N','SUBMITTED') THEN
                    UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL
                    SET    TFM_STATUS           = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                               '[FUSION_ERROR] Team member rejected by Fusion. Project: ' || r.project_name ||
                               '. Interface status: ' || r.import_status),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID           = p_run_id
                    AND    TEAM_MEMBER_NAME = r.team_member_name
                    AND    PROJECT_NAME     = r.project_name
                    AND    TFM_STATUS       NOT IN ('LOADED','FAILED');
                    l_tm_failed := l_tm_failed + SQL%ROWCOUNT;
                ELSIF r.import_status IN ('COMPLETED','IMPORTED','Y','PROCESSED','SUCCESS','P') THEN
                    UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID           = p_run_id
                    AND    TEAM_MEMBER_NAME = r.team_member_name
                    AND    PROJECT_NAME     = r.project_name
                    AND    TFM_STATUS       NOT IN ('LOADED','FAILED');
                    l_tm_loaded := l_tm_loaded + SQL%ROWCOUNT;
                ELSE
                    UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL
                    SET    TFM_STATUS           = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                               '[FUSION_ERROR] Team member unrecognized status: ' || NVL(r.import_status, 'NULL')),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID           = p_run_id
                    AND    TEAM_MEMBER_NAME = r.team_member_name
                    AND    PROJECT_NAME     = r.project_name
                    AND    TFM_STATUS       NOT IN ('LOADED','FAILED');
                    l_tm_failed := l_tm_failed + SQL%ROWCOUNT;
                END IF;

            -- ---- TXN CONTROLS ----
            ELSIF r.object_type = 'TXNCONTROLS' THEN
                -- PJC_TXN_CONTROLS_STAGE has LOAD_STATUS but no IMPORT_STATUS.
                IF NVL(r.import_status, r.load_status) IN ('ERROR','REJECTED','FAILED','FAILURE','N','SUBMITTED') THEN
                    UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL
                    SET    TFM_STATUS           = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                               '[FUSION_ERROR] Txn control rejected by Fusion. Project: ' || r.project_number ||
                               '. Status: ' || NVL(r.import_status, r.load_status)),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID             = p_run_id
                    AND    TXN_CTRL_REFERENCE = r.txn_ctrl_reference
                    AND    PROJECT_NUMBER     = r.project_number
                    AND    TFM_STATUS         NOT IN ('LOADED','FAILED');
                    l_tc_failed := l_tc_failed + SQL%ROWCOUNT;
                ELSIF NVL(r.import_status, r.load_status) IN ('COMPLETED','IMPORTED','Y','PROCESSED','SUCCESS','P','COMPLETE') THEN
                    UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID             = p_run_id
                    AND    TXN_CTRL_REFERENCE = r.txn_ctrl_reference
                    AND    PROJECT_NUMBER     = r.project_number
                    AND    TFM_STATUS         NOT IN ('LOADED','FAILED');
                    l_tc_loaded := l_tc_loaded + SQL%ROWCOUNT;
                ELSE
                    UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL
                    SET    TFM_STATUS           = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                               '[FUSION_ERROR] Txn control unrecognized status: ' ||
                               NVL(r.import_status, NVL(r.load_status, 'NULL'))),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID             = p_run_id
                    AND    TXN_CTRL_REFERENCE = r.txn_ctrl_reference
                    AND    PROJECT_NUMBER     = r.project_number
                    AND    TFM_STATUS         NOT IN ('LOADED','FAILED');
                    l_tc_failed := l_tc_failed + SQL%ROWCOUNT;
                END IF;

            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ': BIP complete. Projects ' || l_prj_loaded || 'L/' || l_prj_failed || 'F' ||
                         ', Tasks ' || l_tsk_loaded || 'L/' || l_tsk_failed || 'F' ||
                         ', TeamMembers ' || l_tm_loaded || 'L/' || l_tm_failed || 'F' ||
                         ', TxnControls ' || l_tc_loaded || 'L/' || l_tc_failed || 'F',
            p_package   => C_PKG,
            p_procedure => C_PROC);

        -- ================================================================
        -- Import Report fallback: if any TFM rows are still GENERATED,
        -- match per-row errors from the ESS Import Report XML.
        -- ================================================================
        SELECT (SELECT COUNT(*) FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED')
             + (SELECT COUNT(*) FROM DMT_OWNER.DMT_PJF_TASKS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED')
             + (SELECT COUNT(*) FROM DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED')
             + (SELECT COUNT(*) FROM DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL
                WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED')
        INTO l_still_gen FROM DUAL;

        IF l_still_gen > 0 AND p_import_ess_id IS NOT NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id  => p_run_id,
                p_message => C_PROC || ': ' || l_still_gen ||
                             ' rows still GENERATED after BIP. Attempting Import Report (ESS ' ||
                             p_import_ess_id || ').',
                p_package   => C_PKG,
                p_procedure => C_PROC);
            apply_import_report(p_run_id, p_import_ess_id, l_ir_matched);
        END IF;

        -- ================================================================
        -- Cascade: a child TFM row still GENERATED inherits its parent
        -- project's outcome. Catches children purged from the interface
        -- table after successful import (no BIP row returned).
        -- ================================================================
        -- Tasks: cascade LOADED from parent project
        UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL tsk
        SET    tsk.TFM_STATUS           = 'LOADED',
               tsk.RESULTS_UPDATED_DATE = SYSDATE,
               tsk.LAST_UPDATED_DATE    = SYSDATE
        WHERE  tsk.RUN_ID     = p_run_id
        AND    tsk.TFM_STATUS = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL p
            WHERE  p.RUN_ID         = p_run_id
            AND    p.PROJECT_NUMBER = tsk.PROJECT_NUMBER
            AND    p.TFM_STATUS     = 'LOADED');

        -- Team Members: cascade LOADED from parent project
        UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL tm
        SET    tm.TFM_STATUS           = 'LOADED',
               tm.RESULTS_UPDATED_DATE = SYSDATE,
               tm.LAST_UPDATED_DATE    = SYSDATE
        WHERE  tm.RUN_ID     = p_run_id
        AND    tm.TFM_STATUS = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL p
            WHERE  p.RUN_ID       = p_run_id
            AND    p.PROJECT_NAME = tm.PROJECT_NAME
            AND    p.TFM_STATUS   = 'LOADED');

        -- Txn Controls: cascade LOADED from parent project
        UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL tc
        SET    tc.TFM_STATUS           = 'LOADED',
               tc.RESULTS_UPDATED_DATE = SYSDATE,
               tc.LAST_UPDATED_DATE    = SYSDATE
        WHERE  tc.RUN_ID     = p_run_id
        AND    tc.TFM_STATUS = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL p
            WHERE  p.RUN_ID         = p_run_id
            AND    p.PROJECT_NUMBER = tc.PROJECT_NUMBER
            AND    p.TFM_STATUS     = 'LOADED');

        -- Tasks: cascade FAILED from parent project
        UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL tsk
        SET    tsk.TFM_STATUS           = 'FAILED',
               tsk.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(tsk.ERROR_TEXT,
                   '[FUSION_ERROR] Parent project ' || tsk.PROJECT_NUMBER || ' was rejected by Fusion.'),
               tsk.RESULTS_UPDATED_DATE = SYSDATE,
               tsk.LAST_UPDATED_DATE    = SYSDATE
        WHERE  tsk.RUN_ID     = p_run_id
        AND    tsk.TFM_STATUS = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL p
            WHERE  p.RUN_ID         = p_run_id
            AND    p.PROJECT_NUMBER = tsk.PROJECT_NUMBER
            AND    p.TFM_STATUS     = 'FAILED');

        -- Team Members: cascade FAILED from parent project
        UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL tm
        SET    tm.TFM_STATUS           = 'FAILED',
               tm.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(tm.ERROR_TEXT,
                   '[FUSION_ERROR] Parent project ' || tm.PROJECT_NAME || ' was rejected by Fusion.'),
               tm.RESULTS_UPDATED_DATE = SYSDATE,
               tm.LAST_UPDATED_DATE    = SYSDATE
        WHERE  tm.RUN_ID     = p_run_id
        AND    tm.TFM_STATUS = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL p
            WHERE  p.RUN_ID       = p_run_id
            AND    p.PROJECT_NAME = tm.PROJECT_NAME
            AND    p.TFM_STATUS   = 'FAILED');

        -- Txn Controls: cascade FAILED from parent project
        UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL tc
        SET    tc.TFM_STATUS           = 'FAILED',
               tc.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(tc.ERROR_TEXT,
                   '[FUSION_ERROR] Parent project ' || tc.PROJECT_NUMBER || ' was rejected by Fusion.'),
               tc.RESULTS_UPDATED_DATE = SYSDATE,
               tc.LAST_UPDATED_DATE    = SYSDATE
        WHERE  tc.RUN_ID     = p_run_id
        AND    tc.TFM_STATUS = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL p
            WHERE  p.RUN_ID         = p_run_id
            AND    p.PROJECT_NUMBER = tc.PROJECT_NUMBER
            AND    p.TFM_STATUS     = 'FAILED');

        -- (Absence != LOADED catch-all moved to the standard SWEEP_UNACCOUNTED — §7.)
        l_not_recon := 0;

        -- NO write-back to staging — the TFM row is the sole record of the
        -- Fusion outcome (accepted rule: downstream outcomes are never
        -- written back to staging). NO COMMIT — the orchestrator owns the
        -- transaction boundary.

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' complete.' ||
                         ' Projects ' || l_prj_loaded || 'L/' || l_prj_failed || 'F' ||
                         ', Tasks ' || l_tsk_loaded || 'L/' || l_tsk_failed || 'F' ||
                         ', TeamMembers ' || l_tm_loaded || 'L/' || l_tm_failed || 'F' ||
                         ', TxnControls ' || l_tc_loaded || 'L/' || l_tc_failed || 'F' ||
                         ', IR_MATCHED: ' || l_ir_matched ||
                         ', NOT_RECONCILED: ' || l_not_recon || '.',
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
    END PARSE_AND_UPDATE;

    -- ============================================================
    -- SWEEP_UNACCOUNTED — STANDARD RECONCILE-ERROR SWEEP (design §7).
    -- Marks every TFM row still NOT IN ('LOADED','FAILED') as FAILED with a
    -- reportable [RECONCILE_ERROR] (absence != LOADED, Rule #1). Byte-identical
    -- across packages except the tagged EDIT regions. Does NOT commit.
    -- ============================================================
    PROCEDURE SWEEP_UNACCOUNTED (p_run_id IN NUMBER) IS
    BEGIN
        -- <<EDIT-TABLE — CHANGE BELOW: the object's TFM table name. Repeat this
        --   whole UPDATE block (EDIT-TABLE through the ';') once per TFM table
        --   the object owns.>>
        UPDATE DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-MSG>>
        SET    TFM_STATUS           = 'FAILED',
               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
        -- <<EDIT-MSG — CHANGE BELOW: the message text. It MUST begin with the
        --   literal '[RECONCILE_ERROR] ' tag.>>
                   '[RECONCILE_ERROR] Project not confirmed in Fusion '
                   || '(not found in the PJF_PROJECTS_ALL_B base table for this run) '
                   || 'after reconciliation; its import outcome could not be verified.'
        -- <<END EDIT-MSG — everything below is FIXED until EDIT-SCOPE>>
               ),
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID     = p_run_id
        AND    TFM_STATUS NOT IN ('LOADED','FAILED')
        -- (EDIT-SCOPE deleted — DMT_PJF_PROJECTS_TFM_TBL is not shared.)
        ;

        -- <<EDIT-TABLE — CHANGE BELOW: the object's TFM table name. Repeat this
        --   whole UPDATE block (EDIT-TABLE through the ';') once per TFM table
        --   the object owns.>>
        UPDATE DMT_OWNER.DMT_PJF_TASKS_TFM_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-MSG>>
        SET    TFM_STATUS           = 'FAILED',
               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
        -- <<EDIT-MSG — CHANGE BELOW: the message text. It MUST begin with the
        --   literal '[RECONCILE_ERROR] ' tag.>>
                   '[RECONCILE_ERROR] Project task not confirmed in Fusion '
                   || '(not found in the PJF_TASKS base table for this run) after '
                   || 'reconciliation; its import outcome could not be verified.'
        -- <<END EDIT-MSG — everything below is FIXED until EDIT-SCOPE>>
               ),
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID     = p_run_id
        AND    TFM_STATUS NOT IN ('LOADED','FAILED')
        -- (EDIT-SCOPE deleted — DMT_PJF_TASKS_TFM_TBL is not shared.)
        ;

        -- <<EDIT-TABLE — CHANGE BELOW: the object's TFM table name. Repeat this
        --   whole UPDATE block (EDIT-TABLE through the ';') once per TFM table
        --   the object owns.>>
        UPDATE DMT_OWNER.DMT_PJF_TEAM_MEMBERS_TFM_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-MSG>>
        SET    TFM_STATUS           = 'FAILED',
               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
        -- <<EDIT-MSG — CHANGE BELOW: the message text. It MUST begin with the
        --   literal '[RECONCILE_ERROR] ' tag.>>
                   '[RECONCILE_ERROR] Project team member not confirmed in Fusion '
                   || '(not found in the PJF_PROJECT_PARTIES base table for this run) '
                   || 'after reconciliation; its import outcome could not be verified.'
        -- <<END EDIT-MSG — everything below is FIXED until EDIT-SCOPE>>
               ),
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID     = p_run_id
        AND    TFM_STATUS NOT IN ('LOADED','FAILED')
        -- (EDIT-SCOPE deleted — DMT_PJF_TEAM_MEMBERS_TFM_TBL is not shared.)
        ;

        -- <<EDIT-TABLE — CHANGE BELOW: the object's TFM table name. Repeat this
        --   whole UPDATE block (EDIT-TABLE through the ';') once per TFM table
        --   the object owns.>>
        UPDATE DMT_OWNER.DMT_PJC_TXN_CONTROLS_TFM_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-MSG>>
        SET    TFM_STATUS           = 'FAILED',
               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
        -- <<EDIT-MSG — CHANGE BELOW: the message text. It MUST begin with the
        --   literal '[RECONCILE_ERROR] ' tag.>>
                   '[RECONCILE_ERROR] Project transaction control not confirmed in '
                   || 'Fusion (not found in the PJC_TXN_CONTROLS base table for this run) '
                   || 'after reconciliation; its import outcome could not be verified.'
        -- <<END EDIT-MSG — everything below is FIXED until EDIT-SCOPE>>
               ),
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID     = p_run_id
        AND    TFM_STATUS NOT IN ('LOADED','FAILED')
        -- (EDIT-SCOPE deleted — DMT_PJC_TXN_CONTROLS_TFM_TBL is not shared.)
        ;
    END SWEEP_UNACCOUNTED;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH
    -- Orchestrates FETCH then PARSE. A fetch failure raises so the
    -- work item fails loudly — never a silent zero-row "success".
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id         IN NUMBER,
        p_load_ess_id    IN NUMBER,
        p_import_ess_id  IN NUMBER DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
        l_xml  XMLTYPE;
        l_err  NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' start. load_ess_id: ' || p_load_ess_id ||
                         ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            p_package   => C_PKG,
            p_procedure => C_PROC);

        FETCH_BIP_RESULTS(
            p_run_id        => p_run_id,
            p_load_ess_id   => p_load_ess_id,
            x_report_xml    => l_xml,
            x_error_code    => l_err,
            p_import_ess_id => p_import_ess_id);

        IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20038,
                'RECONCILE_BATCH: FETCH_BIP_RESULTS failed for CEMLI ' ||
                C_CEMLI || ' (detail in DMT_LOG_TBL).');
        END IF;

        PARSE_AND_UPDATE(p_run_id, l_xml, p_import_ess_id);

        -- Standard final step: fail any row still unaccounted (absence != LOADED).
        SWEEP_UNACCOUNTED(p_run_id);

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' complete.',
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
