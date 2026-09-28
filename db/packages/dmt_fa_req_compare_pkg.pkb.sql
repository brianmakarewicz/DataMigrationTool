CREATE OR REPLACE PACKAGE BODY DMT_FA_REQ_COMPARE_PKG AS

    -- ------------------------------------------------------------------
    -- Assets (Fixed Assets). MONEY object -- amount = asset COST, which lives
    -- on the BOOK table (DMT_FA_ASSET_BOOK_TFM_TBL.COST DMT-side; FA_BOOKS.COST
    -- Fusion-side), NOT the header (the header table has no cost column). For
    -- run 132 each asset has exactly one book row (US CORP), so book grain and
    -- asset grain coincide and the cost totals are clean.
    --
    -- STG scope (gotcha): the prefix is applied at TRANSFORM, not at stage, and
    -- STG carries no RUN_ID (its SCENARIO_ID is the write-once seed id, not the
    -- run). So STG is scoped to the run through the BOOK TFM rows'
    -- STG_SEQUENCE_ID pointers -- never by run id or by a prefix LIKE on the
    -- STG table (which returns 0 rows).
    --
    -- Key path (KEY_TYPE = 'LOAD_ID', PRIMARY batch-id path per discovery): the
    -- DMT load ESS request id (DMT_WORK_QUEUE_TBL.LOAD_ESS_JOB_ID) round-trips
    -- onto FA_MASS_ADDITIONS.LOAD_REQUEST_ID; the successes are the POSTED rows
    -- under that load id, joined FA_MASS_ADDITIONS.ASSET_ID -> FA_ADDITIONS_B ->
    -- FA_BOOKS for cost. This is prefix-free and production-valid. A captured
    -- FUSION_ASSET_ID list is the documented fallback only if the interface is
    -- ever purged; the batch-id path is primary and used here.
    -- ------------------------------------------------------------------
    FUNCTION GET_ASSETS_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        C_CEMLI CONSTANT VARCHAR2(30) := 'Assets';
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
        -- (a) staged total (count + cost) for this run's assets. Money is on
        --     the BOOK table; scope STG to the run via the BOOK TFM rows'
        --     STG_SEQUENCE_ID pointers (STG has no RUN_ID).
        SELECT COUNT(*), NVL(SUM(s.COST), 0)
          INTO l_stg_cnt, l_stg_amt
          FROM DMT_FA_ASSET_BOOK_STG_TBL s
         WHERE s.STG_SEQUENCE_ID IN (
                 SELECT STG_SEQUENCE_ID
                   FROM DMT_FA_ASSET_BOOK_TFM_TBL
                  WHERE RUN_ID = p_run_id);

        -- (b) transform errors (count + cost): book TFM rows FAILED for the run.
        SELECT COUNT(*), NVL(SUM(COST), 0)
          INTO l_err_cnt, l_err_amt
          FROM DMT_FA_ASSET_BOOK_TFM_TBL
         WHERE RUN_ID = p_run_id
           AND TFM_STATUS = 'FAILED';

        -- (c) batch key = the load ESS request id(s) this run submitted for
        --     Assets (there can be more than one child partition per run).
        --     These land on FA_MASS_ADDITIONS.LOAD_REQUEST_ID (KEY_TYPE=LOAD_ID).
        SELECT LISTAGG(LOAD_ESS_JOB_ID, ',') WITHIN GROUP (ORDER BY LOAD_ESS_JOB_ID)
          INTO l_batch
          FROM DMT_WORK_QUEUE_TBL
         WHERE RUN_ID = p_run_id AND CEMLI_CODE = C_CEMLI
           AND LOAD_ESS_JOB_ID IS NOT NULL;

        IF l_batch IS NULL THEN
            -- Not yet loaded: no Fusion side. Never report 0 successes.
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No load request id yet (in flight)');
        END IF;
        l_key_type := 'LOAD_ID';

        -- (d) live Fusion aggregate via the shared BIP transport (count + cost,
        --     POSTED rows only, summed from FA_BOOKS.COST).
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
                'Assets comparison: BIP report error code '||l_err);
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

        -- (f) variance + balance on count AND money.
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_var_amt := l_stg_amt - (NVL(l_fus_amt,0) + l_err_amt);
        l_bal := CASE WHEN l_var_cnt = 0 AND l_var_amt = 0 THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
            l_fus_cnt, l_fus_amt, NVL(l_ccy,'USD'), l_money_ok,
            l_var_cnt, l_var_amt, l_bal, NULL);
    END GET_ASSETS_CMP;

    -- ------------------------------------------------------------------
    -- Requisitions. MONEY object accounted at the HEADER grain (one accounted
    -- record per requisition header; DMT_RUN_RECORDS_V reports Requisitions
    -- from the header TFM table only). The header carries NO amount column, so
    -- money is rolled up from the lines as QUANTITY * CURRENCY_UNIT_PRICE
    -- (CURRENCY_AMOUNT is NULL in this run and on the Fusion base line, exactly
    -- like the STANDARD-PO case).
    --
    -- STG scope (CRITICAL gotcha -- the 10/2380 double-count): STG carries no
    -- RUN_ID and this object's seed data was STAGED TWICE (a second NEW copy
    -- sits alongside the run-132 copy). Scoping STG by a raw business/interface
    -- key double-counts the lines. The only safe run scope is the exact STG
    -- rows the run transformed -- reached through the LINE TFM rows'
    -- STG_SEQUENCE_ID pointers. That yields 5 lines / 1190; a raw-key join does
    -- not. Both the count and the money are scoped this way.
    --
    -- Key path (KEY_TYPE = 'CAPTURED_ID'): this run has TWO import ESS ids
    -- (two batches), so a single IMPORT_ID does not select the run. The clean,
    -- prefix-free run key is the captured FUSION_REQUISITION_HEADER_ID list on
    -- this run's LOADED header TFM rows; Fusion is read live by that id list.
    -- ------------------------------------------------------------------
    FUNCTION GET_REQUISITIONS_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        C_CEMLI CONSTANT VARCHAR2(30) := 'Requisitions';
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
        -- (a) staged total. Record count = the run's header record set, scoped
        --     through the header TFM rows' STG_SEQUENCE_ID pointers. Money =
        --     SUM over the exact STG LINES this run transformed, scoped through
        --     the LINE TFM rows' STG_SEQUENCE_ID pointers. Scoping via
        --     STG_SEQUENCE_ID (not a raw interface-key join) is what avoids the
        --     double-staging double-count (10 lines / 2380).
        SELECT COUNT(*)
          INTO l_stg_cnt
          FROM DMT_POR_REQ_HEADERS_STG_TBL s
         WHERE s.STG_SEQUENCE_ID IN (
                 SELECT STG_SEQUENCE_ID
                   FROM DMT_POR_REQ_HEADERS_TFM_TBL
                  WHERE RUN_ID = p_run_id);

        SELECT NVL(SUM(NVL(ls.CURRENCY_AMOUNT, ls.QUANTITY * ls.CURRENCY_UNIT_PRICE)), 0)
          INTO l_stg_amt
          FROM DMT_POR_REQ_LINES_STG_TBL ls
         WHERE ls.STG_SEQUENCE_ID IN (
                 SELECT STG_SEQUENCE_ID
                   FROM DMT_POR_REQ_LINES_TFM_TBL
                  WHERE RUN_ID = p_run_id);

        -- (b) transform errors: FAILED headers (count), money rolled up from
        --     their lines (QUANTITY * CURRENCY_UNIT_PRICE). Header grain.
        SELECT COUNT(DISTINCT h.TFM_SEQUENCE_ID),
               NVL(SUM(NVL(l.CURRENCY_AMOUNT, l.QUANTITY * l.CURRENCY_UNIT_PRICE)), 0)
          INTO l_err_cnt, l_err_amt
          FROM DMT_POR_REQ_HEADERS_TFM_TBL h
          LEFT JOIN DMT_POR_REQ_LINES_TFM_TBL l
                 ON l.RUN_ID = h.RUN_ID
                AND l.INTERFACE_HEADER_KEY = h.INTERFACE_HEADER_KEY
         WHERE h.RUN_ID = p_run_id
           AND h.TFM_STATUS = 'FAILED';

        -- (c) batch key = the captured FUSION_REQUISITION_HEADER_ID list on
        --     this run's LOADED header TFM rows (KEY_TYPE = CAPTURED_ID). This
        --     run has two import ESS ids, so a single import id will not select
        --     the run; the captured header id list is the clean run key.
        SELECT LISTAGG(FUSION_REQUISITION_HEADER_ID, ',')
                 WITHIN GROUP (ORDER BY FUSION_REQUISITION_HEADER_ID)
          INTO l_batch
          FROM DMT_POR_REQ_HEADERS_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'LOADED'
           AND FUSION_REQUISITION_HEADER_ID IS NOT NULL;

        IF l_batch IS NULL THEN
            -- Still in flight (no LOADED header captured yet): never report 0
            -- successes as if confirmed.
            RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, 'NONE',
                l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
                NULL, NULL, NULL, l_money_ok, NULL, NULL, '?',
                'No captured FUSION_REQUISITION_HEADER_ID yet (in flight)');
        END IF;
        l_key_type := 'CAPTURED_ID';

        -- (d) live Fusion aggregate via the shared BIP transport. Count of
        --     headers + money = SUM(line quantity * unit_price) over the
        --     captured header id list.
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
                'Requisitions comparison: BIP report error code '||l_err);
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

        -- (f) variance + balance on count AND money.
        l_var_cnt := l_stg_cnt - (NVL(l_fus_cnt,0) + l_err_cnt);
        l_var_amt := l_stg_amt - (NVL(l_fus_amt,0) + l_err_amt);
        l_bal := CASE WHEN l_var_cnt = 0 AND l_var_amt = 0 THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(C_CEMLI, C_CEMLI, l_key_type,
            l_stg_cnt, l_stg_amt, l_err_cnt, l_err_amt,
            l_fus_cnt, l_fus_amt, NVL(l_ccy,'USD'), l_money_ok,
            l_var_cnt, l_var_amt, l_bal, NULL);
    END GET_REQUISITIONS_CMP;

END DMT_FA_REQ_COMPARE_PKG;
/
