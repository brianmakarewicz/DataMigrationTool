-- PACKAGE DMT_PROJECT_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PROJECT_FBDI_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_PROJECT_FBDI_GEN_PKG spec
-- Projects FBDI zip generation.
-- 4 CSVs: PjfProjectsAllXface.csv, PjfProjElementsXface.csv,
-- PjfProjectPartiesInt.csv, PjcTxnControlsStage.csv
-- Single submission (not grouped).
-- ============================================================
    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );

    -- FAIL_GENERATED_ROWS -- the zip's load failed (backlog #672).
    -- Marks every GENERATED row of the run's Projects zip FAILED with
    -- p_error_text, in ALL FOUR record types (projects, tasks, team members,
    -- transaction controls), so no record of the failed load is left behind as
    -- GENERATED. The caller (DMT_LOADER_PKG.fin_mark_generated_failed,
    -- synchronous load-failure path) passes the [LOAD_ERROR] text; this
    -- procedure never composes one. LOADED, STAGED and FAILED rows are never
    -- touched. NO COMMIT (the caller commits).
    -- x_rows_failed = rows changed across the four tables.
    -- x_error_code  = DMT_UTIL_PKG.C_SUCCESS / C_ERROR (failure logged).
    PROCEDURE FAIL_GENERATED_ROWS (
        p_run_id      IN  NUMBER,
        p_error_text  IN  VARCHAR2,
        x_rows_failed OUT NUMBER,
        x_error_code  OUT NUMBER
    );
END DMT_PROJECT_FBDI_GEN_PKG;
/
