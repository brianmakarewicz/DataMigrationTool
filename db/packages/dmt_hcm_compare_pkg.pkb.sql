CREATE OR REPLACE PACKAGE BODY DMT_HCM_COMPARE_PKG AS

    -- ------------------------------------------------------------------
    -- Workers. COUNT-ONLY -- no monetary attribute anywhere on this object
    -- (docs/superpowers/specs/discovery/Workers.md, run 132). Loads via HDL
    -- (Worker.dat); there is no FBDI import ESS request id. The Fusion
    -- tie-back is the HDL key map: HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID
    -- (OBJECT_NAME='Person') equals the TFM row's RECON_KEY (the prefixed
    -- PERSON_NUMBER); SURROGATE_ID is the base PER_ALL_PEOPLE_F.PERSON_ID and
    -- equals the captured FUSION_PERSON_ID. Batch key = the exact RECON_KEY
    -- list of this run's LOADED TFM rows (KEY_TYPE = STAMPED_REF) -- an
    -- exact per-record match, never a prefix wildcard or timestamp window.
    -- ------------------------------------------------------------------
    FUNCTION GET_WORKERS_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        C_CEMLI CONSTANT VARCHAR2(30) := 'Workers';
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
        -- (a) staged total: STG has no RUN_ID, joined via the run's TFM rows
        --     (STG_SEQUENCE_ID). Count-only, no money column.
        SELECT COUNT(*)
          INTO l_stg_cnt
          FROM DMT_WORKER_STG_TBL s
         WHERE s.STG_SEQUENCE_ID IN (
                 SELECT t.STG_SEQUENCE_ID
                   FROM DMT_WORKER_TFM_TBL t
                  WHERE t.RUN_ID = p_run_id);

        -- (b) transform errors: same run set, TFM_STATUS = FAILED.
        SELECT COUNT(*)
          INTO l_err_cnt
          FROM DMT_WORKER_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';

        -- (c) batch key = the exact RECON_KEY list of this run's LOADED TFM
        --     rows -- the HDL SourceSystemId that round-trips onto
        --     HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID. Never a prefix scan.
        SELECT LISTAGG(RECON_KEY, ',') WITHIN GROUP (ORDER BY RECON_KEY)
          INTO l_batch
          FROM DMT_WORKER_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'LOADED'
           AND RECON_KEY IS NOT NULL;

        IF l_batch IS NULL THEN
            -- Still in flight (no LOADED rows captured yet): never report 0
            -- successes as if confirmed.
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, NULL, l_err_cnt, NULL,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No LOADED RECON_KEY yet (in flight)', NULL, NULL, NULL);
        END IF;
        l_key_type := 'STAMPED_REF';

        -- (d) live Fusion confirmation via the shared BIP transport -- the
        --     .xdm joins HRC_INTEGRATION_KEY_MAP (OBJECT_NAME='Person') to
        --     PER_ALL_PEOPLE_F by SURROGATE_ID, scoped to the exact
        --     RECON_KEY list passed as :P_BATCH_ID.
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
                'Workers comparison: BIP report error code '||l_err);
        END IF;

        IF l_xml IS NULL THEN
            l_fus_cnt := 0;
        ELSE
            SELECT TO_NUMBER(x.success_count)
              INTO l_fus_cnt
              FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                     success_count VARCHAR2(40) PATH 'SUCCESS_COUNT') x;
        END IF;

        -- (f) count-only balance; no money grain exists for Workers.
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_bal := CASE WHEN l_var_cnt = 0 THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, NULL, l_err_cnt, NULL,
            l_fus_cnt, NULL, NULL, l_money_ok,
            l_var_cnt, NULL, l_bal, NULL, NULL, NULL, NULL);
    END GET_WORKERS_CMP;

    -- ------------------------------------------------------------------
    -- Salaries. MONEY object (SALARY_AMOUNT). Loads via HDL (Salary.dat);
    -- no FBDI import ESS request id. Tie-back is the HDL key map:
    -- HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID (OBJECT_NAME='Salary')
    -- equals the TFM row's RECON_KEY (prefixed PERSON_NUMBER || '_SAL');
    -- SURROGATE_ID = CMP_SALARY.SALARY_ID = captured FUSION_SALARY_ID.
    -- Money is read live from CMP_SALARY.SALARY_AMOUNT (TFM's SALARY_AMOUNT
    -- is VARCHAR2, so TO_NUMBER for sums; currency is NULL on TFM -- derived
    -- at Fusion -- so currency is read live from CMP_SALARY, never TFM).
    -- Batch key = the exact RECON_KEY list of this run's LOADED TFM rows
    -- (KEY_TYPE = STAMPED_REF) -- an exact per-record match, never a prefix
    -- wildcard or timestamp window. Run 132: balances on both count and
    -- money (75,000 Fusion success + 80,000 TFM error = 155,000 STG).
    -- ------------------------------------------------------------------
    FUNCTION GET_SALARIES_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        C_CEMLI CONSTANT VARCHAR2(30) := 'Salaries';
        l_stg_cnt   NUMBER; l_stg_amt   NUMBER;
        l_err_cnt   NUMBER; l_err_amt   NUMBER;
        l_fus_cnt   NUMBER; l_fus_amt   NUMBER; l_ccy VARCHAR2(15);
        l_batch     VARCHAR2(4000);
        l_xml       XMLTYPE;
        l_err       NUMBER;
        l_key_type  VARCHAR2(20);
        l_money_ok  VARCHAR2(1) := 'Y';
        l_path      DMT_BIP_REPORT_TBL.CMP_REPORT_CATALOG_PATH%TYPE;
        l_bal       VARCHAR2(1);
        l_var_cnt   NUMBER; l_var_amt NUMBER;
    BEGIN
        -- (a) staged total: STG has no RUN_ID, joined via the run's TFM rows
        --     (STG_SEQUENCE_ID). Money = SALARY_AMOUNT (VARCHAR2 on STG/TFM).
        SELECT COUNT(*), NVL(SUM(TO_NUMBER(s.SALARY_AMOUNT DEFAULT NULL ON CONVERSION ERROR)), 0)
          INTO l_stg_cnt, l_stg_amt
          FROM DMT_SALARY_STG_TBL s
         WHERE s.STG_SEQUENCE_ID IN (
                 SELECT t.STG_SEQUENCE_ID
                   FROM DMT_SALARY_TFM_TBL t
                  WHERE t.RUN_ID = p_run_id);

        -- (b) transform errors: same run set, TFM_STATUS = FAILED. The
        --     FAILED row's amount still counts toward the error total -- a
        --     rejected salary is honestly reported, not dropped.
        SELECT COUNT(*), NVL(SUM(TO_NUMBER(SALARY_AMOUNT DEFAULT NULL ON CONVERSION ERROR)), 0)
          INTO l_err_cnt, l_err_amt
          FROM DMT_SALARY_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';

        -- (c) batch key = the exact RECON_KEY list of this run's LOADED TFM
        --     rows -- the HDL SourceSystemId that round-trips onto
        --     HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID. Never a prefix scan.
        SELECT LISTAGG(RECON_KEY, ',') WITHIN GROUP (ORDER BY RECON_KEY)
          INTO l_batch
          FROM DMT_SALARY_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'LOADED'
           AND RECON_KEY IS NOT NULL;

        IF l_batch IS NULL THEN
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No LOADED RECON_KEY yet (in flight)', NULL, NULL, NULL);
        END IF;
        l_key_type := 'STAMPED_REF';

        -- (d) live Fusion confirmation via the shared BIP transport -- the
        --     .xdm joins HRC_INTEGRATION_KEY_MAP (OBJECT_NAME='Salary') to
        --     CMP_SALARY by SURROGATE_ID, scoped to the exact RECON_KEY
        --     list passed as :P_BATCH_ID; money read live from CMP_SALARY.
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
                'Salaries comparison: BIP report error code '||l_err);
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

        -- (f) variance + balance on both count and money.
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_var_amt := l_stg_amt - (NVL(l_fus_amt,0) + l_err_amt);
        l_bal := CASE WHEN l_var_cnt = 0 AND l_var_amt = 0
                      THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
            l_fus_cnt, l_fus_amt, NVL(l_ccy,'USD'), l_money_ok,
            l_var_cnt, l_var_amt, l_bal, NULL, NULL, NULL, NULL);
    END GET_SALARIES_CMP;

    -- ------------------------------------------------------------------
    -- TalentProfiles. COUNT-ONLY -- no monetary attribute. Loads via HDL
    -- (TalentProfile.dat + ProfileItem.dat, one zip); no FBDI import ESS
    -- request id. RUN 132 loaded ZERO profiles (0 LOADED, 2 FAILED -- a
    -- known generator forward-fix: an invalid ProfileItem METADATA attribute
    -- rejects the ENTIRE HDL file, so even the otherwise-valid GOOD record
    -- fails alongside the BAD one; both carry the real Fusion rejection
    -- message). The Fusion success side is therefore DESIGNED, not yet
    -- confirmed by a LOADED row -- this function is built fully for a
    -- future run where rows do land, mirroring the ProjectBudgets/Grants
    -- honest-0-loaded pattern (DMT_PPM_COMPARE_PKG).
    --
    -- Key path (HDL tie-back) -- the parent Profile gets NO key-map row of
    -- its own on this pod; it is reached through the CHILD ProfileItem:
    -- HRC_INTEGRATION_KEY_MAP (OBJECT_NAME='ProfileItem',
    -- SOURCE_SYSTEM_OWNER='HRC_SQLLOADER') maps SOURCE_SYSTEM_ID (the
    -- child's RECON_KEY, prefixed PERSON_NUMBER || '_TPITM') to
    -- SURROGATE_ID = HRT_PROFILE_ITEMS.PROFILE_ITEM_ID; the item's
    -- PROFILE_ID column points to the parent HRT_PROFILES_B row. Since the
    -- parent TFM table's own RECON_KEY (PERSON_NUMBER || '_TPROF') does not
    -- appear in the key map directly, the batch key passed to Fusion is
    -- built from the SAME per-run LOADED-TFM-row scope translated to the
    -- child suffix (_TPITM) that the .xdm's key-map join actually matches;
    -- with 0 LOADED rows this run the batch is never built and the function
    -- takes the honest-zero branch below (mirrors ProjectBudgets/Grants).
    -- ------------------------------------------------------------------
    FUNCTION GET_TALENT_PROFILES_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        C_CEMLI CONSTANT VARCHAR2(30) := 'TalentProfiles';
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
        -- (a) staged total: STG has no RUN_ID, joined via the run's TFM rows
        --     (STG_SEQUENCE_ID). Count-only, no money column.
        SELECT COUNT(*)
          INTO l_stg_cnt
          FROM DMT_TALENT_PROF_STG_TBL s
         WHERE s.STG_SEQUENCE_ID IN (
                 SELECT t.STG_SEQUENCE_ID
                   FROM DMT_TALENT_PROF_TFM_TBL t
                  WHERE t.RUN_ID = p_run_id);

        -- (b) transform errors: same run set, TFM_STATUS = FAILED.
        SELECT COUNT(*)
          INTO l_err_cnt
          FROM DMT_TALENT_PROF_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';

        -- (c) batch key = the exact child-ProfileItem RECON_KEY list of this
        --     run's LOADED parent TFM rows, translated to the item-level
        --     SourceSystemId suffix the key map actually stores (RECON_KEY
        --     stores PERSON_NUMBER||'_TPROF' on the parent row; the item's
        --     key-map SOURCE_SYSTEM_ID is PERSON_NUMBER||'_TPITM' --
        --     substitute the suffix rather than assume it matches). No
        --     prefix scan and no timestamp window either way.
        SELECT LISTAGG(
                 REGEXP_REPLACE(RECON_KEY, '_TPROF$', '_TPITM'), ','
               ) WITHIN GROUP (ORDER BY RECON_KEY)
          INTO l_batch
          FROM DMT_TALENT_PROF_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'LOADED'
           AND RECON_KEY IS NOT NULL;

        IF l_batch IS NULL THEN
            -- RUN 132: 0 LOADED. Honest -- both rows are FAILED with a real
            -- Fusion whole-file-rejection error, so STG (2) = err (2)
            -- balances on its own; no Fusion side to confirm yet. Never
            -- fabricate a success count (mirrors ProjectBudgets/Grants).
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, NULL, l_err_cnt, NULL,
                0, NULL, NULL, l_money_ok,
                l_stg_cnt - l_err_cnt, NULL,
                CASE WHEN l_stg_cnt = l_err_cnt THEN 'Y' ELSE 'N' END,
                NULL, NULL, NULL, NULL);
        END IF;
        l_key_type := 'STAMPED_REF';

        -- (d) live Fusion confirmation via the shared BIP transport -- the
        --     .xdm joins HRC_INTEGRATION_KEY_MAP (OBJECT_NAME='ProfileItem',
        --     SOURCE_SYSTEM_OWNER='HRC_SQLLOADER') to HRT_PROFILE_ITEMS by
        --     SURROGATE_ID, confirms the parent exists in HRT_PROFILES_B,
        --     and counts DISTINCT parent PROFILE_ID -- the object's verdict
        --     grain is the parent profile, not the child item.
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
                'TalentProfiles comparison: BIP report error code '||l_err);
        END IF;

        IF l_xml IS NULL THEN
            l_fus_cnt := 0;
        ELSE
            SELECT TO_NUMBER(x.success_count)
              INTO l_fus_cnt
              FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                     success_count VARCHAR2(40) PATH 'SUCCESS_COUNT') x;
        END IF;

        -- (f) count-only balance; no money grain exists for TalentProfiles.
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_bal := CASE WHEN l_var_cnt = 0 THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, NULL, l_err_cnt, NULL,
            l_fus_cnt, NULL, NULL, l_money_ok,
            l_var_cnt, NULL, l_bal, NULL, NULL, NULL, NULL);
    END GET_TALENT_PROFILES_CMP;

END DMT_HCM_COMPARE_PKG;
/
