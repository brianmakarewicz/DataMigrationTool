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
END DMT_PROJECT_FBDI_GEN_PKG;
/
