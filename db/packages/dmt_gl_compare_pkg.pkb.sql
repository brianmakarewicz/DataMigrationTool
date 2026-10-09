CREATE OR REPLACE PACKAGE BODY DMT_GL_COMPARE_PKG AS

    -- ------------------------------------------------------------------
    -- GLBalances. Grain = journal LINE (one DMT_GL_INTERFACE_TFM_TBL row =
    -- one gl_je_lines row). STG has no RUN_ID; the run's staged set is the
    -- STG rows referenced by this run's TFM rows (STG_SEQUENCE_ID join).
    -- Money = ENTERED_DR (headline) with ENTERED_CR tracked alongside per
    -- discovery; ACCOUNTED amounts are NULL on the DMT side for this run
    -- (single-currency test data) so they are never used here.
    -- Key = STAMPED_REF: GL_JE_BATCHES.GROUP_ID carries prefix || the GLBalances
    -- work queue id (stamped at generation, backlog #173) and survives Journal
    -- Import -- the live Fusion query filters on jb.group_id = that id
    -- (passed as :P_BATCH_ID), never a prefix and never a timestamp window.
    -- A Fusion "success" is a journal LINE whose HEADER balances
    -- (running_total_dr = running_total_cr) and is therefore postable.
    -- Every attempted line physically lands in gl_je_lines regardless of
    -- outcome -- presence alone does NOT mean success for GL, the opposite
    -- of most interface tables -- so the aggregate report itself must
    -- split on header balance, not on row presence.
    -- ------------------------------------------------------------------
    FUNCTION GET_BALANCES_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        C_CEMLI CONSTANT VARCHAR2(30) := 'GLBalances';
        l_stg_cnt   NUMBER; l_stg_amt   NUMBER;
        l_err_cnt   NUMBER; l_err_amt   NUMBER;
        l_fus_cnt   NUMBER; l_fus_amt   NUMBER;
        l_batch     VARCHAR2(4000);
        l_xml       XMLTYPE;
        l_err       NUMBER;
        l_key_type  VARCHAR2(20);
        l_money_ok  VARCHAR2(1) := 'Y';
        l_path      DMT_BIP_REPORT_TBL.CMP_REPORT_CATALOG_PATH%TYPE;
        l_bal       VARCHAR2(1);
        l_var_cnt   NUMBER; l_var_amt NUMBER;
    BEGIN
        -- (a) staged total for this run's GL interface lines, reached via
        --     the TFM join (STG carries no RUN_ID). Money = ENTERED_DR.
        SELECT COUNT(*), NVL(SUM(s.ENTERED_DR), 0)
          INTO l_stg_cnt, l_stg_amt
          FROM DMT_GL_INTERFACE_STG_TBL s
         WHERE s.STG_SEQUENCE_ID IN (
                 SELECT t.STG_SEQUENCE_ID
                   FROM DMT_GL_INTERFACE_TFM_TBL t
                  WHERE t.RUN_ID = p_run_id);

        -- (b) transform errors: lines whose journal was honestly rejected
        --     (unbalanced -> will not post), TFM_STATUS = FAILED.
        SELECT COUNT(*), NVL(SUM(ENTERED_DR), 0)
          INTO l_err_cnt, l_err_amt
          FROM DMT_GL_INTERFACE_TFM_TBL
         WHERE RUN_ID = p_run_id
           AND TFM_STATUS = 'FAILED';

        -- (c) batch = the run's GL group (prefix || work queue id), stamped into GROUP_ID
        --     at generation. Only meaningful once this run actually
        --     staged GL rows; otherwise there is nothing to key Fusion on.
        IF l_stg_cnt = 0 AND l_err_cnt = 0 THEN
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No GL interface rows staged for this run yet (in flight)', NULL, NULL, NULL);
        END IF;
        -- GROUP_ID is prefix || the GLBalances work queue id (backlog #173), stamped on
        -- every line at generation; the run's GL batches carry that group.
        SELECT TO_CHAR(MAX(GROUP_ID)) INTO l_batch
          FROM DMT_GL_INTERFACE_TFM_TBL
         WHERE RUN_ID = p_run_id;
        l_batch    := NVL(l_batch, TO_CHAR(p_run_id));
        l_key_type := 'STAMPED_REF';

        -- (d) live Fusion aggregate via the shared BIP transport. The
        --     report itself splits on journal-header balance to decide
        --     SUCCESS vs ERROR at the header level (never on row presence).
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
                'GLBalances comparison: BIP report error code '||l_err);
        END IF;

        IF l_xml IS NULL THEN
            l_fus_cnt := 0; l_fus_amt := 0;
        ELSE
            SELECT TO_NUMBER(x.success_count),
                   TO_NUMBER(x.success_amount)
              INTO l_fus_cnt, l_fus_amt
              FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                     success_count  VARCHAR2(40) PATH 'SUCCESS_COUNT',
                     success_amount VARCHAR2(40) PATH 'SUCCESS_AMOUNT') x;
        END IF;

        -- (f) variance + balance on ENTERED_DR (the headline amount).
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_var_amt := l_stg_amt - (NVL(l_fus_amt,0) + l_err_amt);
        l_bal := CASE WHEN l_var_cnt = 0 AND l_var_amt = 0
                      THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
            l_fus_cnt, l_fus_amt, 'USD', l_money_ok,
            l_var_cnt, l_var_amt, l_bal, NULL, NULL, NULL, NULL);
    END GET_BALANCES_COMPARISON;

    -- ------------------------------------------------------------------
    -- GLBudgets. Grain = budget CELL (LEDGER_ID + BUDGET_NAME + PERIOD_NAME
    -- + CURRENCY_CODE + SEGMENT1..30), not a transaction. STG has no
    -- RUN_ID; reached via the TFM join on STG_SEQUENCE_ID. Money =
    -- BUDGET_AMOUNT (the single FBDI amount a budget line carries).
    -- Key = CAPTURED_ID: a loaded cell has NO batch/request/group column at
    -- all (proven live in discovery -- the only near-match column on
    -- GL_BUDGET_BALANCES is OBJECT_VERSION_NUMBER, an optimistic-lock
    -- counter). The production-valid key is the exact
    -- CODE_COMBINATION_ID list DMT already captured on this run's LOADED
    -- TFM rows (column FUSION_BUDGET_VERSION_ID -- a documented misnomer;
    -- backlog #87 it now stores the cell composite
    -- ledger~budget~period~code_combination_id, and the CCID is extracted
    -- from it here, never a budget version id) plus the
    -- budget name. NO time window (LAST_UPDATE_DATE scoping was the first
    -- approach discovery tried and proved unreliable; it is never used
    -- here). Base table = GL_BUDGET_BALANCES, never GL_BALANCES (which
    -- carries zero budget rows on this instance).
    -- ------------------------------------------------------------------
    FUNCTION GET_BUDGETS_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        C_CEMLI CONSTANT VARCHAR2(30) := 'GLBudgets';
        l_stg_cnt   NUMBER; l_stg_amt   NUMBER;
        l_err_cnt   NUMBER; l_err_amt   NUMBER;
        l_fus_cnt   NUMBER; l_fus_amt   NUMBER;
        l_batch     VARCHAR2(4000);
        l_xml       XMLTYPE;
        l_err       NUMBER;
        l_key_type  VARCHAR2(20);
        l_money_ok  VARCHAR2(1) := 'Y';
        l_path      DMT_BIP_REPORT_TBL.CMP_REPORT_CATALOG_PATH%TYPE;
        l_bal       VARCHAR2(1);
        l_var_cnt   NUMBER; l_var_amt NUMBER;
        l_budget_name VARCHAR2(100);
    BEGIN
        -- (a) staged total for this run's budget cells, reached via the
        --     TFM join (STG carries no RUN_ID). Money = BUDGET_AMOUNT.
        SELECT COUNT(*), NVL(SUM(s.BUDGET_AMOUNT), 0)
          INTO l_stg_cnt, l_stg_amt
          FROM DMT_GL_BUDGET_INT_STG_TBL s
         WHERE s.STG_SEQUENCE_ID IN (
                 SELECT t.STG_SEQUENCE_ID
                   FROM DMT_GL_BUDGET_INT_TFM_TBL t
                  WHERE t.RUN_ID = p_run_id);

        -- (b) transform errors: cells honestly rejected by Fusion (e.g. an
        --     invalid budget name), TFM_STATUS = FAILED.
        SELECT COUNT(*), NVL(SUM(BUDGET_AMOUNT), 0)
          INTO l_err_cnt, l_err_amt
          FROM DMT_GL_BUDGET_INT_TFM_TBL
         WHERE RUN_ID = p_run_id
           AND TFM_STATUS = 'FAILED';

        -- (c) captured-id batch: the CODE_COMBINATION_ID list DMT stored on
        --     this run's LOADED TFM rows plus the budget name, so the report
        --     can resolve each cell with no time window.
        --     Backlog #87: FUSION_BUDGET_VERSION_ID now holds the full cell
        --     composite ledger~budget~period~code_combination_id, not the bare
        --     CCID. The compare report (GL_BUDGET_CMP_DM) still keys on bare
        --     CODE_COMBINATION_ID (TO_NUMBER over a comma list), so pull the
        --     CCID back out -- it is the segment after the LAST tilde.
        SELECT LISTAGG(REGEXP_SUBSTR(FUSION_BUDGET_VERSION_ID, '[^~]+$'), ',')
                 WITHIN GROUP (ORDER BY FUSION_BUDGET_VERSION_ID),
               MAX(BUDGET_NAME)
          INTO l_batch, l_budget_name
          FROM DMT_GL_BUDGET_INT_TFM_TBL
         WHERE RUN_ID = p_run_id
           AND TFM_STATUS = 'LOADED'
           AND FUSION_BUDGET_VERSION_ID IS NOT NULL;

        IF l_batch IS NULL THEN
            -- Still in flight, or nothing loaded yet: no captured ids to
            -- key Fusion on. Never report 0 successes as a verdict.
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No captured CODE_COMBINATION_ID on a LOADED row yet (in flight)', NULL, NULL, NULL);
        END IF;
        l_key_type := 'CAPTURED_ID';

        -- (d) live Fusion aggregate via the shared BIP transport, keyed on
        --     the captured CCID list + budget name -- no LAST_UPDATE_DATE
        --     window, per discovery's production key resolution.
        SELECT CMP_REPORT_CATALOG_PATH INTO l_path
          FROM DMT_BIP_REPORT_TBL WHERE CEMLI_CODE = C_CEMLI;

        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id      => p_run_id,
            p_cemli_code  => C_CEMLI,
            p_params      => 'P_BATCH_ID|'||l_batch||DMT_UTIL_PKG.C_BIP_PARAM_SEP||'P_BUDGET_NAME|'||l_budget_name,
            x_report_xml  => l_xml,
            x_error_code  => l_err,
            p_report_path => l_path);

        -- (e) a fault must never read as zero successes.
        IF l_err <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20903,
                'GLBudgets comparison: BIP report error code '||l_err);
        END IF;

        IF l_xml IS NULL THEN
            l_fus_cnt := 0; l_fus_amt := 0;
        ELSE
            SELECT TO_NUMBER(x.success_count),
                   TO_NUMBER(x.success_amount)
              INTO l_fus_cnt, l_fus_amt
              FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                     success_count  VARCHAR2(40) PATH 'SUCCESS_COUNT',
                     success_amount VARCHAR2(40) PATH 'SUCCESS_AMOUNT') x;
        END IF;

        -- (f) variance + balance on BUDGET_AMOUNT.
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_var_amt := l_stg_amt - (NVL(l_fus_amt,0) + l_err_amt);
        l_bal := CASE WHEN l_var_cnt = 0 AND l_var_amt = 0
                      THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
            l_fus_cnt, l_fus_amt, 'USD', l_money_ok,
            l_var_cnt, l_var_amt, l_bal, NULL, NULL, NULL, NULL);
    END GET_BUDGETS_COMPARISON;

END DMT_GL_COMPARE_PKG;
/
