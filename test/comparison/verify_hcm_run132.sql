-- End-to-end verification of the post-run comparison report rolled out to
-- the FINAL family: Workers, Salaries, TalentProfiles (HCM, loaded via HDL,
-- not FBDI). Mirrors test/comparison/verify_ppm_run132.sql. Each assertion
-- makes a LIVE runReport SOAP call into Fusion (via DMT_HCM_COMPARE_PKG,
-- dispatched from DMT_RUN_COMPARE_PKG), proving every object's row reaches
-- Fusion (or, for the one 0-LOADED object, that the live query correctly
-- finds nothing to false-positive on). Nothing counts until it reaches base
-- tables -- this is that proof.
--
-- HDL specifics: there is no import ESS request id for this family. The
-- Fusion tie-back is the HDL key map HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID
-- (= the TFM RECON_KEY of a LOADED record) -> SURROGATE_ID (= the base-table
-- PK). KEY_TYPE = STAMPED_REF for both objects that loaded something this
-- run; TalentProfiles falls back to KEY_TYPE = NONE because 0 rows loaded.
--
-- Discovery-proven values (docs/superpowers/specs/discovery/{Workers,
-- Salaries,TalentProfiles}.md), run 132:
--   Workers         STG=2  err=1  Fusion=1 (LIVE)          count-balanced, KEY=STAMPED_REF, money=N
--   Salaries        STG=2/155000  err=1/80000  Fusion=1/75000 (LIVE)  balanced count+money, KEY=STAMPED_REF, money=Y
--   TalentProfiles  STG=2  err=2  Fusion=0 (0 LOADED)       balanced 0+2=2, KEY=NONE (0 LOADED this run), money=N
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

        IF v.CEMLI_CODE = 'Workers' THEN
            seen(v.CEMLI_CODE) := TRUE;
            dump(v);
            assert_str('Workers KEY_TYPE',             v.KEY_TYPE,             'STAMPED_REF');
            assert_num('Workers STG_COUNT',            v.STG_COUNT,            2);
            assert_num('Workers TFM_ERROR_COUNT',      v.TFM_ERROR_COUNT,      1);
            assert_num('Workers FUSION_SUCCESS_COUNT', v.FUSION_SUCCESS_COUNT, 1);
            assert_num('Workers VARIANCE_COUNT',       v.VARIANCE_COUNT,       0);
            assert_str('Workers IN_BALANCE',           v.IN_BALANCE,           'Y');
            assert_str('Workers FUSION_MONEY_AVAILABLE', v.FUSION_MONEY_AVAILABLE, 'N');
            assert_null('Workers STG_AMOUNT',          v.STG_AMOUNT);
            assert_null('Workers FUSION_SUCCESS_AMOUNT', v.FUSION_SUCCESS_AMOUNT);

        ELSIF v.CEMLI_CODE = 'Salaries' THEN
            seen(v.CEMLI_CODE) := TRUE;
            dump(v);
            assert_str('Salaries KEY_TYPE',             v.KEY_TYPE,             'STAMPED_REF');
            assert_num('Salaries STG_COUNT',            v.STG_COUNT,            2);
            assert_num('Salaries STG_AMOUNT',           v.STG_AMOUNT,           155000);
            assert_num('Salaries TFM_ERROR_COUNT',      v.TFM_ERROR_COUNT,      1);
            assert_num('Salaries TFM_ERROR_AMOUNT',     v.TFM_ERROR_AMOUNT,     80000);
            assert_num('Salaries FUSION_SUCCESS_COUNT', v.FUSION_SUCCESS_COUNT, 1);
            assert_num('Salaries FUSION_SUCCESS_AMOUNT',v.FUSION_SUCCESS_AMOUNT,75000);
            assert_num('Salaries VARIANCE_COUNT',       v.VARIANCE_COUNT,       0);
            assert_num('Salaries VARIANCE_AMOUNT',      v.VARIANCE_AMOUNT,      0);
            assert_str('Salaries IN_BALANCE',           v.IN_BALANCE,           'Y');
            assert_str('Salaries FUSION_MONEY_AVAILABLE', v.FUSION_MONEY_AVAILABLE, 'Y');
            assert_str('Salaries AMOUNT_CURRENCY',      v.AMOUNT_CURRENCY,      'USD');

        ELSIF v.CEMLI_CODE = 'TalentProfiles' THEN
            seen(v.CEMLI_CODE) := TRUE;
            dump(v);
            assert_num('TalentProfiles STG_COUNT',            v.STG_COUNT,            2);
            assert_num('TalentProfiles TFM_ERROR_COUNT',      v.TFM_ERROR_COUNT,      2);
            assert_num('TalentProfiles FUSION_SUCCESS_COUNT', v.FUSION_SUCCESS_COUNT, 0);
            assert_str('TalentProfiles IN_BALANCE',           v.IN_BALANCE,           'Y');
            assert_str('TalentProfiles FUSION_MONEY_AVAILABLE', v.FUSION_MONEY_AVAILABLE, 'N');
            assert_null('TalentProfiles STG_AMOUNT',          v.STG_AMOUNT);
        END IF;
    END LOOP;
    CLOSE c;

    FOR obj IN (SELECT COLUMN_VALUE cemli FROM TABLE(SYS.ODCIVARCHAR2LIST(
        'Workers','Salaries','TalentProfiles'))) LOOP
        IF NOT seen.EXISTS(obj.cemli) THEN
            RAISE_APPLICATION_ERROR(-20914, obj.cemli||' row missing from run 132 comparison grid');
        END IF;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('PASS total_rows='||n||' hcm_objects_verified=3 (FINAL FAMILY)');
END;
/
