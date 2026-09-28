CREATE OR REPLACE PACKAGE BODY DMT_SUP_COMPARE_PKG AS

    -- Shared shape for all five count-only supplier objects. Each public
    -- function passes its own CEMLI code and a dynamic TFM-table count
    -- (via a REF CURSOR built from static per-object SQL -- see each public
    -- function) so this stays one place for the batch-id lookup, BIP call,
    -- and variance/balance math (mirrors DMT_PO_COMPARE_PKG.GET_COMPARISON).
    FUNCTION BUILD_ROW(
        p_run_id    IN NUMBER,
        p_cemli     IN VARCHAR2,
        p_stg_cnt   IN NUMBER,
        p_err_cnt   IN NUMBER
    ) RETURN DMT_CMP_ROW_OBJ IS
        l_batch     VARCHAR2(4000);
        l_xml       XMLTYPE;
        l_err       NUMBER;
        l_key_type  VARCHAR2(20);
        l_fus_cnt   NUMBER;
        l_path      DMT_BIP_REPORT_TBL.CMP_REPORT_CATALOG_PATH%TYPE;
        l_bal       VARCHAR2(1);
        l_var_cnt   NUMBER;
    BEGIN
        -- batch id list = the LOAD ESS job id(s) this run submitted for this
        -- supplier object (key path = LOAD_ID, never the prefix).
        SELECT LISTAGG(LOAD_ESS_JOB_ID, ',') WITHIN GROUP (ORDER BY LOAD_ESS_JOB_ID)
          INTO l_batch
          FROM DMT_WORK_QUEUE_TBL
         WHERE RUN_ID = p_run_id AND CEMLI_CODE = p_cemli
           AND LOAD_ESS_JOB_ID IS NOT NULL;

        IF l_batch IS NULL THEN
            -- Still in flight: no Fusion side yet. Never report 0 successes.
            RETURN DMT_CMP_ROW_OBJ(p_cemli, p_cemli, 'NONE',
                p_stg_cnt, NULL, p_err_cnt, NULL,
                NULL, NULL, NULL, 'N', NULL, NULL, '?',
                'No load request id yet (in flight)');
        END IF;
        l_key_type := 'LOAD_ID';

        SELECT CMP_REPORT_CATALOG_PATH INTO l_path
          FROM DMT_BIP_REPORT_TBL WHERE CEMLI_CODE = p_cemli;

        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id      => p_run_id,
            p_cemli_code  => p_cemli,
            p_params      => 'P_BATCH_ID|'||l_batch,
            x_report_xml  => l_xml,
            x_error_code  => l_err,
            p_report_path => l_path);

        -- a fault must never read as zero successes.
        IF l_err <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20903,
                p_cemli||' comparison: BIP report error code '||l_err);
        END IF;

        IF l_xml IS NULL THEN
            l_fus_cnt := 0;
        ELSE
            SELECT TO_NUMBER(x.success_count)
              INTO l_fus_cnt
              FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                     success_count VARCHAR2(40) PATH 'SUCCESS_COUNT') x;
        END IF;

        -- count-only: no money anywhere in this family. Balance decided on
        -- count alone, mirroring the PO function's l_money_ok='N' branch.
        l_var_cnt := p_stg_cnt - (NVL(l_fus_cnt,0) + p_err_cnt);
        l_bal := CASE WHEN l_var_cnt = 0 THEN 'Y' ELSE 'N' END;

        RETURN DMT_CMP_ROW_OBJ(p_cemli, p_cemli, l_key_type,
            p_stg_cnt, NULL, p_err_cnt, NULL,
            l_fus_cnt, NULL, NULL, 'N',
            l_var_cnt, NULL, l_bal, NULL);
    END BUILD_ROW;

    FUNCTION GET_SUPPLIERS_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        l_stg_cnt NUMBER; l_err_cnt NUMBER;
    BEGIN
        SELECT COUNT(DISTINCT TFM_SEQUENCE_ID)
          INTO l_stg_cnt
          FROM DMT_POZ_SUPPLIERS_TFM_TBL
         WHERE RUN_ID = p_run_id;

        SELECT COUNT(DISTINCT TFM_SEQUENCE_ID)
          INTO l_err_cnt
          FROM DMT_POZ_SUPPLIERS_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';

        RETURN BUILD_ROW(p_run_id, 'Suppliers', l_stg_cnt, l_err_cnt);
    END GET_SUPPLIERS_CMP;

    FUNCTION GET_SUP_ADDR_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        l_stg_cnt NUMBER; l_err_cnt NUMBER;
    BEGIN
        SELECT COUNT(DISTINCT TFM_SEQUENCE_ID)
          INTO l_stg_cnt
          FROM DMT_POZ_SUP_ADDR_TFM_TBL
         WHERE RUN_ID = p_run_id;

        SELECT COUNT(DISTINCT TFM_SEQUENCE_ID)
          INTO l_err_cnt
          FROM DMT_POZ_SUP_ADDR_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';

        RETURN BUILD_ROW(p_run_id, 'SupplierAddresses', l_stg_cnt, l_err_cnt);
    END GET_SUP_ADDR_CMP;

    FUNCTION GET_SUP_SITES_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        l_stg_cnt NUMBER; l_err_cnt NUMBER;
    BEGIN
        SELECT COUNT(DISTINCT TFM_SEQUENCE_ID)
          INTO l_stg_cnt
          FROM DMT_POZ_SUP_SITE_TFM_TBL
         WHERE RUN_ID = p_run_id;

        SELECT COUNT(DISTINCT TFM_SEQUENCE_ID)
          INTO l_err_cnt
          FROM DMT_POZ_SUP_SITE_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';

        RETURN BUILD_ROW(p_run_id, 'SupplierSites', l_stg_cnt, l_err_cnt);
    END GET_SUP_SITES_CMP;

    FUNCTION GET_SUP_SITE_ASSN_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        l_stg_cnt NUMBER; l_err_cnt NUMBER;
    BEGIN
        SELECT COUNT(DISTINCT TFM_SEQUENCE_ID)
          INTO l_stg_cnt
          FROM DMT_POZ_SUP_SITE_ASSN_TFM_TBL
         WHERE RUN_ID = p_run_id;

        SELECT COUNT(DISTINCT TFM_SEQUENCE_ID)
          INTO l_err_cnt
          FROM DMT_POZ_SUP_SITE_ASSN_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';

        RETURN BUILD_ROW(p_run_id, 'SupplierSiteAssignments', l_stg_cnt, l_err_cnt);
    END GET_SUP_SITE_ASSN_CMP;

    FUNCTION GET_SUP_CONTACTS_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        l_stg_cnt NUMBER; l_err_cnt NUMBER;
    BEGIN
        SELECT COUNT(DISTINCT TFM_SEQUENCE_ID)
          INTO l_stg_cnt
          FROM DMT_POZ_SUP_CONTACTS_TFM_TBL
         WHERE RUN_ID = p_run_id;

        SELECT COUNT(DISTINCT TFM_SEQUENCE_ID)
          INTO l_err_cnt
          FROM DMT_POZ_SUP_CONTACTS_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';

        RETURN BUILD_ROW(p_run_id, 'SupplierContacts', l_stg_cnt, l_err_cnt);
    END GET_SUP_CONTACTS_CMP;

END DMT_SUP_COMPARE_PKG;
/
