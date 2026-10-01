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
--         poll the upload ESS job. A SUCCEEDED/WARNING load does NOT mark any
--         row terminal — rows stay GENERATED for the base-table report to
--         confirm. A non-terminal/ERROR load is a genuine Fusion rejection: its
--         real ESS status is STASHED into ERROR_TEXT (accumulate, never
--         overwrite) on every GENERATED row so the post-reconcile sweep marks
--         them FAILED on that real error. A transport exception is re-raised so
--         the work item fails loudly.
--
--   RECONCILE (FETCH_BIP_RESULTS + PARSE_AND_UPDATE): run the base-table
--         report DMT_VS_RECON_RPT over this run's set codes and value keys.
--         A set found in FND_VS_VALUE_SETS -> LOADED with
--         FUSION_VALUE_SET_ID = VALUE_SET_ID. A value found in
--         FND_VS_VALUES_B  -> LOADED with FUSION_VALUE_ID = VALUE_ID (the
--         real surrogate ids). Rows not returned stay as the load step set
--         them: FAILED if the load stashed a real error, else left
--         GENERATED (unaccounted) -- never a fabricated LOADED or id.
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

    -- ============================================================
    -- LOAD_VIA_FBDI
    -- The LOAD step: submit the one generated FND_VS FBDI zip to Fusion via the
    -- shared loadAndImportData path (DMT_LOADER_PKG.SUBMIT_LOAD) and poll the
    -- upload ESS job to a terminal state. The BIP base-table report -- not the
    -- ESS status -- is the authority for LOADED, so a SUCCEEDED/WARNING load
    -- leaves every row GENERATED. A non-terminal/ERROR load stashes its real ESS
    -- status into ERROR_TEXT on every GENERATED set + value row (accumulate,
    -- never overwrite); the post-reconcile sweep then marks those FAILED on the
    -- real error. A transport exception is re-raised. Writes the TFM tables only;
    -- no COMMIT (the runner owns the txn).
    -- ============================================================
    PROCEDURE LOAD_VIA_FBDI (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'LOAD_VIA_FBDI';

        l_ucm_account   VARCHAR2(200);
        l_raw_job_name  VARCHAR2(500);
        l_job_name      VARCHAR2(500);
        l_iface_details NUMBER;
        l_user          VARCHAR2(100);
        l_pass          VARCHAR2(100);
        l_zip           BLOB;
        l_filename      VARCHAR2(200);
        l_load_ess_id   VARCHAR2(100);
        l_status        VARCHAR2(50);
        l_sep           PLS_INTEGER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, C_PROC || ' start.', p_package => C_PKG, p_procedure => C_PROC);

        -- ERP options: UCM account, import job name, interface-details id. The
        -- stored IMPORT_JOB_NAME uses ';' between package path and job definition;
        -- loadAndImportData's <erp:JobName> needs ',' -- convert the last ';'.
        BEGIN
            SELECT UCM_ACCOUNT,
                   IMPORT_JOB_NAME,
                   TO_NUMBER(NVL(SOURCE_ERP_OPTIONS_ID, ERP_INTERFACE_OPTIONS_ID))
            INTO   l_ucm_account, l_raw_job_name, l_iface_details
            FROM   DMT_ERP_INTERFACE_OPTIONS_TBL
            WHERE  CEMLI_CODE = C_CEMLI;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20040,
                    'LOAD_VIA_FBDI: No row in DMT_ERP_INTERFACE_OPTIONS_TBL for CEMLI_CODE '''
                    || C_CEMLI || '''. Seed the ValueSets ERP-options row (UCM account + '
                    || 'import job name) before running the pipeline.');
        END;

        l_sep := INSTR(l_raw_job_name, ';', -1);
        IF l_sep > 0 THEN
            l_job_name := SUBSTR(l_raw_job_name, 1, l_sep - 1) || ','
                          || SUBSTR(l_raw_job_name, l_sep + 1);
        ELSE
            l_job_name := l_raw_job_name;
        END IF;

        -- Per-CEMLI Fusion creds (SUBMIT_LOAD falls back to config defaults if NULL).
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(C_CEMLI, l_user, l_pass);

        -- Fetch the generated zip (one FND_VS zip per run, built by the FBL gen pkg).
        BEGIN
            SELECT ZIP_CONTENT, FILENAME
            INTO   l_zip, l_filename
            FROM   DMT_FBDI_ZIP_TBL
            WHERE  RUN_ID = p_run_id
            AND    OBJECT_TYPE = 'FND_VS';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_PROC || ': no FND_VS zip found for this run. Nothing to load.',
                    p_log_type => 'WARN', p_package => C_PKG, p_procedure => C_PROC);
                RETURN;
        END;

        IF l_zip IS NULL OR DBMS_LOB.GETLENGTH(l_zip) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': FND_VS zip is empty. Nothing to load.',
                p_log_type => 'WARN', p_package => C_PKG, p_procedure => C_PROC);
            RETURN;
        END IF;

        -- Submit + poll. A transport failure here is a genuine load error: it is
        -- logged and re-raised so the work item fails loudly and the runner rolls
        -- back. (The per-row ERROR_TEXT stash below is best-effort for the log and
        -- is itself rolled back by that same re-raise -- a transport crash leaves
        -- no committed verdict, which is correct: the item retries from clean.)
        BEGIN
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

            DMT_LOADER_PKG.POLL_ESS_JOB(
                p_run_id         => p_run_id,
                p_ess_job_id     => l_load_ess_id,
                p_timeout_sec    => 1800,
                p_raise_on_error => FALSE,
                p_log_context    => C_CEMLI,
                p_cemli_code     => C_CEMLI,
                x_fusion_status  => l_status,
                p_username       => l_user,
                p_password       => l_pass);
        EXCEPTION
            WHEN OTHERS THEN
                DECLARE
                    l_errmsg VARCHAR2(4000) := SQLERRM;
                BEGIN
                    UPDATE DMT_FND_VS_SET_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] Value-set upload transport failed: ' || l_errmsg),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';

                    UPDATE DMT_FND_VS_VALUE_TFM_TBL
                    SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                          '[FUSION_ERROR] Value-set upload transport failed: ' || l_errmsg),
                           LAST_UPDATED_DATE = SYSDATE
                    WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';

                    DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                        C_PROC || ': loadAndImportData / poll failed (stashed, re-raising).',
                        l_errmsg, p_package => C_PKG, p_procedure => C_PROC);
                    RAISE;
                END;
        END;

        -- Terminal ESS status reached. SUCCEEDED/WARNING -> leave rows GENERATED
        -- for the base-table report to confirm (an ESS success is NOT a per-row
        -- verdict). Anything else -> stash the real status on every GENERATED row
        -- so the post-reconcile sweep marks them FAILED on that real error.
        IF l_status IN (C_STATUS_SUCCEEDED, C_STATUS_WARNING) THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': upload ESS ' || l_load_ess_id || ' returned ' || l_status
                || '. Rows left GENERATED for base-table reconciliation.',
                p_package => C_PKG, p_procedure => C_PROC);
        ELSE
            DECLARE
                l_err VARCHAR2(500) :=
                    '[LOAD_ERROR] Value Set upload ESS ' || l_load_ess_id
                    || ' returned ' || l_status || '. See ESS logs.';
            BEGIN
                UPDATE DMT_FND_VS_SET_TFM_TBL
                SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, l_err),
                       LAST_UPDATED_DATE = SYSDATE
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';

                UPDATE DMT_FND_VS_VALUE_TFM_TBL
                SET    ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, l_err),
                       LAST_UPDATED_DATE = SYSDATE
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';

                DMT_UTIL_PKG.LOG(p_run_id,
                    C_PROC || ': upload ESS ' || l_load_ess_id || ' returned ' || l_status
                    || '. Stashed [LOAD_ERROR] on all GENERATED rows (sweep will FAIL them).',
                    p_log_type => 'WARN', p_package => C_PKG, p_procedure => C_PROC);
            END;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
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
    -- Rows not returned are left as the load step set them (FAILED with a real
    -- load error, else GENERATED/unaccounted) -- never a fabricated verdict or
    -- id. Writes the TFM tables only; no COMMIT (the runner owns the txn).
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
                || 'No fabricated LOADED; rows left as the load step set them.',
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
                UPDATE DMT_FND_VS_SET_TFM_TBL
                SET    TFM_STATUS           = 'LOADED',
                       FUSION_VALUE_SET_ID  = r.fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID     = p_run_id
                AND    VALUE_SET_CODE = r.record_key
                AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                l_sets_loaded := l_sets_loaded + SQL%ROWCOUNT;

            ELSIF r.source_type = 'VALUE' THEN
                -- Composite RECORD_KEY = VALUE_SET_CODE || '^' || VALUE.
                l_sep := INSTR(r.record_key, '^');
                IF l_sep > 0 THEN
                    l_set_code := SUBSTR(r.record_key, 1, l_sep - 1);
                    l_value    := SUBSTR(r.record_key, l_sep + 1);

                    UPDATE DMT_FND_VS_VALUE_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           FUSION_VALUE_ID      = r.fusion_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID     = p_run_id
                    AND    VALUE_SET_CODE = l_set_code
                    AND    VALUE          = l_value
                    AND    TFM_STATUS NOT IN ('LOADED','FAILED');
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
        -- still need confirmed (rows the load step did NOT mark FAILED; config
        -- codes are not run-prefixed, so match the base tables on the exact codes).
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

        -- Post-reconcile sweep: any row NOT confirmed in the base table is still
        -- GENERATED. If the load stashed a real Fusion error in ERROR_TEXT, mark
        -- it FAILED on that real error. A row with no stashed error AND no
        -- base-table hit is left GENERATED (unaccounted); the accounting gate
        -- surfaces it -- we never fabricate a verdict.
        UPDATE DMT_FND_VS_SET_TFM_TBL
        SET    TFM_STATUS           = 'FAILED',
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED'
        AND    ERROR_TEXT IS NOT NULL;

        UPDATE DMT_FND_VS_VALUE_TFM_TBL
        SET    TFM_STATUS           = 'FAILED',
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED'
        AND    ERROR_TEXT IS NOT NULL;

        -- Mirror the terminal TFM outcome onto STG for both objects (STG_STATUS is
        -- terminal from staging's point of view; the TFM row is the record of the
        -- Fusion outcome).
        UPDATE DMT_FND_VS_SET_STG_TBL s
        SET    s.STG_STATUS = (SELECT t.TFM_STATUS
                               FROM   DMT_FND_VS_SET_TFM_TBL t
                               WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                               AND    t.RUN_ID = p_run_id),
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  EXISTS (SELECT 1 FROM DMT_FND_VS_SET_TFM_TBL t
                       WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                       AND    t.RUN_ID = p_run_id
                       AND    t.TFM_STATUS IN ('LOADED','FAILED'));

        UPDATE DMT_FND_VS_VALUE_STG_TBL s
        SET    s.STG_STATUS = (SELECT t.TFM_STATUS
                               FROM   DMT_FND_VS_VALUE_TFM_TBL t
                               WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                               AND    t.RUN_ID = p_run_id),
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  EXISTS (SELECT 1 FROM DMT_FND_VS_VALUE_TFM_TBL t
                       WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                       AND    t.RUN_ID = p_run_id
                       AND    t.TFM_STATUS IN ('LOADED','FAILED'));

        COMMIT;

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
