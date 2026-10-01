SET SERVEROUTPUT ON
DECLARE
    r DMT_CMP_ROW_OBJ;
    t DMT_CMP_ROW_TAB;
BEGIN
    -- 18 positional args: the 15 original attributes plus the three appended
    -- by backlog #94 (STG_KEY_CHECKSUM, FUSION_KEY_CHECKSUM, KEY_MATCH).
    r := DMT_CMP_ROW_OBJ('PurchaseOrders','PurchaseOrders','LOAD_ID',
                         3, 2300, 1, 50, 2, 2250, 'USD', 'Y', NULL, NULL, NULL, NULL,
                         '12345:3', '12345:3', 'Y');
    t := DMT_CMP_ROW_TAB(r);
    IF t.COUNT = 1 AND t(1).STG_COUNT = 3
       -- the three #94 attributes must round-trip through the constructor
       AND t(1).STG_KEY_CHECKSUM = '12345:3'
       AND t(1).FUSION_KEY_CHECKSUM = '12345:3'
       AND t(1).KEY_MATCH = 'Y' THEN
        DBMS_OUTPUT.PUT_LINE('PASS');
    ELSE
        RAISE_APPLICATION_ERROR(-20900, 'type shape wrong');
    END IF;
END;
/
