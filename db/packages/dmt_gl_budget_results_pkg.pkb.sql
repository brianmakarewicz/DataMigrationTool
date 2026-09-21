-- PACKAGE BODY DMT_GL_BUDGET_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GL_BUDGET_RESULTS_PKG" AS
-- ============================================================
-- GL Budget Balances reconciliation (cell-grain, run-start window).
-- See package spec for the reconciliation model.
-- ============================================================
    C_PKG        CONSTANT VARCHAR2(50) := 'DMT_GL_BUDGET_RESULTS_PKG';
    C_CEMLI      CONSTANT VARCHAR2(30) := 'GLBudgets';
    -- Clock-skew buffer applied to run-start so a small ATP<->Fusion time
    -- offset never excludes cells our own run just wrote. Pre-existing budget
    -- data is months old, so a few hours is safe.
    C_SKEW_HOURS CONSTANT NUMBER := 4;
    C_AMT_TOL    CONSTANT NUMBER := 0.01;   -- DR/CR match tolerance

    -- key -> value maps for parsed BIP rows
    TYPE t_num_map IS TABLE OF NUMBER        INDEX BY VARCHAR2(4000);
    TYPE t_str_map IS TABLE OF VARCHAR2(4000) INDEX BY VARCHAR2(4000);

    FUNCTION bip_soap_post (p_url IN VARCHAR2, p_action IN VARCHAR2, p_body IN CLOB) RETURN CLOB IS
        l_req UTL_HTTP.REQ; l_resp UTL_HTTP.RESP; l_response CLOB; l_chunk VARCHAR2(32767);
        l_offset INTEGER := 1; l_amount INTEGER; l_body_len INTEGER;
    BEGIN
        UTL_HTTP.SET_RESPONSE_ERROR_CHECK(FALSE); UTL_HTTP.SET_TRANSFER_TIMEOUT(600);
        l_req := UTL_HTTP.BEGIN_REQUEST(p_url, 'POST', 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_req, 'Content-Type', 'text/xml; charset=utf-8');
        UTL_HTTP.SET_HEADER(l_req, 'Content-Length', DBMS_LOB.GETLENGTH(p_body));
        UTL_HTTP.SET_HEADER(l_req, 'SOAPAction', '"' || p_action || '"');
        UTL_HTTP.SET_HEADER(l_req, 'Accept', 'text/xml');
        l_body_len := DBMS_LOB.GETLENGTH(p_body);
        WHILE l_offset <= l_body_len LOOP
            l_amount := LEAST(8000, l_body_len - l_offset + 1);
            l_chunk := DBMS_LOB.SUBSTR(p_body, l_amount, l_offset);
            UTL_HTTP.WRITE_TEXT(l_req, l_chunk); l_offset := l_offset + l_amount;
        END LOOP;
        l_resp := UTL_HTTP.GET_RESPONSE(l_req);
        DBMS_LOB.CREATETEMPORARY(l_response, TRUE);
        BEGIN LOOP UTL_HTTP.READ_TEXT(l_resp, l_chunk, 32767); DBMS_LOB.APPEND(l_response, l_chunk); END LOOP;
        EXCEPTION WHEN UTL_HTTP.END_OF_BODY THEN NULL; END;
        UTL_HTTP.END_RESPONSE(l_resp);
        IF l_resp.status_code NOT BETWEEN 200 AND 299 THEN
            RAISE_APPLICATION_ERROR(-20030, 'BIP SOAP failed. Status: ' || l_resp.status_code);
        END IF;
        RETURN l_response;
    EXCEPTION WHEN OTHERS THEN BEGIN UTL_HTTP.END_RESPONSE(l_resp); EXCEPTION WHEN OTHERS THEN NULL; END; RAISE;
    END bip_soap_post;

    -- Composite cell key (matches the BIP ACCOUNT_KEY expression's grain).
    FUNCTION cell_key (p_ledger VARCHAR2, p_budget VARCHAR2, p_period VARCHAR2,
                       p_ccy VARCHAR2, p_acct VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN NVL(p_ledger,'#')||CHR(1)||NVL(p_budget,'#')||CHR(1)||NVL(p_period,'#')||CHR(1)||
               NVL(p_ccy,'#')||CHR(1)||NVL(p_acct,'#');
    END cell_key;

    FUNCTION FETCH_BIP_RESULTS (
        p_run_id     IN NUMBER,
        p_run_start  IN TIMESTAMP DEFAULT NULL,
        p_ledger_id  IN NUMBER    DEFAULT NULL
    ) RETURN CLOB IS
        l_base_url  VARCHAR2(500); l_username VARCHAR2(100); l_password VARCHAR2(100);
        l_rpt_path  VARCHAR2(500); l_env CLOB; l_resp CLOB;
        l_run_start VARCHAR2(30); l_ledger VARCHAR2(40);
        l_action CONSTANT VARCHAR2(200) := 'http://xmlns.oracle.com/oxp/service/v2/ReportService/runReportRequest';
    BEGIN
        -- Run-start window (with skew buffer). NULL => last few hours (reconcile
        -- runs immediately after load).
        l_run_start := TO_CHAR(
            NVL(p_run_start, CAST(SYSTIMESTAMP AS TIMESTAMP) - INTERVAL '6' HOUR)
                - NUMTODSINTERVAL(C_SKEW_HOURS,'HOUR'),
            'YYYY-MM-DD HH24:MI:SS');
        l_ledger := CASE WHEN p_ledger_id IS NULL THEN '' ELSE TO_CHAR(p_ledger_id) END;

        DMT_UTIL_PKG.LOG(p_run_id,
            'FETCH_BIP_RESULTS start. run_start>=' || l_run_start ||
            ' ledger=' || NVL(l_ledger,'(all)'), C_PKG, 'FETCH_BIP_RESULTS');

        l_base_url := RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/');
        l_username := DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME');
        l_password := DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD');
        SELECT REPORT_CATALOG_PATH INTO l_rpt_path FROM DMT_BIP_REPORT_TBL WHERE CEMLI_CODE = C_CEMLI;

        DBMS_LOB.CREATETEMPORARY(l_env, TRUE);
        DBMS_LOB.APPEND(l_env, TO_CLOB(
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">' ||
            '<soapenv:Header/><soapenv:Body><v2:runReport><v2:reportRequest>' ||
            '<v2:reportAbsolutePath>' || l_rpt_path || '</v2:reportAbsolutePath>' ||
            '<v2:attributeFormat>xml</v2:attributeFormat>' ||
            '<v2:parameterNameValues><v2:listOfParamNameValues>' ||
            '<v2:item><v2:name>P_RUN_START</v2:name><v2:values><v2:item>' || l_run_start || '</v2:item></v2:values></v2:item>' ||
            '<v2:item><v2:name>P_LEDGER_ID</v2:name><v2:values><v2:item>' || l_ledger || '</v2:item></v2:values></v2:item>' ||
            '</v2:listOfParamNameValues></v2:parameterNameValues>' ||
            '<v2:sizeOfDataChunkDownload>-1</v2:sizeOfDataChunkDownload>' ||
            '</v2:reportRequest><v2:userID>' || l_username || '</v2:userID><v2:password>' || l_password || '</v2:password>' ||
            '</v2:runReport></soapenv:Body></soapenv:Envelope>'));
        l_resp := bip_soap_post(l_base_url || '/xmlpserver/services/v2/ReportService', l_action, l_env);
        DBMS_LOB.FREETEMPORARY(l_env);
        RETURN l_resp;
    EXCEPTION WHEN OTHERS THEN
        DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'FETCH_BIP_RESULTS failed.', SQLERRM, C_PKG, 'FETCH_BIP_RESULTS'); RAISE;
    END FETCH_BIP_RESULTS;

    PROCEDURE PARSE_AND_UPDATE (p_run_id IN NUMBER, p_xml_data IN CLOB) IS
        l_xml     XMLTYPE;
        l_bal_dr  t_num_map;   -- cell_key -> loaded DR
        l_bal_cr  t_num_map;   -- cell_key -> loaded CR
        l_ierr    t_str_map;   -- cell_key -> interface error message
        l_key     VARCHAR2(4000);
        l_loaded  NUMBER := 0; l_failed NUMBER := 0; l_unacc NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'PARSE_AND_UPDATE start.', C_PKG, 'PARSE_AND_UPDATE');
        l_xml := DMT_UTIL_PKG.BIP_REPORT_XML(p_xml_data);
        IF l_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id, 'BIP returned no rows.', DMT_UTIL_PKG.C_LOG_WARN, C_PKG, 'PARSE_AND_UPDATE');
            RETURN;
        END IF;

        -- Load parsed BIP rows into cell-keyed maps.
        FOR r IN (
            SELECT x.rec_type, x.ledger_id, x.budget_name, x.period_name, x.currency_code,
                   x.account_key, x.dr_amount, x.cr_amount, x.error_message
            FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                rec_type      VARCHAR2(10)   PATH 'REC_TYPE',
                ledger_id     VARCHAR2(40)   PATH 'LEDGER_ID',
                budget_name   VARCHAR2(320)  PATH 'BUDGET_NAME',
                period_name   VARCHAR2(60)   PATH 'PERIOD_NAME',
                currency_code VARCHAR2(60)   PATH 'CURRENCY_CODE',
                account_key   VARCHAR2(2000) PATH 'ACCOUNT_KEY',
                dr_amount     NUMBER         PATH 'DR_AMOUNT',
                cr_amount     NUMBER         PATH 'CR_AMOUNT',
                error_message VARCHAR2(2000) PATH 'ERROR_MESSAGE') x
        ) LOOP
            l_key := cell_key(r.ledger_id, r.budget_name, r.period_name, r.currency_code, r.account_key);
            IF r.rec_type = 'BAL' THEN
                l_bal_dr(l_key) := NVL(r.dr_amount, 0);
                l_bal_cr(l_key) := NVL(r.cr_amount, 0);
            ELSIF r.rec_type = 'IFACE' THEN
                -- Only record a REAL Fusion-returned error message. When the
                -- interface row carries no message we have nothing reportable, so
                -- we do NOT compose a placeholder — the cell will fall to the
                -- unaccounted branch below and stay GENERATED for the honest sweep.
                IF r.error_message IS NOT NULL THEN
                    l_ierr(l_key) := SUBSTR(CASE WHEN l_ierr.EXISTS(l_key) THEN l_ierr(l_key) || ' ' END
                                            || r.error_message, 1, 4000);
                END IF;
            END IF;
        END LOOP;

        -- Walk each non-terminal TFM cell for this run and classify it.
        FOR t IN (
            SELECT TFM_SEQUENCE_ID, STG_SEQUENCE_ID, BUDGET_NAME, PERIOD_NAME, CURRENCY_CODE,
                   LEDGER_ID, BUDGET_AMOUNT,
                   NVL(SEGMENT1,'#')||'|'||NVL(SEGMENT2,'#')||'|'||NVL(SEGMENT3,'#')||'|'||
                   NVL(SEGMENT4,'#')||'|'||NVL(SEGMENT5,'#')||'|'||NVL(SEGMENT6,'#')||'|'||
                   NVL(SEGMENT7,'#')||'|'||NVL(SEGMENT8,'#')||'|'||NVL(SEGMENT9,'#')||'|'||
                   NVL(SEGMENT10,'#')||'|'||NVL(SEGMENT11,'#')||'|'||NVL(SEGMENT12,'#')||'|'||
                   NVL(SEGMENT13,'#')||'|'||NVL(SEGMENT14,'#')||'|'||NVL(SEGMENT15,'#')||'|'||
                   NVL(SEGMENT16,'#')||'|'||NVL(SEGMENT17,'#')||'|'||NVL(SEGMENT18,'#')||'|'||
                   NVL(SEGMENT19,'#')||'|'||NVL(SEGMENT20,'#')||'|'||NVL(SEGMENT21,'#')||'|'||
                   NVL(SEGMENT22,'#')||'|'||NVL(SEGMENT23,'#')||'|'||NVL(SEGMENT24,'#')||'|'||
                   NVL(SEGMENT25,'#')||'|'||NVL(SEGMENT26,'#')||'|'||NVL(SEGMENT27,'#')||'|'||
                   NVL(SEGMENT28,'#')||'|'||NVL(SEGMENT29,'#')||'|'||NVL(SEGMENT30,'#') AS account_key
            FROM   DMT_GL_BUDGET_INT_TFM_TBL
            WHERE  RUN_ID = p_run_id AND TFM_STATUS NOT IN ('LOADED','FAILED')
        ) LOOP
            l_key := cell_key(TO_CHAR(t.LEDGER_ID), t.BUDGET_NAME, t.PERIOD_NAME, t.CURRENCY_CODE, t.account_key);

            IF l_bal_dr.EXISTS(l_key) THEN
                -- Base-table cell present since run start = LOADED. Verify DR/CR
                -- (loose positive confirmation); flag amount discrepancy but do
                -- not fail a row that demonstrably reached the base table.
                DECLARE
                    l_exp_dr NUMBER := CASE WHEN NVL(t.BUDGET_AMOUNT,0) >= 0 THEN t.BUDGET_AMOUNT ELSE 0 END;
                    l_exp_cr NUMBER := CASE WHEN NVL(t.BUDGET_AMOUNT,0) <  0 THEN -t.BUDGET_AMOUNT ELSE 0 END;
                    l_note   VARCHAR2(400) := NULL;
                BEGIN
                    IF ABS(NVL(l_bal_dr(l_key),0) - l_exp_dr) > C_AMT_TOL
                       OR ABS(NVL(l_bal_cr(l_key),0) - l_exp_cr) > C_AMT_TOL THEN
                        l_note := '[WARN] Cube amount DR/CR ' || l_bal_dr(l_key) || '/' || l_bal_cr(l_key) ||
                                  ' <> expected ' || l_exp_dr || '/' || l_exp_cr ||
                                  ' (budget cells may aggregate duplicate lines).';
                    END IF;
                    UPDATE DMT_GL_BUDGET_INT_TFM_TBL
                    SET    TFM_STATUS = 'LOADED',
                           ERROR_TEXT = CASE WHEN l_note IS NULL THEN ERROR_TEXT
                                             ELSE DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, l_note) END,
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  TFM_SEQUENCE_ID = t.TFM_SEQUENCE_ID;
                END;
                l_loaded := l_loaded + 1;

            ELSIF l_ierr.EXISTS(l_key) THEN
                -- Row still in the interface with an error = FAILED.
                UPDATE DMT_GL_BUDGET_INT_TFM_TBL
                SET    TFM_STATUS = 'FAILED',
                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, '[FUSION_ERROR] ' || l_ierr(l_key)),
                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                WHERE  TFM_SEQUENCE_ID = t.TFM_SEQUENCE_ID;
                l_failed := l_failed + 1;

            ELSE
                -- Neither loaded nor errored: not accounted. Leave non-terminal
                -- for investigation (object is not DONE per accounting rule).
                l_unacc := l_unacc + 1;
            END IF;
        END LOOP;

        -- Fan cell outcome back to the STG source rows.
        UPDATE DMT_GL_BUDGET_INT_STG_TBL SET STG_STATUS='LOADED', LAST_UPDATED_DATE=SYSDATE
        WHERE STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_GL_BUDGET_INT_TFM_TBL
                                  WHERE RUN_ID=p_run_id AND TFM_STATUS='LOADED');
        UPDATE DMT_GL_BUDGET_INT_STG_TBL SET STG_STATUS='FAILED', LAST_UPDATED_DATE=SYSDATE
        WHERE STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_GL_BUDGET_INT_TFM_TBL
                                  WHERE RUN_ID=p_run_id AND TFM_STATUS='FAILED');

        DMT_UTIL_PKG.LOG(p_run_id,
            'PARSE_AND_UPDATE complete. LOADED: ' || l_loaded || ', FAILED: ' || l_failed ||
            ', UNACCOUNTED: ' || l_unacc, C_PKG, 'PARSE_AND_UPDATE');
        IF l_unacc > 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                l_unacc || ' GL budget cell(s) neither found in GL_BUDGET_BALANCES (since run start) '||
                'nor lingering in GL_BUDGET_INTERFACE. Investigate — object is not DONE.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, 'PARSE_AND_UPDATE');
        END IF;
    EXCEPTION WHEN OTHERS THEN
        DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'PARSE_AND_UPDATE failed.', SQLERRM, C_PKG, 'PARSE_AND_UPDATE'); RAISE;
    END PARSE_AND_UPDATE;

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_GLBUDGETS (private)
    -- The Contract v1 base-tier positive proof for GLBudgets — the SINGLE-TIER
    -- template proven for Expenditures (PR #363). The shared package
    -- DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the GLBudgets nine-column recon
    -- report over BIP (keyset paged, scoped to this run's load request id) and
    -- returns the parsed rows -- no dynamic SQL, no TFM reference there. The APPLY
    -- here is STATIC SQL against the compile-time-known GL Budget TFM table:
    --   * BASE / SUCCESS / FUSION_ID NOT NULL  -> LOADED, stamp FUSION_ID into
    --       FUSION_BUDGET_VERSION_ID. The ONLY path to LOADED.
    --   * FUSION_STATUS = ERROR with a real message -> FAILED, message appended as
    --       '[FUSION_ERROR] ' || message (never composed).
    --   * everything else left for the existing run-start / cell-key harvest
    --       (PARSE_AND_UPDATE) and the shared unaccounted sweep.
    --
    -- GLBudgets is structurally unlike a transaction object (budgets are CELLS):
    -- GL_BUDGET_BALANCES has no surrogate id, run id, request id or prefix, so the
    -- report's RECORD_KEY IS the composite cell key
    --   ledger|budget|period|currency|seg1..seg30 (~ NULL as '#')
    -- and the TFM's RECON_KEY is stamped to exactly that string by the transform.
    -- GL_BUDGET_VERSIONS.BUDGET_VERSION_ID is VPD-blocked on the demo instance
    -- (live SELECT -> ORA-00942), so the honest, non-null Fusion base-table id the
    -- report returns is the cell's GL_CODE_COMBINATIONS.CODE_COMBINATION_ID; that
    -- is what lands in FUSION_BUDGET_VERSION_ID (the TFM's Fusion-id column). Rows
    -- already terminal (LOADED/FAILED) are never touched, so this runs safely
    -- alongside PARSE_AND_UPDATE without double-counting; whichever proves a cell
    -- first wins and the other's guard skips it.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_GLBUDGETS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'APPLY_CONTRACT_V1_GLBUDGETS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
    BEGIN
        -- Generated-row count (static, this object's own table) drives the shared
        -- fetch's keyset page-count cap.
        SELECT COUNT(*) INTO l_gen_count
        FROM   DMT_GL_BUDGET_INT_TFM_TBL
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
                'APPLY_CONTRACT_V1_GLBUDGETS: Contract v1 fetch failed for '
                || 'GLBudgets (detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': GLBudgets recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                IF l_rows(i).SOURCE_TYPE = 'BASE'
                   AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                   AND l_rows(i).FUSION_ID IS NOT NULL THEN
                    -- Positive proof: cell present in GL_BUDGET_BALANCES resolving
                    -- to a real code combination id. The ONLY path to LOADED.
                    -- Static UPDATE keyed on RECON_KEY (= the cell key).
                    UPDATE DMT_GL_BUDGET_INT_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_BUDGET_VERSION_ID = l_rows(i).FUSION_ID,
                           RESULTS_UPDATED_DATE     = SYSDATE,
                           LAST_UPDATED_DATE        = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    RECON_KEY = l_rows(i).RECORD_KEY
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_loaded := l_loaded + SQL%ROWCOUNT;

                ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                      AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                    -- A real, specific Fusion error -> FAILED on the exact message
                    -- (never composed). Static UPDATE keyed on RECON_KEY.
                    UPDATE DMT_GL_BUDGET_INT_TFM_TBL
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
                    -- non-terminal status with no real error: leave the row for
                    -- the existing unaccounted sweep. Never fabricate an outcome.
                    NULL;
                END IF;
            END LOOP;
        END IF;

        -- Fan cell outcome back to the STG source rows for the cells this pass
        -- turned terminal (same echo PARSE_AND_UPDATE does; safe to repeat).
        UPDATE DMT_GL_BUDGET_INT_STG_TBL SET STG_STATUS='LOADED', LAST_UPDATED_DATE=SYSDATE
        WHERE STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_GL_BUDGET_INT_TFM_TBL
                                  WHERE RUN_ID=p_run_id AND TFM_STATUS='LOADED');
        UPDATE DMT_GL_BUDGET_INT_STG_TBL SET STG_STATUS='FAILED', LAST_UPDATED_DATE=SYSDATE
        WHERE STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_GL_BUDGET_INT_TFM_TBL
                                  WHERE RUN_ID=p_run_id AND TFM_STATUS='FAILED');

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
    END APPLY_CONTRACT_V1_GLBUDGETS;

    -- ============================================================
    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER    DEFAULT NULL,
        p_run_start     IN TIMESTAMP DEFAULT NULL,
        p_ledger_id     IN NUMBER    DEFAULT NULL,
        p_work_queue_id IN NUMBER    DEFAULT NULL
    ) IS
    BEGIN
        -- Contract v1 base-tier positive proof (single-tier FBDI template, PR #363):
        -- the shared fetch returns the nine-column recon report rows and the APPLY is
        -- STATIC SQL against this object's TFM table, keyed on RECON_KEY. This is now
        -- the SOLE reconciliation path for GLBudgets: it stamps
        -- FUSION_BUDGET_VERSION_ID on cells positively confirmed in
        -- GL_BUDGET_BALANCES, marks FAILED cells left in GL_BUDGET_INTERFACE with the
        -- real error, and leaves the rest GENERATED for the shared unaccounted sweep.
        -- The load ESS id feeds the report's LOAD_REQUEST_ID, which is how the
        -- nine-column report scopes cells to THIS run (budgets carry no run id/prefix
        -- of their own).
        --
        -- The former two-parameter run-start / cell-key path (FETCH_BIP_RESULTS +
        -- PARSE_AND_UPDATE, params P_RUN_START / P_LEDGER_ID) is RETIRED here: the
        -- GLBudgets data model was rewritten to the nine-column Contract v1 shape
        -- (PR #360), so those old parameters and the REC_TYPE/ACCOUNT_KEY columns the
        -- old parser read no longer exist. Those two procedures remain in the package
        -- (unused) to avoid churn to the spec, but they are no longer invoked.
        -- p_run_start / p_ledger_id are accepted for signature compatibility with the
        -- loader dispatch and are intentionally not used.
        APPLY_CONTRACT_V1_GLBUDGETS(
            p_run_id     => p_run_id,
            p_request_id => TO_CHAR(p_load_ess_id));
        -- Unresolved records intentionally left GENERATED (unaccounted).
        -- No fabricated FAILED: the accounting gate reports the object
        -- not-DONE and the funnel surfaces these as UNRECONCILED.
    EXCEPTION WHEN OTHERS THEN
        DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RECONCILE_BATCH failed.', SQLERRM, C_PKG, 'RECONCILE_BATCH'); RAISE;
    END RECONCILE_BATCH;

END DMT_GL_BUDGET_RESULTS_PKG;
/
