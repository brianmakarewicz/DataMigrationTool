CREATE OR REPLACE PACKAGE BODY DMT_RUN_COMPARE_PKG AS
    C_PKG CONSTANT VARCHAR2(30) := 'DMT_RUN_COMPARE_PKG';

    FUNCTION BUILD_ROWS(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_TAB IS
        l_out DMT_CMP_ROW_TAB := DMT_CMP_ROW_TAB();
        l_row DMT_CMP_ROW_OBJ;
    BEGIN
        FOR obj IN (
            SELECT DISTINCT r.CEMLI_CODE, r.CMP_FUNCTION
              FROM DMT_WORK_QUEUE_TBL wq
              JOIN DMT_BIP_REPORT_TBL r ON r.CEMLI_CODE = wq.CEMLI_CODE
             WHERE wq.RUN_ID = p_run_id
               AND r.CMP_FUNCTION IS NOT NULL
             ORDER BY r.CEMLI_CODE
        ) LOOP
            BEGIN
                -- Sanctioned dynamic-invocation site #4 per DMT_DESIGN.html rule #66
                -- (amended 2026-09-28, owner-directed). CMP_FUNCTION is a PKG.FUNC
                -- name sourced only from the PR-reviewed registry DMT_BIP_REPORT_TBL.
                -- Enforce the rule's allow-pattern before invoking; the value that
                -- varies (p_run_id) travels as a bind, never concatenated.
                IF NOT REGEXP_LIKE(obj.CMP_FUNCTION,
                        '^[A-Z][A-Z0-9_$#]*\.[A-Z][A-Z0-9_$#]*$') THEN
                    RAISE_APPLICATION_ERROR(-20910,
                        'CMP_FUNCTION is not a valid PKG.FUNC identifier: '||
                        obj.CMP_FUNCTION);
                END IF;
                EXECUTE IMMEDIATE
                    'BEGIN :r := '||obj.CMP_FUNCTION||'(:p); END;'
                    USING OUT l_row, IN p_run_id;
                l_out.EXTEND; l_out(l_out.LAST) := l_row;
            EXCEPTION WHEN OTHERS THEN
                -- Never let one broken/unregistered object's comparison
                -- function fail the whole grid -- but never silently drop
                -- the object either. A raised comparison function (e.g. a
                -- BIP SOAP fault, which every family function surfaces via
                -- RAISE_APPLICATION_ERROR(-20903) rather than reading a
                -- fault as 0) means Fusion's side could not be confirmed --
                -- that is different from "not in this run" and must stay
                -- visible on the grid as an explicit unknown row.
                DMT_UTIL_PKG.LOG_ERROR(
                    p_run_id    => p_run_id,
                    p_message   => 'Comparison function failed for CEMLI_CODE='||
                                    obj.CEMLI_CODE||' ('||obj.CMP_FUNCTION||'); marked unknown on grid',
                    p_sqlerrm   => SQLERRM,
                    p_package   => C_PKG,
                    p_procedure => 'BUILD_ROWS');
                l_out.EXTEND;
                l_out(l_out.LAST) := DMT_CMP_ROW_OBJ(
                    obj.CEMLI_CODE, obj.CEMLI_CODE, 'NONE',
                    NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'N', NULL, NULL,
                    '?', 'Comparison unavailable: '||SUBSTR(SQLERRM,1,300));
            END;
        END LOOP;
        RETURN l_out;
    END BUILD_ROWS;

    PROCEDURE GET_RUN_COMPARISON(p_run_id IN NUMBER, x_cursor OUT SYS_REFCURSOR) IS
        l_rows DMT_CMP_ROW_TAB := BUILD_ROWS(p_run_id);
    BEGIN
        OPEN x_cursor FOR
            SELECT VALUE(t) FROM TABLE(l_rows) t;
    END GET_RUN_COMPARISON;
END DMT_RUN_COMPARE_PKG;
/
