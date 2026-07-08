-- PACKAGE DMT_PLAN_BUDGET_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PLAN_BUDGET_FBDI_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_PLAN_BUDGET_FBDI_GEN_PKG
-- Planning Budget Balances FBDI zip generation.
-- ONE zip: EpbcsDataImport.csv
-- ============================================================
    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );
END DMT_PLAN_BUDGET_FBDI_GEN_PKG;
/
