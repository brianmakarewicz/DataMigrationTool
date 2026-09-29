CREATE OR REPLACE PACKAGE BODY DMT_PPM_COMPARE_PKG AS

    -- ------------------------------------------------------------------
    -- Projects. COUNT-ONLY -- Projects carries no reconcilable amount (only
    -- an unrelated, unpopulated OPPORTUNITY_AMT sales field). Discovery
    -- (docs/superpowers/specs/discovery/Projects.md, run 132) found NO
    -- batch key round-trips onto the Fusion base table: LOAD/IMPORT ESS job
    -- ids never land on PJF_PROJECTS_ALL_B.REQUEST_ID (NULL after import on
    -- this pod), and the interface table is purged. The production-valid
    -- key is therefore FALLBACK-TO-CAPTURED-IDS: the exact list of
    -- FUSION_PROJECT_ID values DMT already captured on this run's LOADED
    -- TFM rows. This is prefix-free and identifies the run's records
    -- exactly in production or test -- never a prefix/timestamp query.
    -- ------------------------------------------------------------------
    FUNCTION GET_PROJECTS_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        C_CEMLI CONSTANT VARCHAR2(30) := 'Projects';
        l_stg_cnt   NUMBER;
        l_err_cnt   NUMBER;
        l_fus_cnt   NUMBER;
        l_batch     VARCHAR2(4000);
        l_xml       XMLTYPE;
        l_err       NUMBER;
        l_key_type  VARCHAR2(20);
        l_money_ok  VARCHAR2(1) := 'N';
        l_path      DMT_BIP_REPORT_TBL.CMP_REPORT_CATALOG_PATH%TYPE;
        l_bal       VARCHAR2(1);
        l_var_cnt   NUMBER;
    BEGIN
        -- (a) staged total: STG has no RUN_ID and holds duplicate seed rows,
        --     so the TFM run set is the authoritative record set (per discovery).
        SELECT COUNT(*)
          INTO l_stg_cnt
          FROM DMT_PJF_PROJECTS_TFM_TBL
         WHERE RUN_ID = p_run_id;

        -- (b) transform errors: same run set, TFM_STATUS = FAILED.
        SELECT COUNT(*)
          INTO l_err_cnt
          FROM DMT_PJF_PROJECTS_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';

        -- (c) batch key = the exact FUSION_PROJECT_ID list DMT captured on
        --     this run's LOADED rows (KEY_TYPE = CAPTURED_ID). No batch id
        --     round-trips for Projects on this pod (discovery proved it);
        --     never fall back to a prefix or timestamp query.
        SELECT LISTAGG(FUSION_PROJECT_ID, ',') WITHIN GROUP (ORDER BY FUSION_PROJECT_ID)
          INTO l_batch
          FROM DMT_PJF_PROJECTS_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'LOADED'
           AND FUSION_PROJECT_ID IS NOT NULL;

        IF l_batch IS NULL THEN
            -- Still in flight (no LOADED rows captured yet): never report 0
            -- successes as if confirmed.
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, NULL, l_err_cnt, NULL,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No captured FUSION_PROJECT_ID yet (in flight)');
        END IF;
        l_key_type := 'CAPTURED_ID';

        -- (d) live Fusion confirmation via the shared BIP transport -- counts
        --     exactly the captured id list on PJF_PROJECTS_ALL_B.
        SELECT CMP_REPORT_CATALOG_PATH INTO l_path
          FROM DMT_BIP_REPORT_TBL WHERE CEMLI_CODE = C_CEMLI;

        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id      => p_run_id,
            p_cemli_code  => C_CEMLI,
            p_params      => 'P_BATCH_ID|'||l_batch,
            x_report_xml  => l_xml,
            x_error_code  => l_err,
            p_report_path => l_path);

        -- (e) a fault must never read as zero successes.
        IF l_err <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20903,
                'Projects comparison: BIP report error code '||l_err);
        END IF;

        IF l_xml IS NULL THEN
            l_fus_cnt := 0;
        ELSE
            SELECT TO_NUMBER(x.success_count)
              INTO l_fus_cnt
              FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                     success_count VARCHAR2(40) PATH 'SUCCESS_COUNT') x;
        END IF;

        -- (f) count-only balance; no money anywhere in this object.
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_bal := CASE WHEN l_var_cnt = 0 THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, NULL, l_err_cnt, NULL,
            l_fus_cnt, NULL, NULL, l_money_ok,
            l_var_cnt, NULL, l_bal, NULL);
    END GET_PROJECTS_CMP;

    -- ------------------------------------------------------------------
    -- ProjectBudgets. MONEY object (TOTAL_TC_RAW_COST). RUN 132 loaded ZERO
    -- budget rows (0 LOADED, 3 FAILED -- all functionally blocked on this
    -- pod, per discovery docs/superpowers/specs/discovery/ProjectBudgets.md).
    -- The Fusion success side is therefore DESIGNED, not yet confirmed by a
    -- LOADED row: this function is built fully for a future run where rows
    -- do land. Batch key = the captured FUSION_BUDGET_VERSION_ID list on
    -- this run's LOADED TFM rows (KEY_TYPE = CAPTURED_ID; no proven batch-id
    -- round-trip for ProjectBudgets on this pod, so the same prefix-free
    -- captured-id fallback as Projects is used -- never a prefix/timestamp
    -- query). CRITICAL: the base query excludes PJO_PLAN_VERSIONS_B rows
    -- with a NULL PM_BUDGET_REFERENCE -- those are the auto-created "Project
    -- Plan" workplan versions Fusion makes when a project is created; they
    -- are NOT the Approved Cost Budget this FBDI loads and would be a
    -- false-positive if counted (discovery found this live, confirmed 0
    -- rows survive the filter for run 132's prefix).
    -- ------------------------------------------------------------------
    FUNCTION GET_PROJECT_BUDGETS_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        C_CEMLI CONSTANT VARCHAR2(30) := 'ProjectBudgets';
        l_stg_cnt   NUMBER; l_stg_amt NUMBER;
        l_err_cnt   NUMBER; l_err_amt NUMBER;
        l_fus_cnt   NUMBER; l_fus_amt NUMBER;
        l_batch     VARCHAR2(4000);
        l_xml       XMLTYPE;
        l_err       NUMBER;
        l_key_type  VARCHAR2(20);
        l_money_ok  VARCHAR2(1) := 'Y';
        l_path      DMT_BIP_REPORT_TBL.CMP_REPORT_CATALOG_PATH%TYPE;
        l_bal       VARCHAR2(1);
        l_var_cnt   NUMBER; l_var_amt NUMBER;
    BEGIN
        -- (a) staged total: STG has no RUN_ID / holds duplicate seed rows;
        --     TFM run set is authoritative. Money = TOTAL_TC_RAW_COST.
        SELECT COUNT(*), NVL(SUM(TOTAL_TC_RAW_COST), 0)
          INTO l_stg_cnt, l_stg_amt
          FROM DMT_PRJ_BUDGET_TFM_TBL
         WHERE RUN_ID = p_run_id;

        -- (b) transform errors: same run set, TFM_STATUS = FAILED.
        SELECT COUNT(*), NVL(SUM(TOTAL_TC_RAW_COST), 0)
          INTO l_err_cnt, l_err_amt
          FROM DMT_PRJ_BUDGET_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';

        -- (c) batch key = the exact FUSION_BUDGET_VERSION_ID list DMT
        --     captured on this run's LOADED rows.
        SELECT LISTAGG(FUSION_BUDGET_VERSION_ID, ',') WITHIN GROUP (ORDER BY FUSION_BUDGET_VERSION_ID)
          INTO l_batch
          FROM DMT_PRJ_BUDGET_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'LOADED'
           AND FUSION_BUDGET_VERSION_ID IS NOT NULL;

        IF l_batch IS NULL THEN
            -- RUN 132: 0 LOADED. Honest -- all 3 rows are FAILED with real
            -- Fusion errors, so STG (3) = err (3) balances on its own; no
            -- Fusion side to confirm yet. Never fabricate a success count.
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
                0, 0, NULL, l_money_ok,
                l_stg_cnt - l_err_cnt, l_stg_amt - l_err_amt,
                CASE WHEN l_stg_cnt = l_err_cnt AND l_stg_amt = l_err_amt THEN 'Y' ELSE 'N' END,
                NULL);
        END IF;
        l_key_type := 'CAPTURED_ID';

        -- (d) live Fusion confirmation via the shared BIP transport. The
        --     .xdm filters OUT rows with a NULL PM_BUDGET_REFERENCE (the
        --     auto-created "Project Plan" workplan versions) so an
        --     un-referenced workplan version never false-positives as a
        --     loaded budget.
        SELECT CMP_REPORT_CATALOG_PATH INTO l_path
          FROM DMT_BIP_REPORT_TBL WHERE CEMLI_CODE = C_CEMLI;

        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id      => p_run_id,
            p_cemli_code  => C_CEMLI,
            p_params      => 'P_BATCH_ID|'||l_batch,
            x_report_xml  => l_xml,
            x_error_code  => l_err,
            p_report_path => l_path);

        IF l_err <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20903,
                'ProjectBudgets comparison: BIP report error code '||l_err);
        END IF;

        IF l_xml IS NULL THEN
            l_fus_cnt := 0; l_fus_amt := 0;
        ELSE
            SELECT TO_NUMBER(x.success_count), TO_NUMBER(x.success_amount)
              INTO l_fus_cnt, l_fus_amt
              FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                     success_count  VARCHAR2(40) PATH 'SUCCESS_COUNT',
                     success_amount VARCHAR2(40) PATH 'SUCCESS_AMOUNT') x;
        END IF;

        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_var_amt := l_stg_amt - (NVL(l_fus_amt,0) + l_err_amt);
        l_bal := CASE WHEN l_var_cnt = 0 AND l_var_amt = 0 THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
            l_fus_cnt, l_fus_amt, NULL, l_money_ok,
            l_var_cnt, l_var_amt, l_bal, NULL);
    END GET_PROJECT_BUDGETS_CMP;

    -- ------------------------------------------------------------------
    -- Expenditures. MONEY object (DENOM_RAW_COST). BATCH-KEY-FOUND: the
    -- import ESS request id round-trips exactly onto PJC_EXP_ITEMS_ALL.
    -- REQUEST_ID (discovery docs/superpowers/specs/discovery/Expenditures.md,
    -- run 132, confirmed live). Key = DMT_WORK_QUEUE_TBL.IMPORT_ESS_JOB_ID
    -- for this run/CEMLI (there can be more than one queue partition).
    --
    -- IMPORTANT -- Fusion RECOMPUTES cost at import (QUANTITY x the
    -- person/rate schedule), so the loaded base amount legitimately differs
    -- from the submitted STG amount (run 132: submitted 4000, Fusion
    -- recorded 3840). This is NOT a reconciliation defect -- we always
    -- report Fusion's actual DENOM_RAW_COST, never force it to match STG.
    -- Count balances (2 LOADED + 6 FAILED = 8 = STG total); money does not,
    -- by design, and IN_BALANCE is computed on COUNT alone here so this
    -- honest recompute never reads as an accounting error.
    -- ------------------------------------------------------------------
    FUNCTION GET_EXPENDITURES_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        C_CEMLI CONSTANT VARCHAR2(30) := 'Expenditures';
        l_stg_cnt   NUMBER; l_stg_amt NUMBER;
        l_err_cnt   NUMBER; l_err_amt NUMBER;
        l_fus_cnt   NUMBER; l_fus_amt NUMBER; l_ccy VARCHAR2(15);
        l_batch     VARCHAR2(4000);
        l_xml       XMLTYPE;
        l_err       NUMBER;
        l_key_type  VARCHAR2(20);
        l_money_ok  VARCHAR2(1) := 'Y';
        l_path      DMT_BIP_REPORT_TBL.CMP_REPORT_CATALOG_PATH%TYPE;
        l_bal       VARCHAR2(1);
        l_var_cnt   NUMBER; l_var_amt NUMBER;
    BEGIN
        -- (a) staged total: STG has no RUN_ID / holds duplicate seed rows;
        --     TFM run set is authoritative. Money = DENOM_RAW_COST (submitted).
        SELECT COUNT(*), NVL(SUM(DENOM_RAW_COST), 0)
          INTO l_stg_cnt, l_stg_amt
          FROM DMT_PJC_EXPENDITURES_TFM_TBL
         WHERE RUN_ID = p_run_id;

        -- (b) transform errors: same run set, TFM_STATUS = FAILED.
        SELECT COUNT(*), NVL(SUM(DENOM_RAW_COST), 0)
          INTO l_err_cnt, l_err_amt
          FROM DMT_PJC_EXPENDITURES_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';

        -- (c) batch id list = the import ESS request id(s) this run
        --     submitted for Expenditures (multiple work-queue partitions
        --     possible; this durably round-trips onto the base ROW, unlike
        --     WORK_QUEUE_ID which is a DMT-internal partition id only).
        SELECT LISTAGG(IMPORT_ESS_JOB_ID, ',') WITHIN GROUP (ORDER BY IMPORT_ESS_JOB_ID)
          INTO l_batch
          FROM DMT_WORK_QUEUE_TBL
         WHERE RUN_ID = p_run_id AND CEMLI_CODE = C_CEMLI
           AND IMPORT_ESS_JOB_ID IS NOT NULL;

        IF l_batch IS NULL THEN
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No import request id yet (in flight)');
        END IF;
        l_key_type := 'IMPORT_ID';

        -- (d) live Fusion aggregate via the shared BIP transport. The
        --     report returns Fusion's ACTUAL recomputed DENOM_RAW_COST --
        --     never STG's submitted figure.
        SELECT CMP_REPORT_CATALOG_PATH INTO l_path
          FROM DMT_BIP_REPORT_TBL WHERE CEMLI_CODE = C_CEMLI;

        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id      => p_run_id,
            p_cemli_code  => C_CEMLI,
            p_params      => 'P_BATCH_ID|'||l_batch,
            x_report_xml  => l_xml,
            x_error_code  => l_err,
            p_report_path => l_path);

        IF l_err <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20903,
                'Expenditures comparison: BIP report error code '||l_err);
        END IF;

        IF l_xml IS NULL THEN
            l_fus_cnt := 0; l_fus_amt := 0;
        ELSE
            SELECT TO_NUMBER(x.success_count),
                   TO_NUMBER(x.success_amount),
                   x.amount_currency
              INTO l_fus_cnt, l_fus_amt, l_ccy
              FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                     success_count   VARCHAR2(40) PATH 'SUCCESS_COUNT',
                     success_amount  VARCHAR2(40) PATH 'SUCCESS_AMOUNT',
                     amount_currency VARCHAR2(15) PATH 'AMOUNT_CURRENCY') x;
        END IF;

        -- (f) COUNT balance decides IN_BALANCE -- Fusion recomputes cost at
        --     import (QUANTITY x rate), so DENOM_RAW_COST honestly differs
        --     from the submitted figure even on a fully-accounted run. The
        --     money variance is still computed and reported (never hidden),
        --     it simply does not gate IN_BALANCE the way it does for every
        --     other money object in this rollout.
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_var_amt := l_stg_amt - (NVL(l_fus_amt,0) + l_err_amt);
        l_bal := CASE WHEN l_var_cnt = 0 THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
            l_fus_cnt, l_fus_amt, NVL(l_ccy,'USD'), l_money_ok,
            l_var_cnt, l_var_amt, l_bal,
            NULL);
    END GET_EXPENDITURES_CMP;

    -- ------------------------------------------------------------------
    -- BillingEvents. MONEY object (BILL_TRNS_AMOUNT). BATCH-KEY-FOUND: the
    -- import ESS request id round-trips exactly onto PJB_BILLING_EVENTS.
    -- REQUEST_ID (live-confirmed for run 132: REQUEST_ID = 10023972 on
    -- both loaded rows, matching DMT_WORK_QUEUE_TBL.IMPORT_ESS_JOB_ID).
    -- Money round-trips verbatim here (unlike Expenditures) -- balances on
    -- both count and money.
    -- ------------------------------------------------------------------
    FUNCTION GET_BILLING_EVENTS_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        C_CEMLI CONSTANT VARCHAR2(30) := 'BillingEvents';
        l_stg_cnt   NUMBER; l_stg_amt NUMBER;
        l_err_cnt   NUMBER; l_err_amt NUMBER;
        l_fus_cnt   NUMBER; l_fus_amt NUMBER; l_ccy VARCHAR2(15);
        l_batch     VARCHAR2(4000);
        l_xml       XMLTYPE;
        l_err       NUMBER;
        l_key_type  VARCHAR2(20);
        l_money_ok  VARCHAR2(1) := 'Y';
        l_path      DMT_BIP_REPORT_TBL.CMP_REPORT_CATALOG_PATH%TYPE;
        l_bal       VARCHAR2(1);
        l_var_cnt   NUMBER; l_var_amt NUMBER;
    BEGIN
        -- (a) staged total: STG has no RUN_ID / holds duplicate seed rows;
        --     TFM run set is authoritative. Money = BILL_TRNS_AMOUNT.
        SELECT COUNT(*), NVL(SUM(BILL_TRNS_AMOUNT), 0)
          INTO l_stg_cnt, l_stg_amt
          FROM DMT_PJB_BILL_EVENTS_TFM_TBL
         WHERE RUN_ID = p_run_id;

        -- (b) transform errors: same run set, TFM_STATUS = FAILED.
        SELECT COUNT(*), NVL(SUM(BILL_TRNS_AMOUNT), 0)
          INTO l_err_cnt, l_err_amt
          FROM DMT_PJB_BILL_EVENTS_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';

        -- (c) batch id list = the import ESS request id(s) this run
        --     submitted for BillingEvents.
        SELECT LISTAGG(IMPORT_ESS_JOB_ID, ',') WITHIN GROUP (ORDER BY IMPORT_ESS_JOB_ID)
          INTO l_batch
          FROM DMT_WORK_QUEUE_TBL
         WHERE RUN_ID = p_run_id AND CEMLI_CODE = C_CEMLI
           AND IMPORT_ESS_JOB_ID IS NOT NULL;

        IF l_batch IS NULL THEN
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No import request id yet (in flight)');
        END IF;
        l_key_type := 'IMPORT_ID';

        -- (d) live Fusion aggregate via the shared BIP transport.
        SELECT CMP_REPORT_CATALOG_PATH INTO l_path
          FROM DMT_BIP_REPORT_TBL WHERE CEMLI_CODE = C_CEMLI;

        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id      => p_run_id,
            p_cemli_code  => C_CEMLI,
            p_params      => 'P_BATCH_ID|'||l_batch,
            x_report_xml  => l_xml,
            x_error_code  => l_err,
            p_report_path => l_path);

        IF l_err <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20903,
                'BillingEvents comparison: BIP report error code '||l_err);
        END IF;

        IF l_xml IS NULL THEN
            l_fus_cnt := 0; l_fus_amt := 0;
        ELSE
            SELECT TO_NUMBER(x.success_count),
                   TO_NUMBER(x.success_amount),
                   x.amount_currency
              INTO l_fus_cnt, l_fus_amt, l_ccy
              FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                     success_count   VARCHAR2(40) PATH 'SUCCESS_COUNT',
                     success_amount  VARCHAR2(40) PATH 'SUCCESS_AMOUNT',
                     amount_currency VARCHAR2(15) PATH 'AMOUNT_CURRENCY') x;
        END IF;

        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_var_amt := l_stg_amt - (NVL(l_fus_amt,0) + l_err_amt);
        l_bal := CASE WHEN l_var_cnt = 0 AND l_var_amt = 0 THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
            l_fus_cnt, l_fus_amt, NVL(l_ccy,'USD'), l_money_ok,
            l_var_cnt, l_var_amt, l_bal, NULL);
    END GET_BILLING_EVENTS_CMP;

    -- ------------------------------------------------------------------
    -- Grants. COUNT-ONLY -- FT_AMOUNT exists on TFM but is NOT populated for
    -- this run (NULL), so money is not reconcilable here (per discovery
    -- docs/superpowers/specs/discovery/Grants.md). RUN 132 loaded ZERO
    -- awards (0 LOADED, 3 FAILED -- the demo pod's known grants-setup
    -- blocker for two rows, a real required-field rejection for the third).
    -- Grants is env-blocked on this pod, so the Fusion success side is
    -- DESIGNED here, not yet confirmed by a LOADED row; built fully for a
    -- future run. Batch key = DC_REQUEST_ID (verified convention: for
    -- AWARD_SOURCE='FBDI' rows SUMMARY_REQUEST_ID is NULL and DC_REQUEST_ID
    -- carries the real import ESS id) -- never SUMMARY_REQUEST_ID.
    -- ------------------------------------------------------------------
    FUNCTION GET_GRANTS_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        C_CEMLI CONSTANT VARCHAR2(30) := 'Grants';
        l_stg_cnt   NUMBER;
        l_err_cnt   NUMBER;
        l_fus_cnt   NUMBER;
        l_batch     VARCHAR2(4000);
        l_xml       XMLTYPE;
        l_err       NUMBER;
        l_key_type  VARCHAR2(20);
        l_money_ok  VARCHAR2(1) := 'N';
        l_path      DMT_BIP_REPORT_TBL.CMP_REPORT_CATALOG_PATH%TYPE;
        l_bal       VARCHAR2(1);
        l_var_cnt   NUMBER;
    BEGIN
        -- (a) staged total: STG has no RUN_ID / holds duplicate seed rows;
        --     TFM run set is authoritative. RUN 132's RECON_KEYs are NULL
        --     (rejected pre-validation), so scope by RUN_ID only.
        SELECT COUNT(*)
          INTO l_stg_cnt
          FROM DMT_GMS_AWD_HEADERS_TFM_TBL
         WHERE RUN_ID = p_run_id;

        -- (b) transform errors: same run set, TFM_STATUS = FAILED.
        SELECT COUNT(*)
          INTO l_err_cnt
          FROM DMT_GMS_AWD_HEADERS_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';

        -- (c) batch id list = the import ESS request id(s) this run
        --     submitted for Grants (AwardMassImportJob).
        SELECT LISTAGG(IMPORT_ESS_JOB_ID, ',') WITHIN GROUP (ORDER BY IMPORT_ESS_JOB_ID)
          INTO l_batch
          FROM DMT_WORK_QUEUE_TBL
         WHERE RUN_ID = p_run_id AND CEMLI_CODE = C_CEMLI
           AND IMPORT_ESS_JOB_ID IS NOT NULL;

        IF l_batch IS NULL THEN
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, NULL, l_err_cnt, NULL,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No import request id yet (in flight)');
        END IF;
        l_key_type := 'IMPORT_ID';

        -- (d) live Fusion confirmation via the shared BIP transport. The
        --     .xdm scopes by DC_REQUEST_ID = this run's import ESS id AND
        --     AWARD_SOURCE = 'FBDI' -- never SUMMARY_REQUEST_ID, which is
        --     NULL for FBDI-sourced awards (verified convention).
        SELECT CMP_REPORT_CATALOG_PATH INTO l_path
          FROM DMT_BIP_REPORT_TBL WHERE CEMLI_CODE = C_CEMLI;

        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id      => p_run_id,
            p_cemli_code  => C_CEMLI,
            p_params      => 'P_BATCH_ID|'||l_batch,
            x_report_xml  => l_xml,
            x_error_code  => l_err,
            p_report_path => l_path);

        IF l_err <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20903,
                'Grants comparison: BIP report error code '||l_err);
        END IF;

        IF l_xml IS NULL THEN
            l_fus_cnt := 0;
        ELSE
            SELECT TO_NUMBER(x.success_count)
              INTO l_fus_cnt
              FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                     success_count VARCHAR2(40) PATH 'SUCCESS_COUNT') x;
        END IF;

        -- (f) balance on count only; FT_AMOUNT not populated for this run.
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_bal := CASE WHEN l_var_cnt = 0 THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, NULL, l_err_cnt, NULL,
            l_fus_cnt, NULL, NULL, l_money_ok,
            l_var_cnt, NULL, l_bal,
            NULL);
    END GET_GRANTS_CMP;

END DMT_PPM_COMPARE_PKG;
/
