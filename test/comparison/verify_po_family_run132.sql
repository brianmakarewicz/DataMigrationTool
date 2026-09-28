-- End-to-end verification of the post-run comparison report rolled out to
-- the two remaining PO-family objects, BlanketPOs and Contracts, mirroring
-- test/comparison/verify_run132.sql for PurchaseOrders and
-- test/comparison/verify_suppliers_run132.sql for the supplier family. Each
-- assertion makes a LIVE runReport SOAP call into Fusion (via
-- DMT_PO_COMPARE_PKG.GET_BLANKET_COMPARISON / GET_CONTRACT_COMPARISON,
-- dispatched from DMT_RUN_COMPARE_PKG), proving every object's row reaches
-- Fusion base tables and reconciles. Nothing counts until it reaches base
-- tables -- this is that proof, end to end.
--
-- Discovery-proven values (docs/superpowers/specs/discovery/{BlanketPOs,
-- Contracts}.md), run 132:
--   BlanketPOs: STG=2, TFM_ERROR=1, FUSION_SUCCESS=1, VARIANCE=0, balanced.
--     Money is DMT-side only (TFM line AMOUNT=50000 on the one LOADED
--     header's line); Fusion never persists a queryable amount for a
--     quantity-based blanket line, so FUSION_SUCCESS_AMOUNT is NULL and
--     FUSION_MONEY_AVAILABLE='N' (balance decided on count only).
--   Contracts: STG=2, TFM_ERROR=1, FUSION_SUCCESS=1, VARIANCE=0, balanced.
--     Header-only document, no money grain anywhere (DMT or Fusion) --
--     every *_AMOUNT column NULL, FUSION_MONEY_AVAILABLE='N'.
--   Both: KEY_TYPE=IMPORT_ID (import ESS request id, never the prefix).
SET SERVEROUTPUT ON
DECLARE
    c SYS_REFCURSOR;
    v DMT_CMP_ROW_OBJ;
    n NUMBER := 0;

    TYPE t_seen_tab IS TABLE OF BOOLEAN INDEX BY VARCHAR2(60);
    seen t_seen_tab;

    PROCEDURE assert_num(p_label IN VARCHAR2, p_actual IN NUMBER, p_expected IN NUMBER) IS
    BEGIN
        IF p_actual IS NULL OR p_actual != p_expected THEN
            RAISE_APPLICATION_ERROR(-20910,
                p_label||' expected '||p_expected||' got '||NVL(TO_CHAR(p_actual),'NULL'));
        END IF;
    END assert_num;

    PROCEDURE assert_str(p_label IN VARCHAR2, p_actual IN VARCHAR2, p_expected IN VARCHAR2) IS
    BEGIN
        IF p_actual IS NULL OR p_actual != p_expected THEN
            RAISE_APPLICATION_ERROR(-20911,
                p_label||' expected '||p_expected||' got '||NVL(p_actual,'NULL'));
        END IF;
    END assert_str;

    PROCEDURE assert_null(p_label IN VARCHAR2, p_actual IN NUMBER) IS
    BEGIN
        IF p_actual IS NOT NULL THEN
            RAISE_APPLICATION_ERROR(-20912,
                p_label||' expected NULL got '||TO_CHAR(p_actual));
        END IF;
    END assert_null;
BEGIN
    DMT_RUN_COMPARE_PKG.GET_RUN_COMPARISON(132, c);
    LOOP
        FETCH c INTO v;
        EXIT WHEN c%NOTFOUND;
        n := n + 1;

        IF v.CEMLI_CODE IN ('BlanketPOs','Contracts') THEN
            seen(v.CEMLI_CODE) := TRUE;

            DBMS_OUTPUT.PUT_LINE('--- '||v.CEMLI_CODE||' ---');
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

            assert_str('KEY_TYPE ('||v.CEMLI_CODE||')',             v.KEY_TYPE,             'IMPORT_ID');
            assert_num('STG_COUNT ('||v.CEMLI_CODE||')',            v.STG_COUNT,            2);
            assert_num('TFM_ERROR_COUNT ('||v.CEMLI_CODE||')',      v.TFM_ERROR_COUNT,      1);
            assert_num('FUSION_SUCCESS_COUNT ('||v.CEMLI_CODE||')', v.FUSION_SUCCESS_COUNT, 1);
            assert_num('VARIANCE_COUNT ('||v.CEMLI_CODE||')',       v.VARIANCE_COUNT,       0);
            assert_str('IN_BALANCE ('||v.CEMLI_CODE||')',           v.IN_BALANCE,           'Y');
            assert_str('FUSION_MONEY_AVAILABLE ('||v.CEMLI_CODE||')', v.FUSION_MONEY_AVAILABLE, 'N');
            assert_null('FUSION_SUCCESS_AMOUNT ('||v.CEMLI_CODE||')', v.FUSION_SUCCESS_AMOUNT);
            assert_null('VARIANCE_AMOUNT ('||v.CEMLI_CODE||')',     v.VARIANCE_AMOUNT);

            IF v.CEMLI_CODE = 'BlanketPOs' THEN
                -- Money is DMT-side only: the single LOADED header's line
                -- carries AMOUNT=50000; the FAILED header has no line (0).
                assert_num('STG_AMOUNT (BlanketPOs)',       v.STG_AMOUNT,       50000);
                assert_num('TFM_ERROR_AMOUNT (BlanketPOs)', v.TFM_ERROR_AMOUNT, 0);
            ELSE
                -- Contracts: header-only, no money grain anywhere.
                assert_null('STG_AMOUNT (Contracts)',       v.STG_AMOUNT);
                assert_null('TFM_ERROR_AMOUNT (Contracts)', v.TFM_ERROR_AMOUNT);
            END IF;
        END IF;
    END LOOP;
    CLOSE c;

    FOR obj IN (SELECT COLUMN_VALUE cemli FROM TABLE(SYS.ODCIVARCHAR2LIST(
        'BlanketPOs','Contracts'))) LOOP
        IF NOT seen.EXISTS(obj.cemli) THEN
            RAISE_APPLICATION_ERROR(-20913, obj.cemli||' row missing from run 132 comparison grid');
        END IF;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('PASS total_rows='||n||' po_family_objects_verified=2');
END;
/
