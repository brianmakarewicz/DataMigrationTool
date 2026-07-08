-- PACKAGE DMT_EXPENDITURE_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_EXPENDITURE_FBDI_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_EXPENDITURE_FBDI_GEN_PKG spec
-- Expenditures FBDI zip generation.
-- Single CSV: PjcTxnXfaceStageAll.csv
-- Single submission (not grouped).
-- ============================================================
    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );
END DMT_EXPENDITURE_FBDI_GEN_PKG;
/
