-- PACKAGE BODY DMT_PLAN_BUDGET_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PLAN_BUDGET_RESULTS_PKG" AS
    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_PLAN_BUDGET_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'PlanningBudgets';

    -- (bip_soap_post + b64_to_clob + the raw-CLOB FETCH_BIP_RESULTS removed 2026-09-23,
    --  backlog item #20 -- the BIP runReport transport is now the shared
    --  DMT_UTIL_PKG.RUN_BIP_REPORT, called from RECONCILE_BATCH. That one call
    --  builds the same runReport envelope (report path resolved from
    --  DMT_BIP_REPORT_TBL by CEMLI, P_BATCH_ID = load_ess_id) and returns the
    --  already-decoded report XMLTYPE, so the local <reportBytes> extraction +
    --  base64 decode -- which carried the VARCHAR2(32767) truncation bug -- is
    --  gone. PARSE_AND_UPDATE now takes the decoded XMLTYPE directly.)

    PROCEDURE PARSE_AND_UPDATE (p_run_id IN NUMBER, p_xml_data IN XMLTYPE,
        p_work_queue_id IN NUMBER DEFAULT NULL) IS
        l_loaded NUMBER := 0; l_failed NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'PARSE_AND_UPDATE start.', 'INFO', C_PKG, 'PARSE_AND_UPDATE');

        -- p_xml_data is the decoded BIP report XMLTYPE from RUN_BIP_REPORT
        -- (NULL when BIP returned no <reportBytes>, i.e. zero rows).
        IF p_xml_data IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'PARSE_AND_UPDATE: No <reportBytes> in BIP response. No rows updated.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, 'PARSE_AND_UPDATE');
            RETURN;
        END IF;

        FOR r IN (
            SELECT x.scenario, UPPER(x.import_status) AS import_status, x.error_msg
            FROM XMLTABLE('/DATA_DS/G_1' PASSING p_xml_data COLUMNS
                scenario    VARCHAR2(100)  PATH 'SCENARIO',
                import_status VARCHAR2(50)   PATH 'IMPORT_STATUS',
                error_msg     VARCHAR2(4000) PATH 'ERROR_MESSAGE') x
        ) LOOP
            IF r.import_status IN ('Y','PROCESSED','SUCCESS','COMPLETED') THEN
                -- Work-queue-ID core: when a work-queue scope is supplied, touch only
                -- THIS item's rows (p_work_queue_id NULL = run-scoped, the standard
                -- direct-run path -- byte-identical to the prior behaviour).
                UPDATE DMT_PLAN_BUDGET_TFM_TBL SET TFM_STATUS='LOADED', RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                WHERE RUN_ID=p_run_id AND SCENARIO=r.scenario AND TFM_STATUS!='LOADED'
                AND   (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
                l_loaded := l_loaded + SQL%ROWCOUNT;
            ELSIF r.error_msg IS NOT NULL THEN
                -- Real Fusion error returned — mark FAILED carrying it.
                UPDATE DMT_PLAN_BUDGET_TFM_TBL SET TFM_STATUS='FAILED',
                    ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,'[FUSION_ERROR] '||r.error_msg),
                    RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                WHERE RUN_ID=p_run_id AND SCENARIO=r.scenario AND TFM_STATUS!='FAILED'
                AND   (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
                l_failed := l_failed + SQL%ROWCOUNT;
            -- Non-success status but no real Fusion error message: do NOT write a
            -- bare '[FUSION_ERROR]' with no detail. Leave the row GENERATED for the
            -- honest sweep to mark UNACCOUNTED.
            END IF;
        END LOOP;

        -- Absence from the BIP report is NOT success. A row is LOADED only when its
        -- SCENARIO comes back with an explicit success import_status above. Rows that
        -- BIP did not confirm (and that carry no real Fusion error) are left GENERATED
        -- so the honest accounting sweep marks them UNACCOUNTED. Never auto-promote
        -- unconfirmed rows to LOADED.

        UPDATE DMT_PLAN_BUDGET_STG_TBL SET STG_STATUS='LOADED', LAST_UPDATED_DATE=SYSDATE
        WHERE STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_PLAN_BUDGET_TFM_TBL WHERE RUN_ID=p_run_id AND TFM_STATUS='LOADED');
        UPDATE DMT_PLAN_BUDGET_STG_TBL SET STG_STATUS='FAILED', LAST_UPDATED_DATE=SYSDATE
        WHERE STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_PLAN_BUDGET_TFM_TBL WHERE RUN_ID=p_run_id AND TFM_STATUS='FAILED');
        -- NO COMMIT — orchestrator controls transaction boundaries
        DMT_UTIL_PKG.LOG(p_run_id, 'PARSE_AND_UPDATE complete. LOADED: '||l_loaded||', FAILED: '||l_failed, 'INFO', C_PKG, 'PARSE_AND_UPDATE');
    EXCEPTION WHEN OTHERS THEN DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'PARSE_AND_UPDATE failed.', SQLERRM, C_PKG, 'PARSE_AND_UPDATE'); RAISE;
    END PARSE_AND_UPDATE;

    PROCEDURE RECONCILE_BATCH (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL) IS
        l_xml      XMLTYPE;
        l_err_code NUMBER;
    BEGIN
        -- Shared transport: RUN_BIP_REPORT resolves the report path from
        -- DMT_BIP_REPORT_TBL by CEMLI and returns the decoded report XMLTYPE
        -- (NULL on zero rows). Same BIP invocation as the old inline
        -- FETCH_BIP_RESULTS: P_BATCH_ID = the load ESS id. On transport/SOAP
        -- failure it returns NULL with C_ERROR -- raise so the failure is loud
        -- (as the old FETCH_BIP_RESULTS raised).
        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id     => p_run_id,
            p_cemli_code => C_CEMLI,
            p_params     => 'P_BATCH_ID|' || TO_CHAR(p_load_ess_id),
            x_report_xml => l_xml,
            x_error_code => l_err_code);
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20034,
                'RECONCILE_BATCH: BIP runReport fetch failed for ' || C_CEMLI ||
                ' (detail in DMT_LOG_TBL).');
        END IF;

        PARSE_AND_UPDATE(p_run_id, l_xml, p_work_queue_id => p_work_queue_id);
    EXCEPTION WHEN OTHERS THEN DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'RECONCILE_BATCH failed.', SQLERRM, C_PKG, 'RECONCILE_BATCH'); RAISE;
    END RECONCILE_BATCH;

END DMT_PLAN_BUDGET_RESULTS_PKG;
/
