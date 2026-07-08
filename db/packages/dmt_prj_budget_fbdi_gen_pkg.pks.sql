-- PACKAGE DMT_PRJ_BUDGET_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PRJ_BUDGET_FBDI_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_PRJ_BUDGET_FBDI_GEN_PKG
-- Project Budgets FBDI zip generation.
-- ONE zip: PjoPlanVersionsXface.csv
-- ============================================================
    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );
END DMT_PRJ_BUDGET_FBDI_GEN_PKG;
/
