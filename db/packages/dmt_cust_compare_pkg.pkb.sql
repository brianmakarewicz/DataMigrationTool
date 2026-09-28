CREATE OR REPLACE PACKAGE BODY DMT_CUST_COMPARE_PKG AS
    C_CEMLI CONSTANT VARCHAR2(30) := 'Customers';

    FUNCTION GET_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        l_stg_cnt   NUMBER;
        l_err_cnt   NUMBER;
        l_batch     VARCHAR2(4000);
        l_xml       XMLTYPE;
        l_err       NUMBER;
        l_key_type  VARCHAR2(20);
        l_money_ok  VARCHAR2(1) := 'N';
        l_path      DMT_BIP_REPORT_TBL.CMP_REPORT_CATALOG_PATH%TYPE;
        l_bal       VARCHAR2(1);
        l_var_cnt   NUMBER;
        l_fus_cnt   NUMBER;
    BEGIN
        -- (a) staged total for the run's Accounts record type. STG has no
        --     RUN_ID; the run's record set is the TFM rows for the run.
        SELECT COUNT(*)
          INTO l_stg_cnt
          FROM DMT_HZ_ACCOUNTS_TFM_TBL
         WHERE RUN_ID = p_run_id;

        -- (b) transform errors: TFM_STATUS = FAILED, account grain.
        SELECT COUNT(*)
          INTO l_err_cnt
          FROM DMT_HZ_ACCOUNTS_TFM_TBL
         WHERE RUN_ID = p_run_id
           AND TFM_STATUS = 'FAILED';

        -- (c) batch = the comma-separated list of this run's per-record
        --     CUST_ORIG_SYSTEM_REFERENCE values (already run-prefixed by the
        --     transform). NEVER a prefix wildcard: each value is matched
        --     individually against HZ_ORIG_SYS_REFERENCES by the BIP report's
        --     IN-list, so only genuine per-record references count -- there
        --     is no LIKE '<prefix>%' scan anywhere in this path.
        SELECT LISTAGG(CUST_ORIG_SYSTEM_REFERENCE, ',')
                 WITHIN GROUP (ORDER BY CUST_ORIG_SYSTEM_REFERENCE)
          INTO l_batch
          FROM DMT_HZ_ACCOUNTS_TFM_TBL
         WHERE RUN_ID = p_run_id
           AND CUST_ORIG_SYSTEM_REFERENCE IS NOT NULL;

        IF l_batch IS NULL THEN
            -- Still in flight: no per-record references staged yet.
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, NULL, l_err_cnt, NULL,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No captured customer reference yet (in flight)');
        END IF;
        l_key_type := 'CAPTURED_ID';

        -- (d) live Fusion aggregate via the shared BIP transport. The report
        --     matches each individual reference in the IN-list against
        --     HZ_ORIG_SYS_REFERENCES for OWNER_TABLE_NAME='HZ_CUST_ACCOUNTS'
        --     -- a per-record business-key join, not a prefix scan.
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
                'Customers comparison: BIP report error code '||l_err);
        END IF;

        IF l_xml IS NULL THEN
            l_fus_cnt := 0;
        ELSE
            SELECT TO_NUMBER(x.success_count)
              INTO l_fus_cnt
              FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                     success_count VARCHAR2(40) PATH 'SUCCESS_COUNT') x;
        END IF;

        -- (f) count-only: no money anywhere for Customers.Accounts.
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_bal := CASE WHEN l_var_cnt = 0 THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, NULL, l_err_cnt, NULL,
            l_fus_cnt, NULL, NULL, l_money_ok,
            l_var_cnt, NULL, l_bal, NULL);
    END GET_COMPARISON;
END DMT_CUST_COMPARE_PKG;
/
