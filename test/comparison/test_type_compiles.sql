SET SERVEROUTPUT ON
DECLARE
    r DMT_CMP_ROW_OBJ;
    t DMT_CMP_ROW_TAB;
BEGIN
    r := DMT_CMP_ROW_OBJ('PurchaseOrders','PurchaseOrders','LOAD_ID',
                         3, 2300, 1, 50, 2, 2250, 'USD', 'Y', NULL, NULL, NULL, NULL);
    t := DMT_CMP_ROW_TAB(r);
    IF t.COUNT = 1 AND t(1).STG_COUNT = 3 THEN
        DBMS_OUTPUT.PUT_LINE('PASS');
    ELSE
        RAISE_APPLICATION_ERROR(-20900, 'type shape wrong');
    END IF;
END;
/
