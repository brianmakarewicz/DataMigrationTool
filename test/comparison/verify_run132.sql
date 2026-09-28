-- Task 6 gate test: end-to-end verification of the run-level comparison
-- framework against the discovery-proven PurchaseOrders numbers for run 132
-- (local Docker). This makes a LIVE runReport SOAP call into Fusion (via
-- DMT_PO_COMPARE_PKG.GET_COMPARISON, dispatched from DMT_RUN_COMPARE_PKG),
-- proving the PO row reaches Fusion base tables and reconciles. Nothing
-- counts until it reaches base tables -- this is that proof, end to end.
--
-- Discovery-proven values (docs/superpowers/specs/discovery/PurchaseOrders.md):
--   STG total          = 3 headers / 2300 money (STANDARD only)
--   TFM errors         = 1 / 50
--   Fusion successes   = 2 / 2250 (LIVE, request_id 10024267)
--   VARIANCE           = 0 / balanced
--   KEY_TYPE           = IMPORT_ID
SET SERVEROUTPUT ON
DECLARE
    c       SYS_REFCURSOR;
    v       DMT_CMP_ROW_OBJ;
    n       NUMBER := 0;
    po_seen BOOLEAN := FALSE;

    PROCEDURE assert_num(p_label IN VARCHAR2, p_actual IN NUMBER, p_expected IN NUMBER) IS
    BEGIN
        IF p_actual IS NULL OR p_actual != p_expected THEN
            RAISE_APPLICATION_ERROR(-20910,
                'PO comparison mismatch: '||p_label||' expected '||p_expected||
                ' got '||NVL(TO_CHAR(p_actual),'NULL'));
        END IF;
    END assert_num;

    PROCEDURE assert_str(p_label IN VARCHAR2, p_actual IN VARCHAR2, p_expected IN VARCHAR2) IS
    BEGIN
        IF p_actual IS NULL OR p_actual != p_expected THEN
            RAISE_APPLICATION_ERROR(-20911,
                'PO comparison mismatch: '||p_label||' expected '||p_expected||
                ' got '||NVL(p_actual,'NULL'));
        END IF;
    END assert_str;
BEGIN
    DMT_RUN_COMPARE_PKG.GET_RUN_COMPARISON(132, c);
    LOOP
        FETCH c INTO v;  -- object-type cursor: one DMT_CMP_ROW_OBJ per row
        EXIT WHEN c%NOTFOUND;
        n := n + 1;
        IF v.CEMLI_CODE = 'PurchaseOrders' THEN
            po_seen := TRUE;

            DBMS_OUTPUT.PUT_LINE('OBJECT_TYPE='||v.OBJECT_TYPE);
            DBMS_OUTPUT.PUT_LINE('CEMLI_CODE='||v.CEMLI_CODE);
            DBMS_OUTPUT.PUT_LINE('KEY_TYPE='||v.KEY_TYPE);
            DBMS_OUTPUT.PUT_LINE('STG_COUNT='||v.STG_COUNT||' STG_AMOUNT='||v.STG_AMOUNT);
            DBMS_OUTPUT.PUT_LINE('TFM_ERROR_COUNT='||v.TFM_ERROR_COUNT||' TFM_ERROR_AMOUNT='||v.TFM_ERROR_AMOUNT);
            DBMS_OUTPUT.PUT_LINE('FUSION_SUCCESS_COUNT='||v.FUSION_SUCCESS_COUNT||' FUSION_SUCCESS_AMOUNT='||v.FUSION_SUCCESS_AMOUNT);
            DBMS_OUTPUT.PUT_LINE('AMOUNT_CURRENCY='||v.AMOUNT_CURRENCY);
            DBMS_OUTPUT.PUT_LINE('FUSION_MONEY_AVAILABLE='||v.FUSION_MONEY_AVAILABLE);
            DBMS_OUTPUT.PUT_LINE('VARIANCE_COUNT='||v.VARIANCE_COUNT||' VARIANCE_AMOUNT='||v.VARIANCE_AMOUNT);
            DBMS_OUTPUT.PUT_LINE('IN_BALANCE='||v.IN_BALANCE);
            DBMS_OUTPUT.PUT_LINE('NOTE='||v.NOTE);

            assert_str('CEMLI_CODE',           v.CEMLI_CODE,           'PurchaseOrders');
            assert_str('KEY_TYPE',             v.KEY_TYPE,             'IMPORT_ID');
            assert_num('STG_COUNT',            v.STG_COUNT,            3);
            assert_num('STG_AMOUNT',           v.STG_AMOUNT,           2300);
            assert_num('TFM_ERROR_COUNT',      v.TFM_ERROR_COUNT,      1);
            assert_num('TFM_ERROR_AMOUNT',     v.TFM_ERROR_AMOUNT,     50);
            assert_num('FUSION_SUCCESS_COUNT', v.FUSION_SUCCESS_COUNT, 2);
            assert_num('FUSION_SUCCESS_AMOUNT',v.FUSION_SUCCESS_AMOUNT,2250);
            assert_num('VARIANCE_COUNT',       v.VARIANCE_COUNT,       0);
            assert_str('IN_BALANCE',           v.IN_BALANCE,           'Y');
        END IF;
    END LOOP;
    CLOSE c;

    IF NOT po_seen THEN
        RAISE_APPLICATION_ERROR(-20912, 'PurchaseOrders row missing from run 132 comparison grid');
    END IF;

    DBMS_OUTPUT.PUT_LINE('PASS rows='||n);
END;
/
