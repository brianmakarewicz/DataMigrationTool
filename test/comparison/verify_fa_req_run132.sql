-- End-to-end verification of the post-run comparison report rolled out to the
-- two money-bearing objects Assets (Fixed Assets) and Requisitions, mirroring
-- test/comparison/verify_ppm_run132.sql. Each assertion makes a LIVE runReport
-- SOAP call into Fusion (via DMT_FA_REQ_COMPARE_PKG, dispatched from
-- DMT_RUN_COMPARE_PKG), proving every object's rows reach Fusion base tables.
-- Nothing counts until it reaches base tables -- this is that proof.
--
-- Discovery-proven values (docs/superpowers/specs/discovery/{Assets,
-- Requisitions}.md, run 132):
--   Assets        STG=3/156000  err=1/1000  Fusion=2/155000 (LIVE)
--                 balanced count+money (3=2+1, 156000=155000+1000),
--                 KEY_TYPE=LOAD_ID, money=Y.
--   Requisitions  STG=5/1190     err=3/700   Fusion=2/490 (LIVE)
--                 balanced count+money (5=2+3, 1190=490+700),
--                 KEY_TYPE=CAPTURED_ID, money=Y. STG scoped via TFM
--                 STG_SEQUENCE_ID (double-staged seed -> no 10/2380 bug).
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

        IF v.CEMLI_CODE = 'Assets' THEN
            seen(v.CEMLI_CODE) := TRUE;
            dump(v);
            assert_str('Assets KEY_TYPE',               v.KEY_TYPE,               'LOAD_ID');
            assert_str('Assets FUSION_MONEY_AVAILABLE',  v.FUSION_MONEY_AVAILABLE, 'Y');
            assert_num('Assets STG_COUNT',               v.STG_COUNT,               3);
            assert_num('Assets STG_AMOUNT',              v.STG_AMOUNT,              156000);
            assert_num('Assets TFM_ERROR_COUNT',         v.TFM_ERROR_COUNT,         1);
            assert_num('Assets TFM_ERROR_AMOUNT',        v.TFM_ERROR_AMOUNT,       1000);
            assert_num('Assets FUSION_SUCCESS_COUNT',    v.FUSION_SUCCESS_COUNT,    2);
            assert_num('Assets FUSION_SUCCESS_AMOUNT',   v.FUSION_SUCCESS_AMOUNT,  155000);
            assert_num('Assets VARIANCE_COUNT',          v.VARIANCE_COUNT,          0);
            assert_num('Assets VARIANCE_AMOUNT',         v.VARIANCE_AMOUNT,         0);
            assert_str('Assets IN_BALANCE',              v.IN_BALANCE,             'Y');

        ELSIF v.CEMLI_CODE = 'Requisitions' THEN
            seen(v.CEMLI_CODE) := TRUE;
            dump(v);
            assert_str('Requisitions KEY_TYPE',              v.KEY_TYPE,               'CAPTURED_ID');
            assert_str('Requisitions FUSION_MONEY_AVAILABLE',v.FUSION_MONEY_AVAILABLE, 'Y');
            assert_num('Requisitions STG_COUNT',             v.STG_COUNT,               5);
            assert_num('Requisitions STG_AMOUNT',            v.STG_AMOUNT,             1190);
            assert_num('Requisitions TFM_ERROR_COUNT',       v.TFM_ERROR_COUNT,         3);
            assert_num('Requisitions TFM_ERROR_AMOUNT',      v.TFM_ERROR_AMOUNT,       700);
            assert_num('Requisitions FUSION_SUCCESS_COUNT',  v.FUSION_SUCCESS_COUNT,    2);
            assert_num('Requisitions FUSION_SUCCESS_AMOUNT', v.FUSION_SUCCESS_AMOUNT,  490);
            assert_num('Requisitions VARIANCE_COUNT',        v.VARIANCE_COUNT,          0);
            assert_num('Requisitions VARIANCE_AMOUNT',       v.VARIANCE_AMOUNT,         0);
            assert_str('Requisitions IN_BALANCE',            v.IN_BALANCE,             'Y');
        END IF;
    END LOOP;
    CLOSE c;

    FOR obj IN (SELECT COLUMN_VALUE cemli FROM TABLE(SYS.ODCIVARCHAR2LIST(
        'Assets','Requisitions'))) LOOP
        IF NOT seen.EXISTS(obj.cemli) THEN
            RAISE_APPLICATION_ERROR(-20914, obj.cemli||' row missing from run 132 comparison grid');
        END IF;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('PASS total_rows='||n||' fa_req_objects_verified=2');
END;
/
