CREATE OR REPLACE PACKAGE DMT_RUN_COMPARE_PKG AS
    -- Live post-run comparison grid for one run. Enumerates the objects in the
    -- run, dispatches to each object's registered comparison function, and
    -- returns one DMT_CMP_ROW_OBJ per object. Read-only; no writes (other
    -- than logging a skip/error to DMT_LOG_TBL via DMT_UTIL_PKG.LOG_ERROR).
    FUNCTION BUILD_ROWS(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_TAB;
    PROCEDURE GET_RUN_COMPARISON(p_run_id IN NUMBER, x_cursor OUT SYS_REFCURSOR);
END DMT_RUN_COMPARE_PKG;
/
