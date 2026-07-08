-- PACKAGE DMT_ZX_FBL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_ZX_FBL_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_ZX_FBL_GEN_PKG
-- Generates pipe-delimited FBL files for Fusion Tax configuration.
-- TWO files in one zip:
--   TaxRegime.csv  (pipe-delimited, WITH header)
--   TaxRate.csv    (pipe-delimited, WITH header)
-- Key difference from FBDI: FBL files have headers and use
-- pipe delimiter. Values are NOT quoted.
-- ============================================================

    PROCEDURE GENERATE_FBL (
        p_run_id  IN  NUMBER,
        x_fbl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );

END DMT_ZX_FBL_GEN_PKG;
/
