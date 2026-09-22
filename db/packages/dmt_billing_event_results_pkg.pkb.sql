-- PACKAGE BODY DMT_BILLING_EVENT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BILLING_EVENT_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_BILLING_EVENT_RESULTS_PKG body
-- Billing Events reconciliation — Three-Tier pattern.
--
-- Tier 1: BIP query on PJB_BILLING_EVENTS_INT (interface table)
--         Always purged after import — will rarely return rows.
-- Tier 2: BIP query on PJB_BILLING_EVENTS (base table)
--         Catches successfully LOADED rows via prefix-based SOURCEREF match.
-- Tier 3: Import Report XML from ImportBillingEventReportJob ESS output.
--         Contains G_6 (full interface snapshot per row) + G_7 (per-row errors).
--         Primary error source since interface table is always purged.
--
-- Flow:
--   1. Run BIP two-tier (Tier 1+2). Tier 2 catches successes.
--   2. For remaining GENERATED rows, find the Report child ESS job.
--   3. Download Import Report XML via GET_ESS_OUTPUT_XML.
--   4. Parse G_6 + G_7: match SOURCEREF → TFM, mark LOADED or FAILED.
--   5. Sweep: remaining GENERATED → FAILED with RECONCILE_ERROR.
--   6. Echo outcomes to STG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_BILLING_EVENT_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'BillingEvents';

    -- --------------------------------------------------------
    -- (bip_soap_post + FETCH_BIP_RESULTS removed — the BIP runReport transport
    --  is now the shared DMT_UTIL_PKG.RUN_BIP_REPORT, called from RECONCILE_BATCH.
    --  It builds the same v2 runReport envelope, posts it, checks the SOAP fault,
    --  extracts <reportBytes> and decodes any size, returning the parsed XMLTYPE.
    --  b64_to_clob was already centralised in DMT_UTIL_PKG.BASE64_DECODE_CLOB.)

    -- --------------------------------------------------------
    -- Private: Find the ImportBillingEventReportJob child ESS ID.
    -- Delegates to DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB which
    -- looks up the exact job definition from DMT_ERP_INTERFACE_OPTIONS_TBL.
    -- Used as fallback when the loader didn't capture it (manual/one-off calls).
    -- Returns NULL if not found.
    -- --------------------------------------------------------
    FUNCTION find_report_ess_id (
        p_run_id IN NUMBER,
        p_import_ess_id  IN NUMBER
    ) RETURN NUMBER IS
        C_PROC CONSTANT VARCHAR2(30) := 'find_report_ess_id';
        l_result NUMBER;
    BEGIN
        -- First check if already captured in the hierarchy
        BEGIN
            SELECT REQUEST_ID INTO l_result
            FROM   DMT_ESS_JOB_TBL
            WHERE  PARENT_REQUEST_ID = p_import_ess_id
            AND    UPPER(JOB_DEFINITION) LIKE '%REPORT%'
            FETCH FIRST 1 ROW ONLY;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_result := NULL;
        END;

        IF l_result IS NOT NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': Found report ESS ' || l_result ||
                                    ' in hierarchy (child of import ' || p_import_ess_id || ')',
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN l_result;
        END IF;

        -- Not in hierarchy yet — capture it now
        l_result := DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB(
            p_run_id => p_run_id,
            p_import_ess_id  => p_import_ess_id,
            p_cemli_code     => C_CEMLI);

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ': Report ESS ID = ' || NVL(TO_CHAR(l_result), 'NULL') ||
                                ' (captured from import ESS ' || p_import_ess_id || ')',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        RETURN l_result;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': Failed to find Report child ESS: ' || SQLERRM,
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN NULL;
    END find_report_ess_id;

    -- --------------------------------------------------------
    -- Private: Parse Import Report XML (G_6 + G_7) and update TFM rows.
    -- Returns the number of TFM rows matched.
    --
    -- XML structure (from ImportBillingEventReportJob output):
    --   G_6: one per interface row — SOURCEREF, IMPORT_STATUS, all FBDI columns
    --   G_7: nested under G_6 — per-row error codes and messages
    -- --------------------------------------------------------
    FUNCTION parse_import_report (
        p_run_id IN NUMBER,
        p_report_xml     IN CLOB
    ) RETURN NUMBER IS
        C_PROC     CONSTANT VARCHAR2(30) := 'parse_import_report';
        l_xml      XMLTYPE;
        l_loaded   NUMBER := 0;
        l_failed   NUMBER := 0;
        l_err_msgs VARCHAR2(4000);
    BEGIN
        IF p_report_xml IS NULL OR DBMS_LOB.GETLENGTH(p_report_xml) = 0 THEN
            RETURN 0;
        END IF;

        BEGIN
            l_xml := XMLTYPE(p_report_xml);
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(
                    p_run_id => p_run_id,
                    p_message        => C_PROC || ': Failed to parse Import Report XML: ' || SQLERRM,
                    p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                    p_package        => C_PKG,
                    p_procedure      => C_PROC);
                RETURN 0;
        END;

        -- Process G_6 rows (one per interface record)
        FOR r IN (
            SELECT x.sourceref,
                   UPPER(x.import_status) AS import_status,
                   x.int_rec_id,
                   x.project_number,
                   x.contract_number,
                   x.g6_xml
            FROM   XMLTABLE('/DATA_DS/G_6' PASSING l_xml
                COLUMNS
                    sourceref       VARCHAR2(240)  PATH 'SOURCEREF',
                    import_status   VARCHAR2(50)   PATH 'IMPORT_STATUS',
                    int_rec_id      NUMBER         PATH 'INT_REC_ID',
                    project_number  VARCHAR2(25)   PATH 'PROJECT_NUMBER',
                    contract_number VARCHAR2(120)  PATH 'CONTRACT_NUMBER',
                    g6_xml          XMLTYPE        PATH '.'
            ) x
        ) LOOP
            -- Aggregate G_7 error messages for this row
            l_err_msgs := NULL;
            BEGIN
                FOR e IN (
                    SELECT y.error_code,
                           y.message_text
                    FROM   XMLTABLE('/G_6/G_7' PASSING r.g6_xml
                        COLUMNS
                            error_code   VARCHAR2(100)  PATH 'ERROR_CODE_S3',
                            message_text VARCHAR2(2000) PATH 'MESSAGE_TEXT_S3'
                    ) y
                ) LOOP
                    IF l_err_msgs IS NOT NULL THEN
                        l_err_msgs := l_err_msgs || ' | ';
                    END IF;
                    l_err_msgs := SUBSTR(l_err_msgs || NVL(e.error_code, '') || ': ' || NVL(e.message_text, ''), 1, 4000);
                END LOOP;
            EXCEPTION
                WHEN OTHERS THEN NULL; -- no G_7 children — not an error
            END;

            IF r.sourceref IS NULL THEN
                CONTINUE;
            END IF;

            IF r.import_status IN ('ERROR', 'REJECTED', 'FAILED', 'FAILURE', 'N') THEN
                -- Only mark FAILED when the Import Report actually returned per-row
                -- error text (l_err_msgs, from G_7 ERROR_CODE/MESSAGE_TEXT). When the
                -- report gives an ERROR status but no message, we have no real Fusion
                -- error to write: leave the row GENERATED for the honest sweep to
                -- mark UNACCOUNTED.
                IF l_err_msgs IS NOT NULL THEN
                    UPDATE DMT_PJB_BILL_EVENTS_TFM_TBL
                    SET    TFM_STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                               '[FUSION_ERROR] ' || l_err_msgs),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    SOURCEREF            = r.sourceref
                    AND    TFM_STATUS              NOT IN ('LOADED', 'FAILED');
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;

            ELSIF r.import_status IN ('COMPLETE', 'COMPLETED', 'IMPORTED', 'Y', 'PROCESSED', 'SUCCESS', 'P') THEN
                -- Backlog #11: the Import Report is a per-row STATUS carrier only --
                -- its G_6 row has SOURCEREF and INT_REC_ID but NOT the base EVENT_ID.
                -- A billing event that truly loaded IS in PJB_BILLING_EVENTS with an
                -- EVENT_ID, and the Contract v1 BASE tier (APPLY_CONTRACT_V1_BILLING
                -- _EVENTS, which runs FIRST on the same SOURCEREF key) already marked
                -- it LOADED and stamped FUSION_EVENT_ID = PJB_BILLING_EVENTS.EVENT_ID
                -- (verified live 2026-09-21: SOURCEREF 15949RT-BE-G1 -> EVENT_ID
                -- 100002547480454). So a row still not LOADED here is NOT in the base
                -- table; marking it LOADED on an import status alone -- with no base
                -- id -- would be a fabricated verdict that violates the base-table
                -- rule (LOADED only with a real base-table row and its Fusion id).
                -- The former fabricated-LOADED path is therefore removed: such a row
                -- is left GENERATED for the honest sweep (UNACCOUNTED, a real defect
                -- to chase), never a made-up LOADED. Error harvesting below is
                -- unchanged (real Fusion errors are still recorded).
                NULL;

            ELSE
                -- Unknown import status. If the Import Report carried real per-row
                -- error text (l_err_msgs, from G_7), that is a genuine Fusion error
                -- and we record it; otherwise we have only a composed status label,
                -- so leave the row GENERATED for the honest sweep to mark UNACCOUNTED.
                IF l_err_msgs IS NOT NULL THEN
                    UPDATE DMT_PJB_BILL_EVENTS_TFM_TBL
                    SET    TFM_STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                               '[FUSION_ERROR] ' || l_err_msgs),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    SOURCEREF            = r.sourceref
                    AND    TFM_STATUS              NOT IN ('LOADED', 'FAILED');
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. From Import Report: LOADED=' || l_loaded ||
                                ', FAILED=' || l_failed,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        RETURN l_loaded + l_failed;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => C_PROC || ' failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN 0;
    END parse_import_report;

    -- --------------------------------------------------------
    -- PARSE_AND_UPDATE — Three-tier reconciliation
    -- Receives the already-decoded BIP report XMLTYPE (NULL when the report
    -- returned no <reportBytes>, i.e. zero rows) from the shared transport
    -- DMT_UTIL_PKG.RUN_BIP_REPORT, called in RECONCILE_BATCH.
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml            IN XMLTYPE,
        p_import_ess_id  IN NUMBER DEFAULT NULL
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_xml        XMLTYPE := p_xml;
        l_loaded     NUMBER := 0;
        l_failed     NUMBER := 0;
        l_not_recon  NUMBER := 0;
        l_ir_matched NUMBER := 0;
        l_still_gen  NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- ====================================================
        -- PHASE 1: BIP Two-Tier (Tier 1 = interface, Tier 2 = base table)
        -- ====================================================
        -- l_xml is the decoded BIP report XMLTYPE from RUN_BIP_REPORT (NULL when
        -- the report returned no <reportBytes>, i.e. zero rows from both tiers).
        IF l_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': No <reportBytes> in BIP response. BIP returned 0 rows from both tiers.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            GOTO import_report_fallback;
        END IF;

        -- Process rows from BIP XML — two-tier reconciliation
        FOR r IN (
            SELECT x.sourceref,
                   x.project_number,
                   x.task_number,
                   UPPER(x.source_type)   AS source_type,
                   UPPER(x.fusion_status) AS fusion_status,
                   x.fusion_id,
                   x.error_msg
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                COLUMNS
                    sourceref       VARCHAR2(240)  PATH 'SOURCEREF',
                    project_number  VARCHAR2(25)   PATH 'PROJECT_NUMBER',
                    task_number     VARCHAR2(100)  PATH 'TASK_NUMBER',
                    source_type     VARCHAR2(20)   PATH 'SOURCE_TYPE',
                    fusion_status   VARCHAR2(50)   PATH 'FUSION_STATUS',
                    fusion_id       NUMBER         PATH 'FUSION_ID',
                    error_msg       VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
        ) LOOP
            IF r.source_type = 'BASE' THEN
                -- Tier 2: Found in base table = positively LOADED
                UPDATE DMT_PJB_BILL_EVENTS_TFM_TBL
                SET    TFM_STATUS               = 'LOADED',
                       FUSION_EVENT_ID      = r.fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    SOURCEREF            = r.sourceref
                AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;

            ELSIF r.source_type = 'INTERFACE' THEN
                -- Tier 1: Interface table row — check tfm_status
                IF r.fusion_status IN ('COMPLETE','COMPLETED','IMPORTED','Y','PROCESSED','SUCCESS','P') THEN
                    UPDATE DMT_PJB_BILL_EVENTS_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_EVENT_ID      = r.fusion_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    SOURCEREF            = r.sourceref
                    AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE','N') THEN
                    -- Only mark FAILED when the BIP report carried a real Fusion
                    -- error message (r.error_msg). An error interface status with no
                    -- message gives us no real Fusion error to write: leave the row
                    -- GENERATED for the honest sweep to mark UNACCOUNTED.
                    IF r.error_msg IS NOT NULL THEN
                        UPDATE DMT_PJB_BILL_EVENTS_TFM_TBL
                        SET    TFM_STATUS               = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                         '[FUSION_ERROR] ' || r.error_msg),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID       = p_run_id
                        AND    SOURCEREF            = r.sourceref
                        AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                        l_failed := l_failed + SQL%ROWCOUNT;
                    END IF;
                ELSE
                    -- Unrecognized interface status and no real Fusion error to
                    -- report. Do NOT fabricate a FAILED; leave the row GENERATED for
                    -- the honest sweep to mark UNACCOUNTED.
                    NULL;
                END IF;
            END IF;
        END LOOP;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ': BIP two-tier complete. LOADED=' || l_loaded || ', FAILED=' || l_failed,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- ====================================================
        -- PHASE 2: Import Report XML fallback (Tier 3)
        -- For any GENERATED rows not resolved by BIP, download
        -- the Import Report from the Report child ESS job.
        -- ====================================================
        <<import_report_fallback>>

        SELECT COUNT(*) INTO l_still_gen
        FROM   DMT_PJB_BILL_EVENTS_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS         = 'GENERATED';

        IF l_still_gen > 0 AND p_import_ess_id IS NOT NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': ' || l_still_gen ||
                    ' rows still GENERATED after BIP. Attempting Import Report fallback (import ESS ' ||
                    p_import_ess_id || ').',
                p_package        => C_PKG,
                p_procedure      => C_PROC);

            DECLARE
                l_report_ess_id NUMBER;
                l_ir_xml        CLOB;
            BEGIN
                -- Find the Report child ESS job
                l_report_ess_id := find_report_ess_id(p_run_id, p_import_ess_id);

                IF l_report_ess_id IS NOT NULL THEN
                    -- Download Import Report XML from the Report child job
                    BEGIN
                        l_ir_xml := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(l_report_ess_id);
                    EXCEPTION
                        WHEN OTHERS THEN
                            DMT_UTIL_PKG.LOG(
                                p_run_id => p_run_id,
                                p_message        => C_PROC || ': Failed to download Import Report XML from ESS ' ||
                                    l_report_ess_id || ': ' || SQLERRM,
                                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                                p_package        => C_PKG,
                                p_procedure      => C_PROC);
                            l_ir_xml := NULL;
                    END;

                    IF l_ir_xml IS NOT NULL AND DBMS_LOB.GETLENGTH(l_ir_xml) > 0 THEN
                        l_ir_matched := parse_import_report(p_run_id, l_ir_xml);

                        DMT_UTIL_PKG.LOG(
                            p_run_id => p_run_id,
                            p_message        => C_PROC || ': Import Report parsed. ' || l_ir_matched ||
                                ' TFM rows matched from Report ESS ' || l_report_ess_id || '.',
                            p_package        => C_PKG,
                            p_procedure      => C_PROC);

                        IF DBMS_LOB.ISTEMPORARY(l_ir_xml) = 1 THEN
                            DBMS_LOB.FREETEMPORARY(l_ir_xml);
                        END IF;
                    ELSE
                        DMT_UTIL_PKG.LOG(
                            p_run_id => p_run_id,
                            p_message        => C_PROC || ': Import Report XML is empty from ESS ' || l_report_ess_id,
                            p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                            p_package        => C_PKG,
                            p_procedure      => C_PROC);
                    END IF;
                ELSE
                    DMT_UTIL_PKG.LOG(
                        p_run_id => p_run_id,
                        p_message        => C_PROC || ': Report child ESS job not found. Cannot retrieve Import Report.',
                        p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                        p_package        => C_PKG,
                        p_procedure      => C_PROC);
                END IF;
            END;
        END IF;

        -- (No absence-!=-LOADED sweep: a record neither confirmed LOADED nor
        -- given a real Fusion error is left GENERATED (unaccounted). The
        -- accounting gate then reports the object not-DONE and the funnel
        -- surfaces it as UNRECONCILED — no fabricated FAILED.)
        l_not_recon := 0;

        -- ====================================================
        -- Echo outcomes back to STG
        -- ====================================================
        UPDATE DMT_PJB_BILL_EVENTS_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_PJB_BILL_EVENTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_PJB_BILL_EVENTS_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_PJB_BILL_EVENTS_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_PJB_BILL_EVENTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- NO COMMIT — orchestrator controls transaction boundaries

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. BillingEvents LOADED: ' || l_loaded ||
                                ', FAILED: ' || l_failed ||
                                ', IMPORT_REPORT_MATCHED: ' || l_ir_matched ||
                                ', NOT_RECONCILED: ' || l_not_recon || '.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => C_PROC || ' failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END PARSE_AND_UPDATE;

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_BILLING_EVENTS (private)
    -- The Contract v1 base-tier positive proof for BillingEvents — the SINGLE-TIER
    -- FBDI template (design section 5, Option A shape; copies the Expenditures
    -- template from PR #363 and the Worker template DMT_WORKER_RESULTS_PKG).
    --
    -- The shared package DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the BillingEvents
    -- nine-column recon report over BIP (keyset paged, run-prefix scoped) and
    -- returns the parsed rows — no dynamic SQL, no TFM reference there. The APPLY
    -- here is STATIC SQL against the compile-time-known BillingEvents TFM table:
    --   * BASE / SUCCESS / FUSION_ID NOT NULL  -> LOADED, stamp FUSION_ID into
    --       FUSION_EVENT_ID. The ONLY path to LOADED.
    --   * FUSION_STATUS = ERROR with a non-null ERROR_MESSAGE -> FAILED, message
    --       appended as '[FUSION_ERROR] ' || message (never composed).
    --   * everything else left for the existing import-report harvest and the
    --       shared unaccounted sweep.
    -- Match is on RECON_KEY = the report's RECORD_KEY (both are the run-prefixed
    -- SOURCEREF — see the transform's RECON_KEY stamp). Rows already terminal
    -- (LOADED/FAILED) are never touched, so this runs safely alongside the
    -- existing PARSE_AND_UPDATE path without double-counting.
    --
    -- SPECIAL / no-carrier case (verified live): PJB_BILLING_EVENTS_INT is ALWAYS
    -- purged after import and has no error-text column, so the DM's INTERFACE tier
    -- emits ERROR_MESSAGE = the literal marker '#IMPORT_REPORT#' for a rejected
    -- row. That marker is a non-null message, so this APPLY correctly marks the
    -- row FAILED with '[FUSION_ERROR] #IMPORT_REPORT#' — the same treatment as any
    -- ERROR. The REAL per-row Fusion text is supplied by the import-report harvest
    -- in PARSE_AND_UPDATE (Tier 3), which appends to ERROR_TEXT. We do not
    -- fabricate the text here; we honestly record that Fusion rejected the row and
    -- defer to the report harvest for the human-readable reason.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_BILLING_EVENTS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_BILLING_EVENTS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
    BEGIN
        -- Generated-row count (static, this object's own table) drives the shared
        -- fetch's keyset page-count cap.
        SELECT COUNT(*) INTO l_gen_count
        FROM   DMT_PJB_BILL_EVENTS_TFM_TBL
        WHERE  RUN_ID = p_run_id;

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
            RAISE_APPLICATION_ERROR(-20096,
                'APPLY_CONTRACT_V1_BILLING_EVENTS: Contract v1 fetch failed for '
                || 'BillingEvents (detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the import-report harvest / unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': BillingEvents recon report returned zero rows; '
                               || 'GENERATED rows left for the import-report harvest '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                IF l_rows(i).SOURCE_TYPE = 'BASE'
                   AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                   AND l_rows(i).FUSION_ID IS NOT NULL THEN
                    -- Positive proof: event found in PJB_BILLING_EVENTS with a real
                    -- id. The ONLY path to LOADED. Static UPDATE keyed on RECON_KEY.
                    UPDATE DMT_PJB_BILL_EVENTS_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           FUSION_EVENT_ID      = l_rows(i).FUSION_ID,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    RECON_KEY = l_rows(i).RECORD_KEY
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_loaded := l_loaded + SQL%ROWCOUNT;

                ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                      AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                    -- A Fusion error -> FAILED on the exact message (never composed).
                    -- For BillingEvents this message is normally the '#IMPORT_REPORT#'
                    -- marker (interface purged, no carrier): still a genuine FAILED,
                    -- with the real text supplied later by the import-report harvest.
                    -- Static UPDATE keyed on RECON_KEY.
                    UPDATE DMT_PJB_BILL_EVENTS_TFM_TBL
                    SET    TFM_STATUS           = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                    ERROR_TEXT,
                                                    '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    RECON_KEY = l_rows(i).RECORD_KEY
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_failed := l_failed + SQL%ROWCOUNT;

                ELSE
                    -- INTERFACE/SUCCESS (corroborating, never sufficient) or a
                    -- non-terminal status with no real error: leave the row for the
                    -- import-report harvest / unaccounted sweep. Never fabricate.
                    NULL;
                END IF;
            END LOOP;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | LOADED: ' || l_loaded
                           || ' | FAILED: ' || l_failed || '.',
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
    END APPLY_CONTRACT_V1_BILLING_EVENTS;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
        l_xml       XMLTYPE;
        l_err_code  NUMBER;
        l_prefix    VARCHAR2(30);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. load_ess_id: ' || p_load_ess_id ||
                                ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Contract v1 base-tier positive proof (single-tier FBDI template): the
        -- shared fetch returns the nine-column recon report rows and the APPLY is
        -- STATIC SQL against this object's TFM table, keyed on RECON_KEY. This is
        -- the ONLY path to LOADED (a real base-table row). It runs FIRST so a
        -- genuinely-costed row is confirmed before the interface/import-report
        -- harvest below looks at what is left. Rows already terminal are untouched.
        -- The load ESS id feeds the report's LOAD_REQUEST_ID; run-scoped row
        -- selection is by the stamped prefix (see the DM header). ERROR rows carry
        -- the '#IMPORT_REPORT#' marker as a genuine FAILED here; the real per-row
        -- text is harvested from the import report XML by PARSE_AND_UPDATE (Tier 3).
        APPLY_CONTRACT_V1_BILLING_EVENTS(
            p_run_id     => p_run_id,
            p_request_id => TO_CHAR(NVL(p_import_ess_id, p_load_ess_id)));

        -- Prefix for the report's Tier 2 base-table match (P_PREFIX).
        BEGIN
            SELECT PREFIX INTO l_prefix
            FROM   DMT_PIPELINE_RUN_TBL
            WHERE  RUN_ID = p_run_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_prefix := NULL;
        END;

        -- Shared transport: builds the runReport envelope, posts, checks the SOAP
        -- fault, decodes <reportBytes> and returns the parsed XMLTYPE (NULL on zero
        -- rows). On transport/SOAP failure it returns NULL with C_ERROR — raise so
        -- the failure is loud (as the old FETCH_BIP_RESULTS raised), never a silent
        -- zero-row "success".
        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id     => p_run_id,
            p_cemli_code => C_CEMLI,
            p_params     => 'P_BATCH_ID|' || TO_CHAR(p_load_ess_id) ||
                            '~P_IMPORT_ESS_ID|' || NVL(TO_CHAR(p_import_ess_id), '') ||
                            '~P_PREFIX|' || NVL(l_prefix, ''),
            x_report_xml => l_xml,
            x_error_code => l_err_code);

        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20034,
                C_PROC || ': BIP runReport fetch failed for ' || C_CEMLI ||
                ' (detail in DMT_LOG_TBL).');
        END IF;

        PARSE_AND_UPDATE(p_run_id, l_xml, p_import_ess_id);

        -- Unresolved records intentionally left GENERATED (unaccounted).
        -- No fabricated FAILED: the accounting gate reports the object
        -- not-DONE and the funnel surfaces these as UNRECONCILED.

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => C_PROC || ' failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END RECONCILE_BATCH;

END DMT_BILLING_EVENT_RESULTS_PKG;
/
