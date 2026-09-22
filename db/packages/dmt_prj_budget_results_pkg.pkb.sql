-- PACKAGE BODY DMT_PRJ_BUDGET_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PRJ_BUDGET_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_PRJ_BUDGET_RESULTS_PKG body
-- Project Budgets BIP reconciliation — Two-Tier pattern.
-- Tier 1: PJO_PLAN_VERSIONS_XFACE (interface table, errors/status)
-- Tier 2: PJO_PLAN_VERSIONS_B (base table, positive confirmation)
-- No absence=LOADED fallback. Every row gets positive verification
-- or is marked FAILED with a reconciliation error.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_PRJ_BUDGET_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'ProjectBudgets';

    -- --------------------------------------------------------
    -- (bip_soap_post + FETCH_BIP_RESULTS removed — the BIP runReport transport
    --  is now the shared DMT_UTIL_PKG.RUN_BIP_REPORT, called from RECONCILE_BATCH.
    --  It builds the same v2 runReport envelope, posts it, checks the SOAP fault,
    --  extracts <reportBytes> and decodes any size, returning the parsed XMLTYPE.
    --  b64_to_clob was already centralised in DMT_UTIL_PKG.BASE64_DECODE_CLOB.)

    -- --------------------------------------------------------
    -- PARSE_AND_UPDATE — Two-tier reconciliation, no absence=LOADED
    -- Receives the already-decoded BIP report XMLTYPE (NULL on zero rows) from
    -- the shared transport DMT_UTIL_PKG.RUN_BIP_REPORT.
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml            IN XMLTYPE
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_xml        XMLTYPE := p_xml;
        l_loaded     NUMBER := 0;
        l_failed     NUMBER := 0;
        l_not_recon  NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- l_xml is the decoded BIP report XMLTYPE from RUN_BIP_REPORT (NULL on
        -- zero rows from both tiers).
        IF l_xml IS NULL THEN
            -- No reportBytes at all — BIP returned 0 rows from BOTH tiers.
            -- We could determine neither a base-table LOADED nor a real Fusion
            -- per-record error, so we do NOT fabricate a FAILED. The GENERATED
            -- rows are left as-is (unaccounted); the accounting gate reports the
            -- object not-DONE and the funnel surfaces them as unreconciled.
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': No <reportBytes> in BIP response. ' ||
                                    'GENERATED rows left unaccounted (not marked FAILED).',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN;
        END IF;

        -- Process rows from BIP XML — two-tier reconciliation
        FOR r IN (
            SELECT x.project_name,
                   x.project_number,
                   x.plan_version_name,
                   x.src_budget_line_reference,
                   UPPER(x.source_type)   AS source_type,
                   UPPER(x.process_code)  AS process_code,
                   UPPER(x.load_status)   AS load_status,
                   x.fusion_id,
                   x.error_msg
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                COLUMNS
                    project_name              VARCHAR2(240)  PATH 'PROJECT_NAME',
                    project_number            VARCHAR2(25)   PATH 'PROJECT_NUMBER',
                    plan_version_name         VARCHAR2(240)  PATH 'PLAN_VERSION_NAME',
                    src_budget_line_reference VARCHAR2(240)  PATH 'SRC_BUDGET_LINE_REFERENCE',
                    source_type               VARCHAR2(20)   PATH 'SOURCE_TYPE',
                    process_code              VARCHAR2(50)   PATH 'PROCESS_CODE',
                    load_status               VARCHAR2(50)   PATH 'LOAD_STATUS',
                    fusion_id                 NUMBER         PATH 'FUSION_ID',
                    error_msg                 VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
        ) LOOP
            IF r.source_type = 'BASE' THEN
                -- Tier 2: Found in base table = positively LOADED
                UPDATE DMT_PRJ_BUDGET_TFM_TBL
                SET    TFM_STATUS               = 'LOADED',
                       FUSION_BUDGET_VERSION_ID = r.fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    SRC_BUDGET_LINE_REFERENCE = r.src_budget_line_reference
                AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;

            ELSIF r.source_type = 'INTERFACE' THEN
                -- Tier 1: Interface table row — check tfm_status
                IF r.process_code IN ('COMPLETED','PROCESSED','SUCCESS','P')
                   OR r.load_status IN ('COMPLETED','PROCESSED','P','SUCCESS') THEN
                    UPDATE DMT_PRJ_BUDGET_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_BUDGET_VERSION_ID = r.fusion_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    SRC_BUDGET_LINE_REFERENCE = r.src_budget_line_reference
                    AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.process_code IN ('ERROR','REJECTED','FAILED','FAILURE','E')
                      OR r.load_status IN ('ERROR','REJECTED','E','FAILED') THEN
                    -- Only mark FAILED when Fusion actually returned an error
                    -- message. When error_msg is NULL we have only a status label
                    -- (which we compose), not a real Fusion error, so we leave the
                    -- row GENERATED for the honest sweep to mark UNACCOUNTED.
                    IF r.error_msg IS NOT NULL THEN
                        UPDATE DMT_PRJ_BUDGET_TFM_TBL
                        SET    TFM_STATUS               = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                         '[FUSION_ERROR] ' || r.error_msg),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID       = p_run_id
                        AND    SRC_BUDGET_LINE_REFERENCE = r.src_budget_line_reference
                        AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                        l_failed := l_failed + SQL%ROWCOUNT;
                    END IF;
                ELSE
                    -- Unknown interface status and no real Fusion error to report.
                    -- Do NOT compose a FAILED; leave the row GENERATED for the
                    -- honest sweep to mark UNACCOUNTED.
                    NULL;
                END IF;
            END IF;
        END LOOP;

        -- (No absence-!=-LOADED sweep: a record neither confirmed LOADED nor
        -- given a real Fusion error is left GENERATED (unaccounted). The
        -- accounting gate then reports the object not-DONE and the funnel
        -- surfaces it as UNRECONCILED — no fabricated FAILED.)
        l_not_recon := 0;

        <<echo_to_stg>>
        -- Echo outcomes back to STG
        UPDATE DMT_PRJ_BUDGET_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_PRJ_BUDGET_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_PRJ_BUDGET_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_PRJ_BUDGET_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_PRJ_BUDGET_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- NO COMMIT — orchestrator controls transaction boundaries

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. ProjectBudgets LOADED: ' || l_loaded ||
                                ', FAILED: ' || l_failed ||
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
    -- APPLY_CONTRACT_V1_PRJ_BUDGET (private)
    -- The Contract v1 base-tier positive proof for ProjectBudgets — the
    -- SINGLE-TIER FBDI template (design section 5, Option A shape; copied from
    -- DMT_EXPENDITURE_RESULTS_PKG.APPLY_CONTRACT_V1_EXPENDITURES, PR #363).
    --
    -- The shared package DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the ProjectBudgets
    -- nine-column recon report over BIP (keyset paged, run-prefix scoped) and
    -- returns the parsed rows — no dynamic SQL, no TFM reference there. The APPLY
    -- here is STATIC SQL against the compile-time-known ProjectBudgets TFM table:
    --   * BASE / SUCCESS / FUSION_ID NOT NULL  -> LOADED, stamp FUSION_ID into
    --       FUSION_BUDGET_VERSION_ID. The ONLY path to LOADED.
    --   * FUSION_STATUS = ERROR with a real message -> FAILED, message appended as
    --       '[FUSION_ERROR] ' || message (never composed).
    --   * everything else left for the existing two-tier / import-report harvest
    --       and the shared unaccounted sweep.
    -- Match is on RECON_KEY = the report's RECORD_KEY. The recon DM emits
    -- RECORD_KEY = PM_BUDGET_REFERENCE on the base tier (the native source budget
    -- line reference, persisted verbatim on PJO_PLAN_VERSIONS_B) and
    -- SRC_BUDGET_LINE_REFERENCE on the interface tier; the transform stamps
    -- RECON_KEY = SRC_BUDGET_LINE_REFERENCE, which is the same string (the source
    -- ref is copied through, not prefixed). Rows already terminal (LOADED/FAILED)
    -- are never touched, so this runs safely alongside the existing
    -- PARSE_AND_UPDATE path without double-counting.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_PRJ_BUDGET (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'APPLY_CONTRACT_V1_PRJ_BUDGET';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
    BEGIN
        -- Generated-row count (static, this object's own table) drives the shared
        -- fetch's keyset page-count cap.
        SELECT COUNT(*) INTO l_gen_count
        FROM   DMT_PRJ_BUDGET_TFM_TBL
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
                'APPLY_CONTRACT_V1_PRJ_BUDGET: Contract v1 fetch failed for '
                || 'ProjectBudgets (detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': ProjectBudgets recon report returned zero rows; '
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
                    -- Positive proof: plan version found in PJO_PLAN_VERSIONS_B with
                    -- a real id. The ONLY path to LOADED. Static UPDATE keyed on
                    -- RECON_KEY.
                    UPDATE DMT_PRJ_BUDGET_TFM_TBL
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
                    UPDATE DMT_PRJ_BUDGET_TFM_TBL
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
    END APPLY_CONTRACT_V1_PRJ_BUDGET;

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
        l_xml      XMLTYPE;
        l_err_code NUMBER;
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
        -- The import ESS id (falling back to the load ESS id) feeds the report's
        -- LOAD_REQUEST_ID for traceability; run-scoped row selection is by the
        -- stamped prefix (see the DM header).
        APPLY_CONTRACT_V1_PRJ_BUDGET(
            p_run_id     => p_run_id,
            p_request_id => TO_CHAR(NVL(p_import_ess_id, p_load_ess_id)));

        -- Shared transport: parsed XMLTYPE (NULL on zero rows). On transport/SOAP
        -- failure it returns NULL with C_ERROR — raise so the failure is loud (as
        -- the old FETCH_BIP_RESULTS raised).
        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id     => p_run_id,
            p_cemli_code => C_CEMLI,
            p_params     => 'P_BATCH_ID|' || TO_CHAR(p_load_ess_id) ||
                            '~P_IMPORT_ESS_ID|' || NVL(TO_CHAR(p_import_ess_id), ''),
            x_report_xml => l_xml,
            x_error_code => l_err_code);
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20034,
                C_PROC || ': BIP runReport fetch failed for ' || C_CEMLI ||
                ' (detail in DMT_LOG_TBL).');
        END IF;

        PARSE_AND_UPDATE(p_run_id, l_xml);

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

END DMT_PRJ_BUDGET_RESULTS_PKG;
/
