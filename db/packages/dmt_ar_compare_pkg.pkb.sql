CREATE OR REPLACE PACKAGE BODY DMT_AR_COMPARE_PKG AS
    C_CEMLI CONSTANT VARCHAR2(30) := 'ARInvoices';

    FUNCTION GET_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
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
        -- (a) staged total for the run's AR invoice lines. STG has no RUN_ID;
        --     the run's record set is the TFM line rows for the run.
        SELECT COUNT(*),
               NVL(SUM(AMOUNT), 0)
          INTO l_stg_cnt, l_stg_amt
          FROM DMT_RA_LINES_TFM_TBL
         WHERE RUN_ID = p_run_id;

        -- (b) transform errors: TFM_STATUS = FAILED, line grain.
        SELECT COUNT(*),
               NVL(SUM(AMOUNT), 0)
          INTO l_err_cnt, l_err_amt
          FROM DMT_RA_LINES_TFM_TBL
         WHERE RUN_ID = p_run_id
           AND TFM_STATUS = 'FAILED';

        -- (c) batch id list = every load/import ESS request id this run
        --     submitted for ARInvoices. AutoInvoice can split one FBDI's
        --     lines across several load requests (grouped by BU + batch
        --     source); both LOAD_ESS_JOB_ID and IMPORT_ESS_JOB_ID are
        --     included so the report filters on the full known id set, never
        --     a single job id and never the prefix.
        SELECT LISTAGG(job_id, ',') WITHIN GROUP (ORDER BY job_id)
          INTO l_batch
          FROM (
              SELECT DISTINCT LOAD_ESS_JOB_ID AS job_id
                FROM DMT_WORK_QUEUE_TBL
               WHERE RUN_ID = p_run_id AND CEMLI_CODE = C_CEMLI
                 AND LOAD_ESS_JOB_ID IS NOT NULL
              UNION
              SELECT DISTINCT IMPORT_ESS_JOB_ID
                FROM DMT_WORK_QUEUE_TBL
               WHERE RUN_ID = p_run_id AND CEMLI_CODE = C_CEMLI
                 AND IMPORT_ESS_JOB_ID IS NOT NULL
          );

        IF l_batch IS NULL THEN
            -- Still in flight: no import request id yet. Never report 0
            -- successes as if it were a confirmed empty result.
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No import request id yet (in flight)');
        END IF;
        l_key_type := 'IMPORT_ID';

        -- (d) live Fusion aggregate via the shared BIP transport. The report
        --     joins RA_CUSTOMER_TRX_LINES_ALL to RA_CUSTOMER_TRX_ALL and
        --     filters on the header REQUEST_ID list -- AutoInvoice's own job
        --     request id(s), not the prefix.
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
                'ARInvoices comparison: BIP report error code '||l_err);
        END IF;

        IF l_xml IS NULL THEN
            -- No <reportBytes> -- honest 0 successes (e.g. AutoInvoice
            -- job-level abort, no base line created this run).
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

        -- (f) variance + balance; money variance only when money is available.
        --     Money exists conceptually for AR invoices, so FUSION_MONEY_AVAILABLE
        --     stays 'Y' even when this run's Fusion amount is honestly 0 --
        --     the money grain is real, just empty because 0 rows loaded.
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_var_amt := CASE WHEN l_money_ok = 'Y'
                          THEN l_stg_amt - (NVL(l_fus_amt,0) + l_err_amt) END;
        l_bal := CASE WHEN l_var_cnt = 0
                        AND (l_money_ok = 'N' OR l_var_amt = 0)
                      THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
            l_fus_cnt, l_fus_amt, NVL(l_ccy,'USD'), l_money_ok,
            l_var_cnt, l_var_amt, l_bal, NULL);
    END GET_COMPARISON;
END DMT_AR_COMPARE_PKG;
/
