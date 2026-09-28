-- Comparison-report registry columns (design: post-run comparison report).
-- Adds three columns to DMT_BIP_REPORT_TBL that drive the per-object
-- post-run comparison report: the comparison data model path, the
-- comparison report path, and the PKG.FUNC (returning DMT_CMP_ROW_OBJ)
-- that produces the comparison rows for that object. Idempotent/re-runnable
-- (guarded ALTER, no error and no duplicate-column failure on re-run).
DECLARE
    PROCEDURE add_col(p_col VARCHAR2, p_def VARCHAR2) IS
        n NUMBER;
    BEGIN
        SELECT COUNT(*) INTO n FROM user_tab_columns
         WHERE table_name = 'DMT_BIP_REPORT_TBL' AND column_name = p_col;
        IF n = 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE DMT_BIP_REPORT_TBL ADD ('||p_col||' '||p_def||')';
        END IF;
    END;
BEGIN
    add_col('CMP_DM_CATALOG_PATH',     'VARCHAR2(500)');
    add_col('CMP_REPORT_CATALOG_PATH', 'VARCHAR2(500)');
    add_col('CMP_FUNCTION',            'VARCHAR2(200)');
END;
/
