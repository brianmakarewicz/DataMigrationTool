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
        l_stg_chk   VARCHAR2(80);
        l_fus_chk   VARCHAR2(80);
        l_match     VARCHAR2(1);
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

        -- Backlog #94 STG-side business-key checksum. Business key per
        -- DMT_DESIGN.html = "PREFIX + CUST_ORIG_SYSTEM_REFERENCE"; the TFM
        -- CUST_ORIG_SYSTEM_REFERENCE already carries the run prefix. On the
        -- Fusion side that same reference is stored verbatim in
        -- HZ_ORIG_SYS_REFERENCES.ORIG_SYSTEM_REFERENCE for
        -- OWNER_TABLE_NAME='HZ_CUST_ACCOUNTS' (verified live on the demo
        -- instance: 93270RT-ACCT-G2/G3 round-trip byte-for-byte). So this TFM
        -- reference is the correct cross-side key.
        --
        -- Grain note: we checksum the LOADABLE set (TFM_STATUS != 'FAILED'),
        -- i.e. the rows this run sent to Fusion. A per-record Fusion reject is
        -- still non-FAILED here until reconciliation marks it, so for a brief
        -- window after a load the STG set can be a superset of what landed and
        -- KEY_MATCH may read 'N'. That is expected and settles to 'Y' once
        -- every row is accounted. EXACT MIRROR of the Fusion-side expression
        -- in CUST_CMP_DM.xdm: distinct UPPER(TRIM(ref)), SUM(ORA_HASH) ||':'||
        -- COUNT.
        SELECT TO_CHAR(NVL(SUM(ORA_HASH(k)),0)) || ':' || COUNT(*)
          INTO l_stg_chk
          FROM (
            SELECT DISTINCT UPPER(TRIM(CUST_ORIG_SYSTEM_REFERENCE)) AS k
              FROM DMT_HZ_ACCOUNTS_TFM_TBL
             WHERE RUN_ID = p_run_id
               AND CUST_ORIG_SYSTEM_REFERENCE IS NOT NULL
               AND NVL(TFM_STATUS,'x') != 'FAILED'
          );

        IF l_batch IS NULL THEN
            -- Still in flight: no per-record references staged yet. STG-side
            -- checksum is known; Fusion side / match unknown.
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, NULL, l_err_cnt, NULL,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No captured customer reference yet (in flight)',
                l_stg_chk, NULL,
                CASE WHEN l_stg_chk IS NOT NULL THEN '?' END);
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
            l_fus_chk := NULL;
        ELSE
            SELECT TO_NUMBER(x.success_count), x.key_checksum
              INTO l_fus_cnt, l_fus_chk
              FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                     success_count VARCHAR2(40) PATH 'SUCCESS_COUNT',
                     key_checksum  VARCHAR2(80) PATH 'KEY_CHECKSUM') x;
        END IF;

        -- (f) count-only: no money anywhere for Customers.Accounts.
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_bal := CASE WHEN l_var_cnt = 0 THEN 'Y' ELSE 'N' END;

        -- KEY_MATCH: a non-money equality signal. Y when both sides present
        -- and equal, N when both present and differ, ? when either side could
        -- not be computed. (l_stg_chk is always non-null here -- Customers is
        -- wired -- so it never goes to the "not computed" NULL state.)
        IF l_stg_chk IS NULL THEN
            l_match := NULL;
        ELSIF l_fus_chk IS NULL THEN
            l_match := '?';
        ELSIF l_stg_chk = l_fus_chk THEN
            l_match := 'Y';
        ELSE
            l_match := 'N';
        END IF;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, NULL, l_err_cnt, NULL,
            l_fus_cnt, NULL, NULL, l_money_ok,
            l_var_cnt, NULL, l_bal, NULL,
            l_stg_chk, l_fus_chk, l_match);
    END GET_COMPARISON;
END DMT_CUST_COMPARE_PKG;
/
