-- PACKAGE BODY DMT_FND_VS_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_FND_VS_RESULTS_PKG" AS
-- ============================================================
-- DMT_FND_VS_RESULTS_PKG body
-- Value Sets: FBDI-file + ESS-import load + BIP base-table reconciliation.
--
-- LOAD mechanism (backlog #130 slice): Value Set VALUES load via the house FBDI
-- path, NOT REST. DMT_FND_VS_FBL_GEN_PKG has already built the FBDI zip and
-- persisted it to DMT_FBDI_ZIP_TBL (OBJECT_TYPE='FND_VS'). LOAD_VIA_FBDI hands
-- that zip to the shared DMT_LOADER_PKG.SUBMIT_LOAD (loadAndImportData — one SOAP
-- call that uploads the zip to UCM and submits the Fusion "Upload Value Set
-- Values" scheduled process, FndValueSetUploadServiceJob), then polls that ESS
-- job to a terminal state. This replaces the dead REST POST path: the valueSets
-- REST resource has its "create" action DISABLED on the demo pod, so REST could
-- never create a new value set value. The ERP options (UCM account, import job
-- name, interface-details id) come from DMT_ERP_INTERFACE_OPTIONS_TBL keyed on
-- CEMLI_CODE 'ValueSets'.
--
-- New reconciliation standard (DMT_DESIGN.html, PROPOSED 2026-09):
-- reconciliation MUST be a BIP report over the Fusion BASE tables that
-- returns the base-table surrogate id. An ESS "SUCCEEDED" is NOT itself
-- reconciliation. ValueSets is a two-object load (a value set, then its
-- child values); LOAD and RECONCILE are two separate phases:
--
--   LOAD  (LOAD_VIA_FBDI): submit the one FND_VS zip via loadAndImportData and
--         poll the upload ESS job. The load step NEVER marks a row terminal and
--         never writes ERROR_TEXT: rows stay GENERATED for the base-table report.
--         An EXPIRED poll result is DMT's own poll-window timeout, not a Fusion
--         state, so it is logged (with Fusion's own state for the request) and
--         nothing is stamped. A terminal non-success ESS state (e.g. ERROR) is a
--         job-level outcome that carries no per-row Fusion message in this step,
--         so it is logged and nothing is stamped either (design section 7.1: a
--         job-level ESS ERROR routes to reconcile, never a fabricated
--         [LOAD_ERROR]). A transport exception is logged and re-raised so the work
--         item fails loudly.
--
--   RECONCILE (FETCH_BIP_RESULTS + PARSE_AND_UPDATE): run the base-table
--         report DMT_VS_RECON_RPT over this run's set codes and value keys.
--         A set found in FND_VS_VALUE_SETS -> LOADED with
--         FUSION_VALUE_SET_ID = VALUE_SET_ID. A value found in
--         FND_VS_VALUES_B  -> LOADED with FUSION_VALUE_ID = VALUE_ID (the
--         real surrogate ids). Rows not returned stay GENERATED and the shared
--         unaccounted sweep (DMT_QUEUE_WORKER_PKG) marks them UNACCOUNTED --
--         never a fabricated LOADED, id, or FAILED.
--
-- Outcomes are written to the TFM tables only; nothing is written back to the
-- staging tables (design section 5: no process writes downstream outcomes to
-- staging). No COMMIT here: the runner (DMT_FND_VS_RUNNER_PKG.RUN) owns the
-- transaction.
--
-- Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no private SOAP
-- copy). Base tables: FND_VS_VALUE_SETS (id VALUE_SET_ID) and
-- FND_VS_VALUES_B (id VALUE_ID). Backlog #11 / new recon standard.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50)  := 'DMT_FND_VS_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30)  := 'ValueSets';

    -- Terminal ESS statuses that mean the upload job carried the file through
    -- (per-row verdicts then come from the base-table report, not from here).
    C_STATUS_SUCCEEDED CONSTANT VARCHAR2(20) := 'SUCCEEDED';
    C_STATUS_WARNING   CONSTANT VARCHAR2(20) := 'WARNING';
    -- POLL_ESS_JOB's result when DMT's own poll window ran out (not a Fusion state).
    C_STATUS_EXPIRED   CONSTANT VARCHAR2(20) := 'EXPIRED';

    -- --------------------------------------------------------
    -- GET_VS_ERP_OPTIONS (private)
    -- Reads the ValueSets ERP options: UCM account, import job name and
    -- interface-details id. The stored IMPORT_JOB_NAME uses ';' between the
    -- package path and the job definition; loadAndImportData's <erp:JobName>
    -- needs ',' -- the last ';' is converted. Raises -20040 when the row is
    -- missing (the caller logs and re-raises).
    -- --------------------------------------------------------
    PROCEDURE GET_VS_ERP_OPTIONS (
        x_ucm_account   OUT VARCHAR2,
        x_job_name      OUT VARCHAR2,
        x_iface_details OUT NUMBER
    ) IS
        l_raw_job_name VARCHAR2(500);
        l_sep          PLS_INTEGER;
    BEGIN
        SELECT UCM_ACCOUNT,
               IMPORT_JOB_NAME,
               TO_NUMBER(NVL(SOURCE_ERP_OPTIONS_ID, ERP_INTERFACE_OPTIONS_ID))
        INTO   x_ucm_account, l_raw_job_name, x_iface_details
        FROM   DMT_ERP_INTERFACE_OPTIONS_TBL
        WHERE  CEMLI_CODE = C_CEMLI;

        l_sep := INSTR(l_raw_job_name, ';', -1);
        IF l_sep > 0 THEN
            x_job_name := SUBSTR(l_raw_job_name, 1, l_sep - 1) || ','
                          || SUBSTR(l_raw_job_name, l_sep + 1);
        ELSE
            x_job_name := l_raw_job_name;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20040,
                'LOAD_VIA_FBDI: No row in DMT_ERP_INTERFACE_OPTIONS_TBL for CEMLI_CODE '''
                || C_CEMLI || '''. Seed the ValueSets ERP-options row (UCM account + '
                || 'import job name) before running the pipeline.');
    END GET_VS_ERP_OPTIONS;

    -- --------------------------------------------------------
    -- GET_VS_ZIP (private)
    -- Returns this run's generated FND_VS zip (one per run, built by the FBL
    -- gen pkg). x_zip NULL means there is no zip for the run: a defined
    -- outcome the caller logs as "nothing to load", not an error.
    -- --------------------------------------------------------
    PROCEDURE GET_VS_ZIP (
        p_run_id   IN  NUMBER,
        x_zip      OUT BLOB,
        x_filename OUT VARCHAR2
    ) IS
    BEGIN
        SELECT ZIP_CONTENT, FILENAME
        INTO   x_zip, x_filename
        FROM   DMT_FBDI_ZIP_TBL
        WHERE  RUN_ID = p_run_id
        AND    OBJECT_TYPE = 'FND_VS';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            x_zip      := NULL;   -- no zip for this run: the caller logs "nothing to load"
            x_filename := NULL;
    END GET_VS_ZIP;

    -- --------------------------------------------------------
    -- READ_FUSION_STATE (private, diagnostic only)
    -- Reads Fusion's own state for an ESS request from ESS_REQUEST_HISTORY
    -- (CAPTURE_ESS_HIERARCHY -> one BIP query, recorded in DMT_ESS_JOB_TBL).
    -- Used only to word the log entry when DMT's poll window ran out; it never
    -- decides a row outcome. A failed lookup is logged and reported through
    -- x_error_code; x_fusion_state is then NULL (never guessed).
    -- --------------------------------------------------------
    PROCEDURE READ_FUSION_STATE (
        p_run_id       IN  NUMBER,
        p_load_ess_id  IN  VARCHAR2,
        x_fusion_state OUT VARCHAR2,
        x_error_code   OUT NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'READ_FUSION_STATE';
    BEGIN
        x_fusion_state := NULL;
        x_error_code   := DMT_UTIL_PKG.C_ERROR;

        DMT_ESS_UTIL_PKG.CAPTURE_ESS_HIERARCHY(
            p_run_id            => p_run_id,
            p_parent_request_id => TO_NUMBER(p_load_ess_id),
            p_cemli_code        => C_CEMLI);

        SELECT MAX(STATE_TEXT) KEEP (DENSE_RANK LAST ORDER BY ESS_JOB_ID)
        INTO   x_fusion_state
        FROM   DMT_ESS_JOB_TBL
        WHERE  RUN_ID = p_run_id
        AND    REQUEST_ID = TO_NUMBER(p_load_ess_id);

        x_error_code := DMT_UTIL_PKG.C_SUCCESS;
    EXCEPTION
        WHEN OTHERS THEN
            x_fusion_state := NULL;
            x_error_code   := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': could not read Fusion state for ESS '
                || p_load_ess_id || ': ' || SUBSTR(SQLERRM, 1, 300),
                p_log_type => 'WARN', p_package => C_PKG, p_procedure => C_PROC);
    END READ_FUSION_STATE;

    -- ============================================================
    -- LOAD_VIA_FBDI
    -- The LOAD step: submit the one generated FND_VS FBDI zip to Fusion via the
    -- shared loadAndImportData path (DMT_LOADER_PKG.SUBMIT_LOAD) and poll the
    -- upload ESS job. The BIP base-table report -- not the ESS status -- is the
    -- authority for LOADED, and this step never marks a row FAILED:
    --   * SUCCEEDED / WARNING: rows left GENERATED for the base-table report.
    --   * EXPIRED: DMT's own poll window ran out while Fusion had not finished.
    --     EXPIRED is not a Fusion terminal state (the job may still run and
    --     load), so it is never a row verdict. Fusion's own state is logged;
    --     rows are left GENERATED for reconciliation, and any row the
    --     base-table report does not confirm ends UNACCOUNTED.
    --   * Any other terminal state (e.g. ERROR): a job-level outcome. This step
    --     has no per-row Fusion error message for it, so it is logged and rows
    --     are left GENERATED for reconciliation the same way -- a status code
    --     is never turned into a [LOAD_ERROR] sentence on the rows.
    -- A transport exception is logged and re-raised (the work item fails
    -- loudly; nothing is stamped on the rows). Writes nothing to TFM; no COMMIT.
    -- ============================================================
    PROCEDURE LOAD_VIA_FBDI (
        p_run_id IN NUMBER
    ) IS
        C_PROC          CONSTANT VARCHAR2(30) := 'LOAD_VIA_FBDI';
        C_LOAD_POLL_SEC CONSTANT PLS_INTEGER  := 1800;   -- DMT poll window for the upload ESS

        l_step          VARCHAR2(500);
        l_ucm_account   VARCHAR2(200);
        l_job_name      VARCHAR2(500);
        l_iface_details NUMBER;
        l_user          VARCHAR2(100);
        l_pass          VARCHAR2(100);
        l_zip           BLOB;
        l_filename      VARCHAR2(200);
        l_load_ess_id   VARCHAR2(100);
        l_status        VARCHAR2(50);
        l_fusion_state  VARCHAR2(30);
        l_state_err     NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        l_step := 'reading the ValueSets ERP options';
        GET_VS_ERP_OPTIONS(
            x_ucm_account   => l_ucm_account,
            x_job_name      => l_job_name,
            x_iface_details => l_iface_details);

        -- Per-CEMLI Fusion creds (SUBMIT_LOAD falls back to config defaults if NULL).
        l_step := 'reading the ValueSets Fusion credentials';
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(C_CEMLI, l_user, l_pass);

        l_step := 'reading the generated FND_VS zip';
        GET_VS_ZIP(p_run_id => p_run_id, x_zip => l_zip, x_filename => l_filename);

        IF l_zip IS NULL OR DBMS_LOB.GETLENGTH(l_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': no FND_VS zip (or an empty one) for this run. Nothing to load.',
                p_log_type => 'WARN', p_package => C_PKG, p_procedure => C_PROC);
            RETURN;
        END IF;

        l_step := 'submitting the value-set upload via loadAndImportData';
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': submitting value-set upload via loadAndImportData. '
            || 'Job: ' || l_job_name || ' | Account: ' || l_ucm_account
            || ' | File: ' || l_filename,
            p_package => C_PKG, p_procedure => C_PROC);

        l_load_ess_id := DMT_LOADER_PKG.SUBMIT_LOAD(
            p_run_id            => p_run_id,
            p_fbdi_zip          => l_zip,
            p_filename          => l_filename,
            p_job_name          => l_job_name,
            p_interface_details => l_iface_details,
            p_doc_account       => l_ucm_account,
            p_parameter_list    => 'NEW,N',
            p_log_context       => C_CEMLI,
            p_username          => l_user,
            p_password          => l_pass);

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': upload ESS job ' || l_load_ess_id || ' submitted. Polling.',
            p_package => C_PKG, p_procedure => C_PROC);

        l_step := 'polling upload ESS job ' || l_load_ess_id;
        DMT_LOADER_PKG.POLL_ESS_JOB(
            p_run_id         => p_run_id,
            p_ess_job_id     => l_load_ess_id,
            p_timeout_sec    => C_LOAD_POLL_SEC,
            p_raise_on_error => FALSE,
            p_log_context    => C_CEMLI,
            p_cemli_code     => C_CEMLI,
            x_fusion_status  => l_status,
            p_username       => l_user,
            p_password       => l_pass);

        IF l_status IN (C_STATUS_SUCCEEDED, C_STATUS_WARNING) THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': upload ESS ' || l_load_ess_id || ' ended ' || l_status
                || '. Rows left GENERATED for base-table reconciliation.',
                p_package => C_PKG, p_procedure => C_PROC);
        ELSIF l_status = C_STATUS_EXPIRED THEN
            -- DMT's own timeout, not a Fusion verdict: read Fusion's state for the
            -- log only, stamp nothing.
            l_step := 'reading Fusion state for upload ESS job ' || l_load_ess_id;
            READ_FUSION_STATE(
                p_run_id       => p_run_id,
                p_load_ess_id  => l_load_ess_id,
                x_fusion_state => l_fusion_state,
                x_error_code   => l_state_err);
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': upload ESS ' || l_load_ess_id || ' did not finish within DMT''s '
                || C_LOAD_POLL_SEC || 's poll window (EXPIRED is DMT''s timeout, not a Fusion '
                || 'state). Fusion state at that point: '
                || CASE WHEN l_state_err = DMT_UTIL_PKG.C_SUCCESS
                        THEN NVL(l_fusion_state, 'not found') ELSE 'lookup failed' END
                || '. No row is stamped; rows left GENERATED for base-table reconciliation '
                || '(unconfirmed rows end UNACCOUNTED).',
                p_log_type => 'WARN', p_package => C_PKG, p_procedure => C_PROC);
        ELSE
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': upload ESS ' || l_load_ess_id || ' ended in Fusion state '
                || l_status || '. This step has no per-row Fusion error for it, so no row '
                || 'is stamped; rows left GENERATED for base-table reconciliation '
                || '(unconfirmed rows end UNACCOUNTED). See the ESS log for request '
                || l_load_ess_id || '.',
                p_log_type => 'WARN', p_package => C_PKG, p_procedure => C_PROC);
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed while ' || l_step || '.', SQLERRM,
                p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END LOAD_VIA_FBDI;

    -- --------------------------------------------------------
    -- FETCH_BIP_RESULTS
    -- Runs the base-table reconciliation report for this run's set codes and
    -- value keys. Delegates to the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no
    -- private SOAP copy). Two parameters: P_SET_CODES (comma-delimited
    -- VALUE_SET_CODE list) and P_VALUE_KEYS (comma-delimited
    -- VALUE_SET_CODE^VALUE composite-key list); config codes are not
    -- run-prefixed. PROCEDURE per the procedures-only contract: x_report_xml
    -- NULL with x_error_code = C_SUCCESS means zero rows; failures are logged
    -- and surfaced through x_error_code -- exceptions never escape.
    -- --------------------------------------------------------
    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id      IN  NUMBER,
        p_set_codes   IN  VARCHAR2,
        p_value_keys  IN  VARCHAR2,
        x_report_xml  OUT XMLTYPE,
        x_error_code  OUT NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'FETCH_BIP_RESULTS';
        l_step VARCHAR2(500);
    BEGIN
        x_report_xml := NULL;
        x_error_code := DMT_UTIL_PKG.C_ERROR;   -- pessimistic until proven

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. CEMLI: ' || C_CEMLI
            || ' | P_SET_CODES: ' || NVL(p_set_codes, '(none)')
            || ' | P_VALUE_KEYS: ' || NVL(p_value_keys, '(none)'),
            p_package => C_PKG, p_procedure => C_PROC);

        IF p_set_codes IS NULL AND p_value_keys IS NULL THEN
            -- Nothing to confirm: zero rows, not an error.
            x_error_code := DMT_UTIL_PKG.C_SUCCESS;
            RETURN;
        END IF;

        l_step := 'running base-table reconciliation report for ' || C_CEMLI;
        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id     => p_run_id,
            p_cemli_code => C_CEMLI,
            p_params     => 'P_SET_CODES|' || p_set_codes
                            || '~P_VALUE_KEYS|' || p_value_keys,
            x_report_xml => x_report_xml,
            x_error_code => x_error_code);

        IF x_error_code != DMT_UTIL_PKG.C_SUCCESS THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ' failed while ' || l_step
                || ' (detail logged by RUN_BIP_REPORT).',
                p_log_type => 'ERROR', p_package => C_PKG, p_procedure => C_PROC);
            RETURN;
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. CEMLI: ' || C_CEMLI ||
            CASE WHEN x_report_xml IS NULL
                 THEN ' | Report returned zero rows.'
                 ELSE ' | Report data received.'
            END,
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            x_report_xml := NULL;
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed while ' || l_step || ' | CEMLI: ' || C_CEMLI,
                SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
    END FETCH_BIP_RESULTS;

    -- --------------------------------------------------------
    -- PARSE_AND_UPDATE
    -- Positive base-table confirmation only. Each report row is either a set
    -- found in FND_VS_VALUE_SETS (SOURCE_TYPE='SET') or a value found in
    -- FND_VS_VALUES_B (SOURCE_TYPE='VALUE'):
    --   SET   -> LOADED with FUSION_VALUE_SET_ID = the returned VALUE_SET_ID.
    --            RECORD_KEY = VALUE_SET_CODE.
    --   VALUE -> LOADED with FUSION_VALUE_ID = the returned VALUE_ID.
    --            RECORD_KEY = VALUE_SET_CODE || '^' || VALUE.
    -- Rows not returned stay GENERATED; the shared unaccounted sweep marks them
    -- UNACCOUNTED -- never a fabricated verdict or id. Writes the TFM tables
    -- only; no COMMIT (the runner owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id     IN NUMBER,
        p_report_xml IN XMLTYPE
    ) IS
        C_PROC        CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_sets_loaded   NUMBER := 0;
        l_values_loaded NUMBER := 0;
        l_set_code      VARCHAR2(60);
        l_value         VARCHAR2(150);
        l_sep           PLS_INTEGER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        IF p_report_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': report returned zero base-table rows. '
                || 'No fabricated LOADED; rows left GENERATED for the unaccounted sweep.',
                p_log_type => 'WARN', p_package => C_PKG, p_procedure => C_PROC);
            RETURN;
        END IF;

        FOR r IN (
            SELECT x.record_key,
                   UPPER(x.source_type) AS source_type,
                   x.fusion_id
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                COLUMNS
                    record_key  VARCHAR2(300) PATH 'RECORD_KEY',
                    source_type VARCHAR2(20)  PATH 'SOURCE_TYPE',
                    fusion_id   NUMBER        PATH 'FUSION_ID'
            ) x
        ) LOOP
            IF r.fusion_id IS NULL THEN
                CONTINUE;
            END IF;

            IF r.source_type = 'SET' THEN
                -- Positive proof: the set exists in FND_VS_VALUE_SETS.
                -- #160 guard: a set that already carries an error (ERROR_TEXT not
                -- null) is NOT rescued to LOADED by a base-table code collision with a
                -- pre-existing set.
                UPDATE DMT_FND_VS_SET_TFM_TBL
                SET    TFM_STATUS           = 'LOADED',
                       FUSION_VALUE_SET_ID  = r.fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID     = p_run_id
                AND    VALUE_SET_CODE = r.record_key
                AND    TFM_STATUS NOT IN ('LOADED','FAILED')
                AND    ERROR_TEXT IS NULL;
                l_sets_loaded := l_sets_loaded + SQL%ROWCOUNT;

            ELSIF r.source_type = 'VALUE' THEN
                -- Composite RECORD_KEY = VALUE_SET_CODE || '^' || VALUE.
                l_sep := INSTR(r.record_key, '^');
                IF l_sep > 0 THEN
                    l_set_code := SUBSTR(r.record_key, 1, l_sep - 1);
                    l_value    := SUBSTR(r.record_key, l_sep + 1);

                    -- #160 guard: a value that already carries an error is NOT
                    -- rescued to LOADED by a base-table key collision.
                    UPDATE DMT_FND_VS_VALUE_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           FUSION_VALUE_ID      = r.fusion_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID     = p_run_id
                    AND    VALUE_SET_CODE = l_set_code
                    AND    VALUE          = l_value
                    AND    TFM_STATUS NOT IN ('LOADED','FAILED')
                    AND    ERROR_TEXT IS NULL;
                    l_values_loaded := l_values_loaded + SQL%ROWCOUNT;
                END IF;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Base-table confirmed LOADED -- sets: ' || l_sets_loaded
            || ', values: ' || l_values_loaded || '.',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END PARSE_AND_UPDATE;

    -- ============================================================
    -- LOAD_AND_RECONCILE
    -- Main entry point. LOAD via the FBDI zip + ESS upload job (LOAD_VIA_FBDI),
    -- then RECONCILE both objects against the Fusion base tables via the BIP
    -- report (the new standard). No COMMIT until the end (the runner also
    -- commits, but this keeps the two phases in one txn).
    -- ============================================================
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'LOAD_AND_RECONCILE';
        l_set_codes  VARCHAR2(4000);
        l_value_keys VARCHAR2(4000);
        l_xml        XMLTYPE;
        l_err        NUMBER;
        l_sets_loaded    NUMBER;
        l_sets_failed    NUMBER;
        l_sets_unaccnt   NUMBER;
        l_vals_loaded    NUMBER;
        l_vals_failed    NUMBER;
        l_vals_unaccnt   NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        -- Phase 1: LOAD -- submit the one FND_VS FBDI zip via loadAndImportData
        -- (Upload Value Set Values ESS job) and poll it to a terminal state.
        LOAD_VIA_FBDI(p_run_id);

        -- Build the comma-delimited lists of set codes / value keys we loaded and
        -- still need confirmed (every row still GENERATED; the codes are the TFM
        -- keys, so match the base tables on the exact codes).
        SELECT LISTAGG(VALUE_SET_CODE, ',') WITHIN GROUP (ORDER BY VALUE_SET_CODE)
        INTO   l_set_codes
        FROM   DMT_FND_VS_SET_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED';

        SELECT LISTAGG(VALUE_SET_CODE || '^' || VALUE, ',')
                   WITHIN GROUP (ORDER BY VALUE_SET_CODE, VALUE)
        INTO   l_value_keys
        FROM   DMT_FND_VS_VALUE_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED';

        -- Phase 2: RECONCILE -- run the base-table report and confirm.
        FETCH_BIP_RESULTS(
            p_run_id     => p_run_id,
            p_set_codes  => l_set_codes,
            p_value_keys => l_value_keys,
            x_report_xml => l_xml,
            x_error_code => l_err);

        IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
            -- Reconciliation transport failed: raise loudly so the queue work item
            -- fails, never a silent zero-row "success".
            RAISE_APPLICATION_ERROR(-20039,
                'LOAD_AND_RECONCILE: base-table reconciliation report failed for CEMLI '
                || C_CEMLI || ' (detail in DMT_LOG_TBL).');
        END IF;

        PARSE_AND_UPDATE(p_run_id, l_xml);

        -- Rows not confirmed in the base table stay GENERATED. The load step no
        -- longer stashes any error, so there is no in-package FAILED sweep: the
        -- shared unaccounted sweep in DMT_QUEUE_WORKER_PKG marks them UNACCOUNTED.
        -- Nothing is mirrored back to the staging tables, and there is no COMMIT
        -- here: the runner commits.

        SELECT COUNT(CASE WHEN TFM_STATUS = 'LOADED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS = 'FAILED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS NOT IN ('LOADED','FAILED') THEN 1 END)
        INTO   l_sets_loaded, l_sets_failed, l_sets_unaccnt
        FROM   DMT_FND_VS_SET_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        SELECT COUNT(CASE WHEN TFM_STATUS = 'LOADED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS = 'FAILED' THEN 1 END),
               COUNT(CASE WHEN TFM_STATUS NOT IN ('LOADED','FAILED') THEN 1 END)
        INTO   l_vals_loaded, l_vals_failed, l_vals_unaccnt
        FROM   DMT_FND_VS_VALUE_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Sets -- LOADED: ' || l_sets_loaded
            || ', FAILED: ' || l_sets_failed || ', UNACCOUNTED: ' || l_sets_unaccnt
            || ' | Values -- LOADED: ' || l_vals_loaded
            || ', FAILED: ' || l_vals_failed || ', UNACCOUNTED: ' || l_vals_unaccnt || '.',
            p_package => C_PKG, p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END LOAD_AND_RECONCILE;

END DMT_FND_VS_RESULTS_PKG;
/
