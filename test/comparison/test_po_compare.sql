-- Task 4 gate test: PurchaseOrders post-run comparison, run 132 (local Docker).
-- Proven values from docs/superpowers/specs/discovery/PurchaseOrders.md:
--   STG total = 3 headers / 2300 money (STANDARD only)
--   TFM errors = 1 / 50
--   Fusion successes (LIVE, request_id 10024267) = 2 / 2250
--   BALANCED (variance count 0, in_balance = Y)
SET SERVEROUTPUT ON
DECLARE
    r DMT_CMP_ROW_OBJ;
BEGIN
    r := DMT_PO_COMPARE_PKG.GET_COMPARISON(132);
    DBMS_OUTPUT.PUT_LINE('stg='||r.STG_COUNT||'/'||r.STG_AMOUNT
        ||' tfmerr='||r.TFM_ERROR_COUNT||'/'||r.TFM_ERROR_AMOUNT
        ||' fus='||r.FUSION_SUCCESS_COUNT||'/'||r.FUSION_SUCCESS_AMOUNT
        ||' key='||r.KEY_TYPE||' bal='||r.IN_BALANCE);
    IF r.STG_COUNT = 3 AND r.TFM_ERROR_COUNT = 1
       AND r.FUSION_SUCCESS_COUNT = 2 AND r.FUSION_SUCCESS_AMOUNT = 2250
       AND r.VARIANCE_COUNT = 0 AND r.IN_BALANCE = 'Y'
       AND r.KEY_TYPE = 'IMPORT_ID' THEN
        DBMS_OUTPUT.PUT_LINE('PASS');
    ELSE
        RAISE_APPLICATION_ERROR(-20902, 'PO comparison did not balance');
    END IF;
END;
/
