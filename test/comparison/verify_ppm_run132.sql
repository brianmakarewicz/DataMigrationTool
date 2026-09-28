-- End-to-end verification of the post-run comparison report rolled out to
-- the five Projects/PPM objects (Projects, ProjectBudgets, Expenditures,
-- BillingEvents, Grants), mirroring test/comparison/verify_run132.sql for
-- PurchaseOrders. Each assertion makes a LIVE runReport SOAP call into
-- Fusion (via DMT_PPM_COMPARE_PKG, dispatched from DMT_RUN_COMPARE_PKG),
-- proving every object's row reaches Fusion (or, for the two 0-LOADED
-- objects, that the live query correctly finds nothing to false-positive
-- on). Nothing counts until it reaches base tables -- this is that proof.
--
-- Discovery-proven values (docs/superpowers/specs/discovery/{Projects,
-- ProjectBudgets,Expenditures,BillingEvents,Grants}.md), run 132:
--   Projects        STG=3  err=1  Fusion=2 (LIVE)   count-balanced, KEY=CAPTURED_ID, money=N
--   ProjectBudgets  STG=3  err=3  Fusion=0 (0 LOADED)  balanced 0+3=3, KEY=CAPTURED_ID (NONE this run), money=Y
--   Expenditures    STG=8  err=6  Fusion=2 (LIVE, $3840)  count-balanced 2+6=8, KEY=IMPORT_ID, money=Y (honest nonzero variance)
--   BillingEvents   STG=3  err=1  Fusion=2 (LIVE, $2)  balanced count+money 2+1=3 / $2+$1000=$1002, KEY=IMPORT_ID, money=Y
--   Grants          STG=3  err=3  Fusion=0 (0 LOADED)  balanced 0+3=3, KEY=IMPORT_ID (NONE this run), money=N
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

    PROCEDURE dump(p_v IN DMT_CMP_ROW_OBJ) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('--- '||p_v.CEMLI_CODE||' ---');
        DBMS_OUTPUT.PUT_LINE('OBJECT_TYPE='||p_v.OBJECT_TYPE);
        DBMS_OUTPUT.PUT_LINE('KEY_TYPE='||p_v.KEY_TYPE);
        DBMS_OUTPUT.PUT_LINE('STG_COUNT='||p_v.STG_COUNT||' STG_AMOUNT='||p_v.STG_AMOUNT);
        DBMS_OUTPUT.PUT_LINE('TFM_ERROR_COUNT='||p_v.TFM_ERROR_COUNT||' TFM_ERROR_AMOUNT='||p_v.TFM_ERROR_AMOUNT);
        DBMS_OUTPUT.PUT_LINE('FUSION_SUCCESS_COUNT='||p_v.FUSION_SUCCESS_COUNT||' FUSION_SUCCESS_AMOUNT='||p_v.FUSION_SUCCESS_AMOUNT);
        DBMS_OUTPUT.PUT_LINE('AMOUNT_CURRENCY='||p_v.AMOUNT_CURRENCY);
        DBMS_OUTPUT.PUT_LINE('FUSION_MONEY_AVAILABLE='||p_v.FUSION_MONEY_AVAILABLE);
        DBMS_OUTPUT.PUT_LINE('VARIANCE_COUNT='||p_v.VARIANCE_COUNT||' VARIANCE_AMOUNT='||p_v.VARIANCE_AMOUNT);
        DBMS_OUTPUT.PUT_LINE('IN_BALANCE='||p_v.IN_BALANCE);
        DBMS_OUTPUT.PUT_LINE('NOTE='||p_v.NOTE);
    END dump;
BEGIN
    DMT_RUN_COMPARE_PKG.GET_RUN_COMPARISON(132, c);
    LOOP
        FETCH c INTO v;
        EXIT WHEN c%NOTFOUND;
        n := n + 1;

        IF v.CEMLI_CODE = 'Projects' THEN
            seen(v.CEMLI_CODE) := TRUE;
            dump(v);
            assert_str('Projects KEY_TYPE',             v.KEY_TYPE,             'CAPTURED_ID');
            assert_num('Projects STG_COUNT',            v.STG_COUNT,            3);
            assert_num('Projects TFM_ERROR_COUNT',      v.TFM_ERROR_COUNT,      1);
            assert_num('Projects FUSION_SUCCESS_COUNT', v.FUSION_SUCCESS_COUNT, 2);
            assert_num('Projects VARIANCE_COUNT',       v.VARIANCE_COUNT,       0);
            assert_str('Projects IN_BALANCE',           v.IN_BALANCE,           'Y');
            assert_str('Projects FUSION_MONEY_AVAILABLE', v.FUSION_MONEY_AVAILABLE, 'N');
            assert_null('Projects STG_AMOUNT',          v.STG_AMOUNT);
            assert_null('Projects FUSION_SUCCESS_AMOUNT', v.FUSION_SUCCESS_AMOUNT);

        ELSIF v.CEMLI_CODE = 'ProjectBudgets' THEN
            seen(v.CEMLI_CODE) := TRUE;
            dump(v);
            assert_num('ProjectBudgets STG_COUNT',            v.STG_COUNT,            3);
            assert_num('ProjectBudgets STG_AMOUNT',           v.STG_AMOUNT,           125999.99);
            assert_num('ProjectBudgets TFM_ERROR_COUNT',      v.TFM_ERROR_COUNT,      3);
            assert_num('ProjectBudgets TFM_ERROR_AMOUNT',     v.TFM_ERROR_AMOUNT,     125999.99);
            assert_num('ProjectBudgets FUSION_SUCCESS_COUNT', v.FUSION_SUCCESS_COUNT, 0);
            assert_str('ProjectBudgets IN_BALANCE',           v.IN_BALANCE,           'Y');
            assert_str('ProjectBudgets FUSION_MONEY_AVAILABLE', v.FUSION_MONEY_AVAILABLE, 'Y');

        ELSIF v.CEMLI_CODE = 'Expenditures' THEN
            seen(v.CEMLI_CODE) := TRUE;
            dump(v);
            assert_str('Expenditures KEY_TYPE',             v.KEY_TYPE,             'IMPORT_ID');
            assert_num('Expenditures STG_COUNT',            v.STG_COUNT,            8);
            assert_num('Expenditures STG_AMOUNT',           v.STG_AMOUNT,           12499.99);
            assert_num('Expenditures TFM_ERROR_COUNT',      v.TFM_ERROR_COUNT,      6);
            assert_num('Expenditures TFM_ERROR_AMOUNT',     v.TFM_ERROR_AMOUNT,     8499.99);
            assert_num('Expenditures FUSION_SUCCESS_COUNT', v.FUSION_SUCCESS_COUNT, 2);
            assert_num('Expenditures FUSION_SUCCESS_AMOUNT',v.FUSION_SUCCESS_AMOUNT,3840);
            assert_num('Expenditures VARIANCE_COUNT',       v.VARIANCE_COUNT,       0);
            assert_str('Expenditures IN_BALANCE',           v.IN_BALANCE,           'Y');
            assert_str('Expenditures FUSION_MONEY_AVAILABLE', v.FUSION_MONEY_AVAILABLE, 'Y');
            -- Honest nonzero money variance: submitted 4000 vs Fusion-recomputed 3840.
            -- 12499.99 - (3840 + 8499.99) = 160.00 -- the recompute gap, not an error.
            IF v.VARIANCE_AMOUNT IS NULL OR v.VARIANCE_AMOUNT = 0 THEN
                RAISE_APPLICATION_ERROR(-20913,
                    'Expenditures VARIANCE_AMOUNT expected NONZERO (Fusion recompute), got '||
                    NVL(TO_CHAR(v.VARIANCE_AMOUNT),'NULL'));
            END IF;

        ELSIF v.CEMLI_CODE = 'BillingEvents' THEN
            seen(v.CEMLI_CODE) := TRUE;
            dump(v);
            assert_str('BillingEvents KEY_TYPE',             v.KEY_TYPE,             'IMPORT_ID');
            assert_num('BillingEvents STG_COUNT',            v.STG_COUNT,            3);
            assert_num('BillingEvents STG_AMOUNT',           v.STG_AMOUNT,           1002);
            assert_num('BillingEvents TFM_ERROR_COUNT',      v.TFM_ERROR_COUNT,      1);
            assert_num('BillingEvents TFM_ERROR_AMOUNT',     v.TFM_ERROR_AMOUNT,     1000);
            assert_num('BillingEvents FUSION_SUCCESS_COUNT', v.FUSION_SUCCESS_COUNT, 2);
            assert_num('BillingEvents FUSION_SUCCESS_AMOUNT',v.FUSION_SUCCESS_AMOUNT,2);
            assert_num('BillingEvents VARIANCE_COUNT',       v.VARIANCE_COUNT,       0);
            assert_num('BillingEvents VARIANCE_AMOUNT',      v.VARIANCE_AMOUNT,      0);
            assert_str('BillingEvents IN_BALANCE',           v.IN_BALANCE,           'Y');
            assert_str('BillingEvents FUSION_MONEY_AVAILABLE', v.FUSION_MONEY_AVAILABLE, 'Y');

        ELSIF v.CEMLI_CODE = 'Grants' THEN
            seen(v.CEMLI_CODE) := TRUE;
            dump(v);
            assert_num('Grants STG_COUNT',            v.STG_COUNT,            3);
            assert_num('Grants TFM_ERROR_COUNT',      v.TFM_ERROR_COUNT,      3);
            assert_num('Grants FUSION_SUCCESS_COUNT', v.FUSION_SUCCESS_COUNT, 0);
            assert_str('Grants IN_BALANCE',           v.IN_BALANCE,           'Y');
            assert_str('Grants FUSION_MONEY_AVAILABLE', v.FUSION_MONEY_AVAILABLE, 'N');
            assert_null('Grants STG_AMOUNT',          v.STG_AMOUNT);
        END IF;
    END LOOP;
    CLOSE c;

    FOR obj IN (SELECT COLUMN_VALUE cemli FROM TABLE(SYS.ODCIVARCHAR2LIST(
        'Projects','ProjectBudgets','Expenditures','BillingEvents','Grants'))) LOOP
        IF NOT seen.EXISTS(obj.cemli) THEN
            RAISE_APPLICATION_ERROR(-20914, obj.cemli||' row missing from run 132 comparison grid');
        END IF;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('PASS total_rows='||n||' ppm_objects_verified=5');
END;
/
