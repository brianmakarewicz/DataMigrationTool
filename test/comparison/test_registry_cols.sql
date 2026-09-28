SET SERVEROUTPUT ON
DECLARE
    l_fn        DMT_BIP_REPORT_TBL.CMP_FUNCTION%TYPE;
    l_cmp_path  DMT_BIP_REPORT_TBL.CMP_REPORT_CATALOG_PATH%TYPE;
    l_cmp_dm    DMT_BIP_REPORT_TBL.CMP_DM_CATALOG_PATH%TYPE;
    l_dm_path   DMT_BIP_REPORT_TBL.DM_CATALOG_PATH%TYPE;
    l_rpt_path  DMT_BIP_REPORT_TBL.REPORT_CATALOG_PATH%TYPE;
BEGIN
    SELECT CMP_FUNCTION, CMP_REPORT_CATALOG_PATH, CMP_DM_CATALOG_PATH,
           DM_CATALOG_PATH, REPORT_CATALOG_PATH
      INTO l_fn, l_cmp_path, l_cmp_dm, l_dm_path, l_rpt_path
      FROM DMT_BIP_REPORT_TBL
     WHERE CEMLI_CODE = 'PurchaseOrders';

    -- Comparison-report columns are seeded.
    IF l_fn != 'DMT_PO_COMPARE_PKG.GET_COMPARISON'
       OR l_cmp_path != '/Custom/DMT2/PurchaseOrders/PO_CMP_RPT.xdo'
       OR l_cmp_dm != '/Custom/DMT2/PurchaseOrders/PO_CMP_DM.xdm' THEN
        RAISE_APPLICATION_ERROR(-20901,
            'comparison columns not seeded: '||l_fn||' / '||l_cmp_path||' / '||l_cmp_dm);
    END IF;

    -- Regression guard: the comparison seed must NOT clobber the Contract-v1
    -- reconciliation report paths that DMT_RECON_CONTRACT_PKG.FETCH_ROWS reads.
    IF l_dm_path != '/Custom/DMT2/PurchaseOrders/DMT_PO_RECON_DM.xdm'
       OR l_rpt_path != '/Custom/DMT2/PurchaseOrders/DMT_PO_RECON_RPT.xdo' THEN
        RAISE_APPLICATION_ERROR(-20902,
            'recon paths clobbered by comparison seed: '||l_dm_path||' / '||l_rpt_path);
    END IF;

    DBMS_OUTPUT.PUT_LINE('PASS');
END;
/
