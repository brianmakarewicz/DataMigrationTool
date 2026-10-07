-- PACKAGE BODY DMT_PRJ_BUDGET_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PRJ_BUDGET_RESULTS_PKG" 
AS
-- ============================================================
-- NAME:    DMT_PRJ_BUDGET_RESULTS_PKG
-- PURPOSE: ProjectBudgets reconciliation: Contract v1 base-tier proof
--          (PJO_PLAN_VERSIONS_B) + BudgetsXfaceBIP import-report harvest.
-- REVISIONS:
--  1.1  2026-10-07  Drop legacy P_BATCH_ID RUN_BIP_REPORT/PARSE_AND_UPDATE path; skip #IMPORT_REPORT# marker
-- No absence=LOADED fallback. A row is LOADED only from a base-table hit
-- with its PLAN_VERSION_ID, FAILED only with a real Fusion message, and is
-- otherwise left for the shared unaccounted sweep.
-- ============================================================

    C_IMPORT_MARKER CONSTANT VARCHAR2(30) := '#IMPORT_REPORT#';

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_PRJ_BUDGET_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'ProjectBudgets';

    -- --------------------------------------------------------
    -- (bip_soap_post + FETCH_BIP_RESULTS removed — the BIP runReport transport
    --  is now the shared DMT_UTIL_PKG.RUN_BIP_REPORT, called from RECONCILE_BATCH.
    --  It builds the same v2 runReport envelope, posts it, checks the SOAP fault,
    --  extracts <reportBytes> and decodes any size, returning the parsed XMLTYPE.
    --  b64_to_clob was already centralised in DMT_UTIL_PKG.BASE64_DECODE_CLOB.)

    -- --------------------------------------------------------
    -- Private: resolve the CHILD Import Budget report job id.
    --
    -- Fusion's ImportBudgetsInterfaceData (the "import" ESS job the loader passes
    -- as p_import_ess_id) is only the interface-load wrapper. The real per-row
    -- accept/reject report lives in a SEPARATE job, BudgetsXfaceBIP, whose XML
    -- carries the SUCCESS_COUNT/FAILURE_COUNT and the per-line rejection messages.
    -- Reading the wrapper's own ESS output yields no per-row verdict and leaves
    -- every rejected budget line unaccounted (proven live, run 121: three
    -- ProjectBudgets rows left UNACCOUNTED although BudgetsXfaceBIP request
    -- 10015083 reported FAILURE_COUNT=3 with real Fusion messages).
    --
    -- DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB reads REPORT_JOB_DEF for this CEMLI
    -- (seeded 'BudgetsXfaceBIP' in DMT_ERP_INTERFACE_OPTIONS_TBL), finds that
    -- request in Fusion, and stores it in DMT_ESS_JOB_TBL as a logical child of the
    -- import job. This helper first reads any already-captured linkage, then
    -- captures lazily (idempotent). Returns the report request id, or NULL if this
    -- run genuinely produced no report — in which case the caller downloads nothing
    -- and the affected rows stay unaccounted (never a fabricated FAILED). This
    -- mirrors DMT_PROJECT_RESULTS_PKG.resolve_report_ess_id exactly.
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
            AND    UPPER(NVL(JOB_SHORT_NAME, JOB_DEFINITION)) LIKE '%BUDGETSXFACEBIP%'
            AND    REQUEST_ID <> p_import_ess_id
            ORDER  BY REQUEST_ID DESC
            FETCH FIRST 1 ROW ONLY;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_report_id := NULL;
        END;

        IF l_report_id IS NULL THEN
            l_report_id := DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB(
                p_run_id        => p_run_id,
                p_import_ess_id => p_import_ess_id,
                p_cemli_code    => C_CEMLI);
        END IF;

        RETURN l_report_id;
    END resolve_report_ess_id;

    -- --------------------------------------------------------
    -- Private: read the BudgetsXfaceBIP import report and mark the exact rows it
    -- rejects FAILED with the REAL Fusion message. This is the ONLY source of real
    -- per-row Fusion error text for ProjectBudgets — the interface/base BIP recon
    -- above proves LOADED (base row found) but the interface table carries no error
    -- text, so a rejected line otherwise stays UNACCOUNTED.
    --
    -- The report's per-row group is LIST_G_12/G_12: column P = the source budget
    -- line reference (= our RECON_KEY = SRC_BUDGET_LINE_REFERENCE, an EXACT match),
    -- column Y = the rejection MESSAGE_TEXT. We therefore target G_12/P/Y directly
    -- with XMLTABLE. (The generic DMT_IMPORT_REPORT_PKG.PARSE_ERRORS only walks
    -- groups whose tag contains 'ERROR'; the budget groups are G_2/G_12, so it
    -- matches nothing here — this targeted parse is required.)
    --
    -- If G_12 is absent we fall back to LIST_G_2/G_2, keyed on DATA_REF_COL2 =
    -- project number, message = MESSAGE_TEXT.
    --
    -- HONEST ACCOUNTING: we only ever stamp FAILED for a row the report explicitly
    -- names WITH a real message, and only on rows not already terminal (LOADED or
    -- FAILED). A row with no base-table hit AND no report rejection stays
    -- UNACCOUNTED — never swept, never fabricated.
    -- --------------------------------------------------------
    PROCEDURE apply_import_report (
        p_run_id        IN  NUMBER,
        p_import_ess_id IN  NUMBER,
        x_matched       OUT NUMBER
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'APPLY_IMPORT_REPORT';
        l_report_id NUMBER;
        l_ir_clob   CLOB;
        l_xml       XMLTYPE;
        l_g12_cnt   NUMBER := 0;
    BEGIN
        x_matched := 0;
        IF p_import_ess_id IS NULL THEN
            RETURN;
        END IF;

        l_report_id := resolve_report_ess_id(p_run_id, p_import_ess_id);
        IF l_report_id IS NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id  => p_run_id,
                p_message => C_PROC || ': No BudgetsXfaceBIP report captured for import ESS ' ||
                             p_import_ess_id || '. No per-row report to read; rows left '
                             || 'unaccounted (never a fabricated FAILED).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RETURN;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ': Reading Import Budget report from job ' || l_report_id ||
                         ' (wrapper import ESS ' || p_import_ess_id || ').',
            p_package   => C_PKG,
            p_procedure => C_PROC);

        BEGIN
            l_ir_clob := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(l_report_id);
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(
                    p_run_id  => p_run_id,
                    p_message => C_PROC || ': Failed to download ESS output XML for report request ' ||
                                 l_report_id || ': ' || SQLERRM,
                    p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                    p_package   => C_PKG,
                    p_procedure => C_PROC);
                l_ir_clob := NULL;
        END;

        IF l_ir_clob IS NULL OR DBMS_LOB.GETLENGTH(l_ir_clob) = 0 THEN
            RETURN;
        END IF;

        BEGIN
            l_xml := XMLTYPE(l_ir_clob);
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(
                    p_run_id  => p_run_id,
                    p_message => C_PROC || ': Report XML for request ' || l_report_id ||
                                 ' is not valid XML; skipping (rows left unaccounted).',
                    p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                    p_package   => C_PKG,
                    p_procedure => C_PROC);
                IF l_ir_clob IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_ir_clob) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_ir_clob);
                END IF;
                RETURN;
        END;

        -- Primary path: LIST_G_12/G_12, column P = SRC_BUDGET_LINE_REFERENCE
        -- (= RECON_KEY, exact), column Y = the rejection message. Only rows with a
        -- non-null message are stamped FAILED, and only if not already terminal.
        FOR r IN (
            SELECT x.recon_key, x.message_text
            FROM   XMLTABLE('/DATA_DS/LIST_G_12/G_12' PASSING l_xml
                COLUMNS
                    -- RECON_KEY is VARCHAR2(1000) on the TFM table; match that width
                    -- so a long source ref never blows up XMLTABLE (ORA-19279) and
                    -- silently downgrades the whole report to the WARN path.
                    recon_key    VARCHAR2(1000) PATH 'P',
                    message_text VARCHAR2(4000) PATH 'Y'
            ) x
            WHERE  x.recon_key IS NOT NULL
            AND    x.message_text IS NOT NULL
        ) LOOP
            l_g12_cnt := l_g12_cnt + 1;
            UPDATE DMT_PRJ_BUDGET_TFM_TBL
            SET    TFM_STATUS           = 'FAILED',
                   ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                            '[FUSION_ERROR] ' || r.message_text),
                   RESULTS_UPDATED_DATE = SYSDATE,
                   LAST_UPDATED_DATE    = SYSDATE
            WHERE  RUN_ID    = p_run_id
            AND    RECON_KEY = r.recon_key
            AND    TFM_STATUS NOT IN ('LOADED','FAILED');
            x_matched := x_matched + SQL%ROWCOUNT;
        END LOOP;

        -- Fallback: only when G_12 held NO rows at all. In the observed report
        -- (run 121) BudgetsXfaceBIP populates BOTH LIST_G_12 and LIST_G_2 with the
        -- same rejections, so G_12 (keyed EXACTLY on RECON_KEY) already covers every
        -- rejected line and the fallback stays dormant — no rejection is missed.
        -- The fallback exists only for a report variant that emits G_2 without G_12.
        -- It keys on DATA_REF_COL2 = project number, so it can stamp every budget
        -- line for a rejected project; that is acceptable — all lines of a rejected
        -- project share the rejection.
        IF l_g12_cnt = 0 THEN
            FOR r IN (
                SELECT x.project_number, x.message_text
                FROM   XMLTABLE('/DATA_DS/LIST_G_2/G_2' PASSING l_xml
                    COLUMNS
                        project_number VARCHAR2(50)   PATH 'DATA_REF_COL2',
                        message_text   VARCHAR2(4000) PATH 'MESSAGE_TEXT'
                ) x
                WHERE  x.project_number IS NOT NULL
                AND    x.message_text IS NOT NULL
            ) LOOP
                UPDATE DMT_PRJ_BUDGET_TFM_TBL
                SET    TFM_STATUS           = 'FAILED',
                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                '[FUSION_ERROR] ' || r.message_text),
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID    = p_run_id
                AND    PROJECT_NUMBER = r.project_number
                AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                x_matched := x_matched + SQL%ROWCOUNT;
            END LOOP;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ': Import Budget report parsed (job ' || l_report_id ||
                         '); ' || x_matched || ' TFM rows marked FAILED with the real message.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

        IF l_ir_clob IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_ir_clob) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_ir_clob);
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            -- A malformed report must NOT abort reconciliation: log a WARN and
            -- return what we matched. Unmatched rows stay for the unaccounted sweep.
            IF l_ir_clob IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_ir_clob) = 1 THEN
                DBMS_LOB.FREETEMPORARY(l_ir_clob);
            END IF;
            DMT_UTIL_PKG.LOG(
                p_run_id  => p_run_id,
                p_message => C_PROC || ': Import Budget report parse/apply failed (' || SQLERRM ||
                             '); ' || x_matched || ' rows matched before the error.',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
    END apply_import_report;

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
    -- ref carries the run prefix since 2026-10-07, and the V2 DM scopes the run
    -- by that prefix, so a budget on an EXISTING project is matched too). The
    -- import-report harvest below keys LIST_G_12 column P (the same prefixed
    -- reference, echoed from the CSV) to RECON_KEY. Rows already terminal (LOADED/FAILED)
    -- are never touched, so this runs safely before the import-report harvest
    -- without double-counting.
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
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
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
                l_rc   := 0;     -- backlog #65: reset per row so a prior row's tier
                l_tier := NULL;  -- cannot mislabel this row's audit log line.
                IF l_rows(i).SOURCE_TYPE = 'BASE'
                   AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                   AND l_rows(i).FUSION_ID IS NOT NULL THEN
                    -- Positive proof: plan version found in PJO_PLAN_VERSIONS_B with a
                    -- real id. The ONLY path to LOADED.
                    --
                    -- Backlog #65 three-tier match (owner order on PR #481). Tier 1 is
                    -- the stamped recon key (RECON_KEY = RECORD_KEY, exactly as before).
                    -- Only if tier 1 matches NO TFM row do we fall through: tier 2 (the
                    -- Slot C DFF stamp: TFM_SEQUENCE_ID = the trailing numeric segment of
                    -- DFF_KEY) -- ProjectBudgets' DMT_REFERENCE is the budget-reference
                    -- string, not a numeric carrier, so tier 2 is normally a no-op; kept
                    -- uniform with the shared template -- and then tier 3 (the business
                    -- key: SRC_BUDGET_LINE_REFERENCE = BUSINESS_KEY, the native source
                    -- budget-line reference the report returns as SOURCE_REF). Every
                    -- tier-1 hit short-circuits, so loaded outcomes are identical to
                    -- before. Static UPDATEs.
                    UPDATE DMT_PRJ_BUDGET_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_BUDGET_VERSION_ID = l_rows(i).FUSION_ID,
                           RESULTS_UPDATED_DATE     = SYSDATE,
                           LAST_UPDATED_DATE        = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    RECON_KEY = l_rows(i).RECORD_KEY
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_rc := SQL%ROWCOUNT;
                    l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                    IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                        l_dff_seq := TO_NUMBER(
                            REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                        IF l_dff_seq IS NOT NULL THEN
                            UPDATE DMT_PRJ_BUDGET_TFM_TBL
                            SET    TFM_STATUS               = 'LOADED',
                                   FUSION_BUDGET_VERSION_ID = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE     = SYSDATE,
                                   LAST_UPDATED_DATE        = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    TFM_SEQUENCE_ID = l_dff_seq
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                        END IF;
                    END IF;

                    IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                        UPDATE DMT_PRJ_BUDGET_TFM_TBL
                        SET    TFM_STATUS               = 'LOADED',
                               FUSION_BUDGET_VERSION_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE     = SYSDATE,
                               LAST_UPDATED_DATE        = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    SRC_BUDGET_LINE_REFERENCE = l_rows(i).BUSINESS_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                    END IF;

                    l_loaded := l_loaded + l_rc;
                    IF l_tier IN ('TIER2','TIER3') THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            C_PROC || ': matched a LOADED project budget via ' || l_tier ||
                            ' fallback (tier 1 stamped key did not resolve). '
                            || 'BUDGET_VERSION_ID ' || l_rows(i).FUSION_ID || '.',
                            'INFO', C_PKG, C_PROC);
                    END IF;

                ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                      AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                      AND l_rows(i).ERROR_MESSAGE <> C_IMPORT_MARKER THEN
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
                    -- INTERFACE/SUCCESS (corroborating, never sufficient), the
                    -- #IMPORT_REPORT# marker (the real message comes from the
                    -- import-report harvest in RECONCILE_BATCH), or a non-terminal
                    -- status with no real error: leave the row for the harvest and
                    -- then the shared unaccounted sweep. Never fabricate an outcome.
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
        l_ir_matched NUMBER := 0;
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

        -- (The legacy second fetch of the same report with the retired P_BATCH_ID
        -- parameter, parsed by PARSE_AND_UPDATE against pre-Contract-v1 column
        -- names, was removed 2026-10-07: it matched no row since the report moved
        -- to the nine-column contract, and it echoed outcomes back onto STG rows,
        -- which section 5 forbids. The Contract v1 fetch above is the only fetch.)

        -- Import-report harvest: the base/interface BIP recon above proves LOADED
        -- (real base row) but carries no per-row Fusion error text. Fusion's
        -- per-line rejections live only in the BudgetsXfaceBIP report, which this
        -- reads and applies — marking each explicitly-named row FAILED with its
        -- REAL message. Runs AFTER the base-tier proof so a genuinely-loaded row is
        -- never overwritten (the UPDATE skips LOADED/FAILED rows anyway). Only rows
        -- the report names are touched; anything else stays unaccounted.
        apply_import_report(
            p_run_id        => p_run_id,
            p_import_ess_id => p_import_ess_id,
            x_matched       => l_ir_matched);

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

    -- --------------------------------------------------------
    -- RESET_UNACCOUNTED (backlog #95) — see spec. Static UPDATE over the
    -- compile-time-known ProjectBudgets TFM table. Flips this run's UNACCOUNTED
    -- rows back to GENERATED and strips the trailing [UNACCOUNTED] tag from
    -- ERROR_TEXT (CLOB-safe REGEXP_REPLACE — plain REPLACE raises ORA-22849),
    -- preserving any prior real error so the next reconcile accumulates onto it
    -- exactly as a first pass would. Scoped by run, and by work-queue item when
    -- given (spawn-per-partition children). NO dynamic SQL; NO COMMIT.
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
        UPDATE DMT_PRJ_BUDGET_TFM_TBL
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
        l_reset := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED ProjectBudgets row(s) to '
            || 'GENERATED for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT — the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_PRJ_BUDGET_RESULTS_PKG;
/
