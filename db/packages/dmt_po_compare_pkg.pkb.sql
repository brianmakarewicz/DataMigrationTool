CREATE OR REPLACE PACKAGE BODY DMT_PO_COMPARE_PKG AS
    C_CEMLI CONSTANT VARCHAR2(30) := 'PurchaseOrders';

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
        -- (a) staged total for the run's STANDARD-PO transform headers.
        --     Money rolls up from the STANDARD lines (QUANTITY * UNIT_PRICE);
        --     AMOUNT is null on STANDARD lines, so it is never summed here.
        SELECT COUNT(DISTINCT th.TFM_SEQUENCE_ID),
               NVL(SUM(tl.QUANTITY * tl.UNIT_PRICE), 0)
          INTO l_stg_cnt, l_stg_amt
          FROM DMT_PO_HEADERS_INT_TFM_TBL th
          LEFT JOIN DMT_PO_LINES_INT_TFM_TBL tl
                 ON tl.INTERFACE_HEADER_KEY = th.INTERFACE_HEADER_KEY
                AND tl.RUN_ID = th.RUN_ID
         WHERE th.RUN_ID = p_run_id
           AND NVL(th.DOCUMENT_TYPE_CODE,'STANDARD') = 'STANDARD';

        -- (b) transform errors: same STANDARD-only scope, TFM_STATUS = FAILED.
        SELECT COUNT(DISTINCT th.TFM_SEQUENCE_ID),
               NVL(SUM(tl.QUANTITY * tl.UNIT_PRICE), 0)
          INTO l_err_cnt, l_err_amt
          FROM DMT_PO_HEADERS_INT_TFM_TBL th
          LEFT JOIN DMT_PO_LINES_INT_TFM_TBL tl
                 ON tl.INTERFACE_HEADER_KEY = th.INTERFACE_HEADER_KEY
                AND tl.RUN_ID = th.RUN_ID
         WHERE th.RUN_ID = p_run_id
           AND NVL(th.DOCUMENT_TYPE_CODE,'STANDARD') = 'STANDARD'
           AND th.TFM_STATUS = 'FAILED';

        -- (c) batch id list = the import ESS request id(s) this run submitted
        --     for PurchaseOrders (there can be more than one per run).
        SELECT LISTAGG(IMPORT_ESS_JOB_ID, ',') WITHIN GROUP (ORDER BY IMPORT_ESS_JOB_ID)
          INTO l_batch
          FROM DMT_WORK_QUEUE_TBL
         WHERE RUN_ID = p_run_id AND CEMLI_CODE = C_CEMLI
           AND IMPORT_ESS_JOB_ID IS NOT NULL;

        IF l_batch IS NULL THEN
            -- Still in flight: no Fusion side yet. Never report 0 successes.
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No import request id yet (in flight)', NULL, NULL, NULL);
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

        -- (e) a fault must never read as zero successes.
        IF l_err <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20903,
                'PO comparison: BIP report error code '||l_err);
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

        -- (f) variance + balance; money variance only when money is available.
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_var_amt := CASE WHEN l_money_ok = 'Y'
                          THEN l_stg_amt - (NVL(l_fus_amt,0) + l_err_amt) END;
        l_bal := CASE WHEN l_var_cnt = 0
                        AND (l_money_ok = 'N' OR l_var_amt = 0)
                      THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
            l_fus_cnt, l_fus_amt, NVL(l_ccy,'USD'), l_money_ok,
            l_var_cnt, l_var_amt, l_bal, NULL, NULL, NULL, NULL);
    END GET_COMPARISON;

    -- ------------------------------------------------------------------
    -- BlanketPOs (BPA). Same shared header/line TFM tables as PurchaseOrders,
    -- filtered to DOCUMENT_TYPE_CODE='BLANKET'. Money is sourced DMT-side
    -- from the TFM line AMOUNT (per discovery: a blanket line is loaded
    -- quantity-based, so Fusion never persists a queryable line/header
    -- amount for it). STG_AMOUNT/TFM_ERROR_AMOUNT reflect the DMT side;
    -- FUSION_SUCCESS_AMOUNT is always NULL and FUSION_MONEY_AVAILABLE='N'
    -- so no money variance is computed -- balance decided on count alone.
    -- ------------------------------------------------------------------
    FUNCTION GET_BLANKET_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        C_CEMLI_B CONSTANT VARCHAR2(30) := 'BlanketPOs';
        l_stg_cnt   NUMBER; l_stg_amt   NUMBER;
        l_err_cnt   NUMBER; l_err_amt   NUMBER;
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
        -- (a) staged total for the run's BLANKET-PO transform headers.
        --     Money = the line-level AMOUNT (BPA lines carry value in
        --     AMOUNT directly; QUANTITY is null so quantity*unit_price
        --     would be wrong here -- opposite of the STANDARD PO case).
        SELECT COUNT(DISTINCT th.TFM_SEQUENCE_ID),
               NVL(SUM(tl.AMOUNT), 0)
          INTO l_stg_cnt, l_stg_amt
          FROM DMT_PO_HEADERS_INT_TFM_TBL th
          LEFT JOIN DMT_PO_LINES_INT_TFM_TBL tl
                 ON tl.INTERFACE_HEADER_KEY = th.INTERFACE_HEADER_KEY
                AND tl.RUN_ID = th.RUN_ID
         WHERE th.RUN_ID = p_run_id
           AND th.DOCUMENT_TYPE_CODE = 'BLANKET';

        -- (b) transform errors: same BLANKET-only scope, TFM_STATUS = FAILED.
        SELECT COUNT(DISTINCT th.TFM_SEQUENCE_ID),
               NVL(SUM(tl.AMOUNT), 0)
          INTO l_err_cnt, l_err_amt
          FROM DMT_PO_HEADERS_INT_TFM_TBL th
          LEFT JOIN DMT_PO_LINES_INT_TFM_TBL tl
                 ON tl.INTERFACE_HEADER_KEY = th.INTERFACE_HEADER_KEY
                AND tl.RUN_ID = th.RUN_ID
         WHERE th.RUN_ID = p_run_id
           AND th.DOCUMENT_TYPE_CODE = 'BLANKET'
           AND th.TFM_STATUS = 'FAILED';

        -- (c) batch id list = the import ESS request id(s) this run submitted
        --     for BlanketPOs.
        SELECT LISTAGG(IMPORT_ESS_JOB_ID, ',') WITHIN GROUP (ORDER BY IMPORT_ESS_JOB_ID)
          INTO l_batch
          FROM DMT_WORK_QUEUE_TBL
         WHERE RUN_ID = p_run_id AND CEMLI_CODE = C_CEMLI_B
           AND IMPORT_ESS_JOB_ID IS NOT NULL;

        IF l_batch IS NULL THEN
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI_B, C_CEMLI_B, 'NONE',
                l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No import request id yet (in flight)', NULL, NULL, NULL);
        END IF;
        l_key_type := 'IMPORT_ID';

        -- (d) live Fusion aggregate via the shared BIP transport. Count only
        --     (the report shape mirrors PO_CMP but the query filters
        --     TYPE_LOOKUP_CODE='BLANKET'; SUCCESS_AMOUNT is ignored here --
        --     Fusion never persists a queryable amount for a blanket line).
        SELECT CMP_REPORT_CATALOG_PATH INTO l_path
          FROM DMT_BIP_REPORT_TBL WHERE CEMLI_CODE = C_CEMLI_B;

        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id      => p_run_id,
            p_cemli_code  => C_CEMLI_B,
            p_params      => 'P_BATCH_ID|'||l_batch,
            x_report_xml  => l_xml,
            x_error_code  => l_err,
            p_report_path => l_path);

        IF l_err <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20903,
                'BlanketPOs comparison: BIP report error code '||l_err);
        END IF;

        IF l_xml IS NULL THEN
            l_fus_cnt := 0;
        ELSE
            SELECT TO_NUMBER(x.success_count)
              INTO l_fus_cnt
              FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                     success_count VARCHAR2(40) PATH 'SUCCESS_COUNT') x;
        END IF;

        -- (f) balance on count only; no money variance (FUSION_MONEY_AVAILABLE='N').
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_bal := CASE WHEN l_var_cnt = 0 THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI_B, C_CEMLI_B, l_key_type,
            l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
            l_fus_cnt, NULL, NULL, l_money_ok,
            l_var_cnt, NULL, l_bal, NULL, NULL, NULL, NULL);
    END GET_BLANKET_COMPARISON;

    -- ------------------------------------------------------------------
    -- Contracts (CPA). Same shared header TFM table, filtered to
    -- DOCUMENT_TYPE_CODE='CONTRACT'. Header-only document -- no line join,
    -- no amount column anywhere in the DMT pipeline or in Fusion for this
    -- document type (per discovery). Count-only in every respect.
    -- ------------------------------------------------------------------
    FUNCTION GET_CONTRACT_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        C_CEMLI_C CONSTANT VARCHAR2(30) := 'Contracts';
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
        l_stg_chk   VARCHAR2(80);
        l_fus_chk   VARCHAR2(80);
        l_match     VARCHAR2(1);
    BEGIN
        -- (a) staged total for the run's CONTRACT transform headers.
        --     Header-only object: no line join, no money column.
        SELECT COUNT(DISTINCT th.TFM_SEQUENCE_ID)
          INTO l_stg_cnt
          FROM DMT_PO_HEADERS_INT_TFM_TBL th
         WHERE th.RUN_ID = p_run_id
           AND th.DOCUMENT_TYPE_CODE = 'CONTRACT';

        -- (b) transform errors: same CONTRACT-only scope, TFM_STATUS = FAILED.
        SELECT COUNT(DISTINCT th.TFM_SEQUENCE_ID)
          INTO l_err_cnt
          FROM DMT_PO_HEADERS_INT_TFM_TBL th
         WHERE th.RUN_ID = p_run_id
           AND th.DOCUMENT_TYPE_CODE = 'CONTRACT'
           AND th.TFM_STATUS = 'FAILED';

        -- (c) batch id list = the import ESS request id(s) this run submitted
        --     for Contracts.
        SELECT LISTAGG(IMPORT_ESS_JOB_ID, ',') WITHIN GROUP (ORDER BY IMPORT_ESS_JOB_ID)
          INTO l_batch
          FROM DMT_WORK_QUEUE_TBL
         WHERE RUN_ID = p_run_id AND CEMLI_CODE = C_CEMLI_C
           AND IMPORT_ESS_JOB_ID IS NOT NULL;

        -- Backlog #94 STG-side business-key checksum. Business key per
        -- DMT_DESIGN.html = "PREFIX + DOCUMENT_NUM"; the TFM DOCUMENT_NUM
        -- already carries the run prefix. On the Fusion side the same value is
        -- PO_HEADERS_ALL.SEGMENT1 for a CONTRACT-type header (verified live on
        -- the demo instance: SEGMENT1 = 93270RT-CPA-001 for the loaded CPA,
        -- matching TFM DOCUMENT_NUM byte-for-byte). We checksum the LOADABLE
        -- CONTRACT set (TFM_STATUS != 'FAILED'). EXACT MIRROR of the Fusion-side
        -- expression in the Contracts PO_CMP_DM.xdm: distinct UPPER(TRIM(num)),
        -- SUM(ORA_HASH) ||':'|| COUNT.
        SELECT TO_CHAR(NVL(SUM(ORA_HASH(k)),0)) || ':' || COUNT(*)
          INTO l_stg_chk
          FROM (
            SELECT DISTINCT UPPER(TRIM(th.DOCUMENT_NUM)) AS k
              FROM DMT_PO_HEADERS_INT_TFM_TBL th
             WHERE th.RUN_ID = p_run_id
               AND th.DOCUMENT_TYPE_CODE = 'CONTRACT'
               AND NVL(th.TFM_STATUS,'x') != 'FAILED'
          );

        IF l_batch IS NULL THEN
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI_C, C_CEMLI_C, 'NONE',
                l_stg_cnt, NULL, l_err_cnt, NULL,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No import request id yet (in flight)',
                l_stg_chk, NULL,
                CASE WHEN l_stg_chk IS NOT NULL THEN '?' END);
        END IF;
        l_key_type := 'IMPORT_ID';

        -- (d) live Fusion aggregate via the shared BIP transport. Count only
        --     (the report shape filters TYPE_LOOKUP_CODE='CONTRACT'; a CPA
        --     has no queryable Fusion amount at all).
        SELECT CMP_REPORT_CATALOG_PATH INTO l_path
          FROM DMT_BIP_REPORT_TBL WHERE CEMLI_CODE = C_CEMLI_C;

        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id      => p_run_id,
            p_cemli_code  => C_CEMLI_C,
            p_params      => 'P_BATCH_ID|'||l_batch,
            x_report_xml  => l_xml,
            x_error_code  => l_err,
            p_report_path => l_path);

        IF l_err <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20903,
                'Contracts comparison: BIP report error code '||l_err);
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

        -- (f) balance on count only; no money grain exists for CPA.
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_bal := CASE WHEN l_var_cnt = 0 THEN 'Y' ELSE 'N' END;

        -- KEY_MATCH: non-money equality signal. Y/N when both sides present,
        -- ? when the Fusion side could not be computed.
        IF l_stg_chk IS NULL THEN
            l_match := NULL;
        ELSIF l_fus_chk IS NULL THEN
            l_match := '?';
        ELSIF l_stg_chk = l_fus_chk THEN
            l_match := 'Y';
        ELSE
            l_match := 'N';
        END IF;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI_C, C_CEMLI_C, l_key_type,
            l_stg_cnt, NULL, l_err_cnt, NULL,
            l_fus_cnt, NULL, NULL, l_money_ok,
            l_var_cnt, NULL, l_bal, NULL,
            l_stg_chk, l_fus_chk, l_match);
    END GET_CONTRACT_COMPARISON;
END DMT_PO_COMPARE_PKG;
/
