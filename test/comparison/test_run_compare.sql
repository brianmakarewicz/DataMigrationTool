-- Task 5 gate test: run-level comparison framework, run 132 (local Docker).
-- Expects the PurchaseOrders row to be present in the grid (its is the only
-- CEMLI_CODE with CMP_FUNCTION registered so far) and balanced.
SET SERVEROUTPUT ON
DECLARE
    c   SYS_REFCURSOR;
    v   DMT_CMP_ROW_OBJ;
    n   NUMBER := 0;
    po_seen BOOLEAN := FALSE;
BEGIN
    DMT_RUN_COMPARE_PKG.GET_RUN_COMPARISON(132, c);
    LOOP
        FETCH c INTO v;  -- object-type cursor: one DMT_CMP_ROW_OBJ per row
        EXIT WHEN c%NOTFOUND;
        n := n + 1;
        IF v.CEMLI_CODE = 'PurchaseOrders' THEN
            po_seen := TRUE;
            IF v.IN_BALANCE <> 'Y' THEN
                RAISE_APPLICATION_ERROR(-20904,'PO not balanced in framework');
            END IF;
        END IF;
    END LOOP;
    CLOSE c;
    IF po_seen AND n >= 1 THEN DBMS_OUTPUT.PUT_LINE('PASS rows='||n);
    ELSE RAISE_APPLICATION_ERROR(-20905,'PO row missing from framework grid'); END IF;
END;
/
