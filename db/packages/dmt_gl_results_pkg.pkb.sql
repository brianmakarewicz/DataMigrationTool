-- PACKAGE BODY DMT_GL_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GL_RESULTS_PKG" AS
-- ============================================================
-- DMT_GL_RESULTS_PKG body
-- GL Balances BIP reconciliation - Two-Tier pattern.
-- Tier 1: GL_INTERFACE (INTERFACE rows: status P = LOADED, else FAILED)
-- Tier 2: GL_JE_HEADERS/GL_JE_LINES (BASE rows, positive confirmation)
-- No absence=LOADED fallback. Every row gets positive verification
-- or is marked FAILED with a reconciliation error.
--
-- Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no private
-- UTL_HTTP copy). Outcomes are written to the TFM table only; nothing
-- is written back to staging (design section 2: STG_STATUS is terminal
-- from staging's point of view - the TFM row records the Fusion outcome).
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_GL_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'GLBalances';

    -- --------------------------------------------------------
    -- FETCH_BIP_RESULTS
    -- Delegates to DMT_UTIL_PKG.RUN_BIP_REPORT with the CEMLI's
    -- registered report and the Contract v1 parameters (design
    -- section 5): P_RUN_ID, P_LOAD_REQUEST_ID (the load ESS request id),
    -- P_IMPORT_ESS_ID and P_PREFIX (from DMT_PIPELINE_RUN_TBL).
    -- PROCEDURE per the section 7 procedures-only contract:
    -- x_report_xml NULL with x_error_code = C_SUCCESS = zero rows;
    -- failures are logged here and reported via x_error_code -
    -- exceptions never escape.
    -- --------------------------------------------------------
    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id        IN  NUMBER,
        p_load_ess_id   IN  NUMBER,
        x_report_xml    OUT XMLTYPE,
        x_error_code    OUT NUMBER,
        p_import_ess_id IN  NUMBER DEFAULT NULL
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'FETCH_BIP_RESULTS';
        l_step   VARCHAR2(500);
        l_prefix VARCHAR2(20);
    BEGIN
        x_report_xml := NULL;
        x_error_code := DMT_UTIL_PKG.C_ERROR;   -- pessimistic until proven

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' start. CEMLI: ' || C_CEMLI ||
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
                p_message => C_PROC || ' failed while ' || l_step ||
                             ' (detail logged by RUN_BIP_REPORT).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_ERROR,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RETURN;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' complete. CEMLI: ' || C_CEMLI ||
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
                p_message => C_PROC || ' failed while ' || l_step ||
                             ' | CEMLI: ' || C_CEMLI,
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
    END FETCH_BIP_RESULTS;

    -- --------------------------------------------------------
    -- PARSE_AND_UPDATE - Two-tier reconciliation, no absence=LOADED.
    -- BASE rows = LOADED (positively confirmed in GL_JE_HEADERS/LINES).
    -- INTERFACE rows = FAILED (still in GL_INTERFACE) unless status P.
    -- Remaining GENERATED = FAILED (not reconciled).
    -- Writes the TFM table only; nothing is written back to staging.
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id     IN NUMBER,
        p_report_xml IN XMLTYPE
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_loaded     NUMBER := 0;
        l_failed     NUMBER := 0;
        l_not_recon  NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' start.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

        -- NULL report = BIP returned 0 rows from both tiers. Positive
        -- verification is impossible, so every GENERATED row is FAILED
        -- (no absence=LOADED).
        IF p_report_xml IS NULL THEN
            UPDATE DMT_OWNER.DMT_GL_INTERFACE_TFM_TBL
            SET    TFM_STATUS           = 'FAILED',
                   ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows from both interface and base tables. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE,
                   LAST_UPDATED_DATE    = SYSDATE
            WHERE  RUN_ID     = p_run_id
            AND    TFM_STATUS = 'GENERATED';
            l_not_recon := SQL%ROWCOUNT;
            DMT_UTIL_PKG.LOG(
                p_run_id  => p_run_id,
                p_message => C_PROC || ': BIP report returned zero rows. ' ||
                             l_not_recon || ' GENERATED rows marked FAILED (not reconciled).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RETURN;
        END IF;

        -- Two-tier reconciliation over the decoded report rows.
        FOR r IN (
            SELECT x.record_key,
                   UPPER(x.source_type)    AS source_type,
                   UPPER(x.import_status)  AS import_status,
                   x.fusion_id,
                   x.error_msg
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                COLUMNS
                    record_key      VARCHAR2(100)  PATH 'RECORD_KEY',
                    import_status   VARCHAR2(50)   PATH 'IMPORT_STATUS',
                    source_type     VARCHAR2(20)   PATH 'SOURCE_TYPE',
                    fusion_id       NUMBER         PATH 'FUSION_ID',
                    error_msg       VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
        ) LOOP
            IF r.source_type = 'BASE' THEN
                -- Tier 2: positively confirmed in GL_JE_HEADERS. A journal is only a
                -- genuine load if it is BALANCED (DR=CR) and therefore postable; an
                -- imported-but-unbalanced journal will never post, so it is FAILED with
                -- the balance error (the BAD regression row lands here).
                IF r.import_status = 'SUCCESS' THEN
                    UPDATE DMT_OWNER.DMT_GL_INTERFACE_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           FUSION_JE_HEADER_ID  = r.fusion_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID     = p_run_id
                    AND    RECON_KEY = r.record_key
                    AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSE
                    -- UNBALANCED (or any non-SUCCESS base status) = FAILED
                    UPDATE DMT_OWNER.DMT_GL_INTERFACE_TFM_TBL
                    SET    TFM_STATUS           = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                    '[FUSION_ERROR] ' || NVL(r.error_msg,
                                                      'Journal imported but not postable (unbalanced).')),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID     = p_run_id
                    AND    RECON_KEY = r.record_key
                    AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;

            ELSIF r.source_type = 'INTERFACE' THEN
                -- Tier 1: GL_INTERFACE status interpretation:
                --   P = Processed (success - journal created, row awaiting purge)
                --   NEW = Not yet processed by JournalImport
                --   E/EFxx = Error (rejected by Fusion)
                IF r.import_status = 'P' THEN
                    UPDATE DMT_OWNER.DMT_GL_INTERFACE_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           FUSION_JE_HEADER_ID  = r.fusion_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID     = p_run_id
                    AND    RECON_KEY = r.record_key
                    AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSE
                    -- Any other status (NEW, E, EFxx) = FAILED
                    UPDATE DMT_OWNER.DMT_GL_INTERFACE_TFM_TBL
                    SET    TFM_STATUS           = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                     '[FUSION_ERROR] Journal not imported. GL_INTERFACE status: ' || r.import_status
                                                     || CASE WHEN r.error_msg IS NOT NULL THEN ' - ' || r.error_msg END),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID     = p_run_id
                    AND    RECON_KEY = r.record_key
                    AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END IF;
        END LOOP;

        -- (The absence != LOADED catch-all now lives in the standard
        -- SWEEP_UNACCOUNTED procedure, called at the end of RECONCILE_BATCH — §7.)

        -- NO write-back to staging: the TFM row is the sole record of the Fusion
        -- outcome (design section 2 STG_STATUS - terminal from staging's point of
        -- view). NO COMMIT - the orchestrator controls transaction boundaries.

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' complete. GLBalances LOADED: ' || l_loaded ||
                         ', FAILED: ' || l_failed ||
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
    -- SWEEP_UNACCOUNTED — STANDARD RECONCILE-ERROR SWEEP.
    -- Absence != LOADED (Rule #1): after reconciliation, any TFM row still
    -- not resolved to LOADED or FAILED reached neither the Fusion base table
    -- nor the interface, so its outcome cannot be verified. Mark it FAILED
    -- with a reportable [RECONCILE_ERROR] so no row silently passes.
    --
    -- STANDARD PROCEDURE (design §7): every reconciler package defines
    -- SWEEP_UNACCOUNTED with this EXACT name and signature and calls it at the
    -- end of RECONCILE_BATCH. Only the TFM table name(s) and the descriptive
    -- [RECONCILE_ERROR] message text may differ between packages. It does NOT
    -- commit — the caller (RECONCILE_BATCH) owns the transaction and commits.
    -- ============================================================
    PROCEDURE SWEEP_UNACCOUNTED (p_run_id IN NUMBER, p_work_queue_id IN NUMBER DEFAULT NULL) IS
    BEGIN
        -- <<EDIT-TABLE — CHANGE BELOW: the object's TFM table name. Repeat this
        --   whole UPDATE block (EDIT-TABLE through the ';') once per TFM table
        --   the object owns.>>
        UPDATE DMT_OWNER.DMT_GL_INTERFACE_TFM_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-MSG>>
        SET    TFM_STATUS           = 'FAILED',
               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
        -- <<EDIT-MSG — CHANGE BELOW: the message text. It MUST begin with the
        --   literal '[RECONCILE_ERROR] ' tag.>>
                   '[RECONCILE_ERROR] GL journal line not confirmed in Fusion '
                   || '(not found in GL_JE_HEADERS / GL_JE_LINES for this run) after '
                   || 'reconciliation; its import outcome could not be verified.'
        -- <<END EDIT-MSG — everything below is FIXED until EDIT-SCOPE>>
               ),
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID     = p_run_id
        AND    TFM_STATUS NOT IN ('LOADED','FAILED')
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)  -- work-queue-ID core: sweep only this item's rows
        -- (EDIT-SCOPE deleted — DMT_GL_INTERFACE_TFM_TBL is not shared.)
        ;
    END SWEEP_UNACCOUNTED;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH - orchestrates FETCH then PARSE.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
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
            -- Route the failure: RECONCILE_BATCH's contract with the queue engine
            -- (invoke_registered) is exception-based, so a fetch failure raises and
            -- the work item fails loudly - never a silent zero-row "success"
            -- (design section 5).
            RAISE_APPLICATION_ERROR(-20038,
                'RECONCILE_BATCH: FETCH_BIP_RESULTS failed for CEMLI ' ||
                C_CEMLI || ' (detail in DMT_LOG_TBL).');
        END IF;

        PARSE_AND_UPDATE(p_run_id, l_xml);

        -- Standard final step: fail any row still unaccounted (absence != LOADED).
        SWEEP_UNACCOUNTED(p_run_id, p_work_queue_id);

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

END DMT_GL_RESULTS_PKG;
/
