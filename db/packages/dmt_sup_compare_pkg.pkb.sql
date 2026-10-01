CREATE OR REPLACE PACKAGE BODY DMT_SUP_COMPARE_PKG AS

    -- Shared shape for all five count-only supplier objects. Each of the five
    -- public functions runs two plain static SELECT ... INTO counts against
    -- its own hardcoded TFM table (STG total and TFM-error total) and passes
    -- those plain NUMBERs, plus its CEMLI code, to this one private helper.
    -- BUILD_ROW is the single place for the batch-id lookup, the BIP call,
    -- and the variance/balance math (mirrors DMT_PO_COMPARE_PKG.GET_COMPARISON).
    -- No dynamic SQL and no REF CURSOR anywhere in this package (rule #66).
    -- Backlog #94 -- business-key checksum. A deterministic, order-independent
    -- set-checksum over an object's normalized business key(s), computed with
    -- the IDENTICAL expression on the STG/TFM side (here) and the Fusion side
    -- (the SUP_CMP_DM BIP data model), so an equal key set yields an equal
    -- checksum. Shape:  SUM(ORA_HASH(UPPER(TRIM(key)))) over the DISTINCT key
    -- set  ||':'||  COUNT(DISTINCT key). SUM over the distinct set is
    -- order-independent and avoids the 4000-byte LISTAGG overflow at scale.
    -- The COUNT suffix distinguishes key sets of DIFFERENT cardinality; it does
    -- not catch a value-preserving swap within the same cardinality (additive
    -- SUM is commutative), so this is a strong-but-not-cryptographic equality
    -- signal, which is the intended scope for a non-money cross-check. Returned as the
    -- VARCHAR2 the DMT_CMP_ROW_OBJ checksum attributes carry.
    --
    -- Only Suppliers passes a non-null p_stg_checksum today (the #94 prototype);
    -- the other four supplier objects pass NULL and the three checksum
    -- attributes stay NULL ("not computed") -- a documented follow-on.
    FUNCTION BUILD_ROW(
        p_run_id        IN NUMBER,
        p_cemli         IN VARCHAR2,
        p_stg_cnt       IN NUMBER,
        p_err_cnt       IN NUMBER,
        p_stg_checksum  IN VARCHAR2 DEFAULT NULL
    ) RETURN DMT_CMP_ROW_OBJ IS
        l_batch     VARCHAR2(4000);
        l_xml       XMLTYPE;
        l_err       NUMBER;
        l_key_type  VARCHAR2(20);
        l_fus_cnt   NUMBER;
        l_path      DMT_BIP_REPORT_TBL.CMP_REPORT_CATALOG_PATH%TYPE;
        l_bal       VARCHAR2(1);
        l_var_cnt   NUMBER;
        l_fus_chk   VARCHAR2(80);
        l_match     VARCHAR2(1);
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
            -- STG-side checksum is already known; Fusion side / match unknown.
            RETURN DMT_CMP_ROW_OBJ(p_cemli, p_cemli, 'NONE',
                p_stg_cnt, NULL, p_err_cnt, NULL,
                NULL, NULL, NULL, 'N', NULL, NULL, '?',
                'No load request id yet (in flight)',
                p_stg_checksum, NULL,
                CASE WHEN p_stg_checksum IS NOT NULL THEN '?' END);
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
            l_fus_chk := NULL;
        ELSE
            SELECT TO_NUMBER(x.success_count), x.key_checksum
              INTO l_fus_cnt, l_fus_chk
              FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml COLUMNS
                     success_count VARCHAR2(40) PATH 'SUCCESS_COUNT',
                     key_checksum  VARCHAR2(80) PATH 'KEY_CHECKSUM') x;
        END IF;

        -- count-only: no money anywhere in this family. Balance decided on
        -- count alone, mirroring the PO function's l_money_ok='N' branch.
        l_var_cnt := p_stg_cnt - (NVL(l_fus_cnt,0) + p_err_cnt);
        l_bal := CASE WHEN l_var_cnt = 0 THEN 'Y' ELSE 'N' END;

        -- KEY_MATCH: a non-money equality signal. Only meaningful when THIS
        -- object computes a STG-side checksum (the #94 prototype). Y when both
        -- sides are present and equal, N when both present and differ, ? when
        -- either side could not be computed. NULL when the object is not wired
        -- for checksums (p_stg_checksum NULL) -- it stays off the signal.
        IF p_stg_checksum IS NULL THEN
            l_match := NULL;
        ELSIF l_fus_chk IS NULL THEN
            l_match := '?';
        ELSIF p_stg_checksum = l_fus_chk THEN
            l_match := 'Y';
        ELSE
            l_match := 'N';
        END IF;

        RETURN DMT_CMP_ROW_OBJ(p_cemli, p_cemli, l_key_type,
            p_stg_cnt, NULL, p_err_cnt, NULL,
            l_fus_cnt, NULL, NULL, 'N',
            l_var_cnt, NULL, l_bal, NULL,
            p_stg_checksum, l_fus_chk, l_match);
    END BUILD_ROW;

    FUNCTION GET_SUPPLIERS_CMP(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ IS
        l_stg_cnt NUMBER; l_err_cnt NUMBER; l_stg_chk VARCHAR2(80);
    BEGIN
        SELECT COUNT(DISTINCT TFM_SEQUENCE_ID)
          INTO l_stg_cnt
          FROM DMT_POZ_SUPPLIERS_TFM_TBL
         WHERE RUN_ID = p_run_id;

        SELECT COUNT(DISTINCT TFM_SEQUENCE_ID)
          INTO l_err_cnt
          FROM DMT_POZ_SUPPLIERS_TFM_TBL
         WHERE RUN_ID = p_run_id AND TFM_STATUS = 'FAILED';

        -- Backlog #94 STG-side business-key checksum. Business key per
        -- DMT_DESIGN.html object table row 1 = "PREFIX + VENDOR_NAME"; the TFM
        -- VENDOR_NAME already carries the run prefix and lands verbatim in
        -- poz_suppliers.vendor_name on the Fusion side, so it is the clean
        -- cross-side key (SEGMENT1 is regenerated by Fusion auto-numbering and
        -- is NOT a reliable cross-side key). Checksum only over the rows this
        -- run actually sent to Fusion (TFM_STATUS != 'FAILED' are the loadable
        -- set; a FAILED row never reaches the base table). EXACT MIRROR of the
        -- Fusion-side expression in SUP_CMP_DM.xdm: distinct UPPER(TRIM(...))
        -- set, SUM(ORA_HASH) ||':'|| COUNT.
        SELECT TO_CHAR(NVL(SUM(ORA_HASH(k)),0)) || ':' || COUNT(*)
          INTO l_stg_chk
          FROM (
            SELECT DISTINCT UPPER(TRIM(VENDOR_NAME)) AS k
              FROM DMT_POZ_SUPPLIERS_TFM_TBL
             WHERE RUN_ID = p_run_id
               AND NVL(TFM_STATUS,'x') != 'FAILED'
          );

        RETURN BUILD_ROW(p_run_id, 'Suppliers', l_stg_cnt, l_err_cnt, l_stg_chk);
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
