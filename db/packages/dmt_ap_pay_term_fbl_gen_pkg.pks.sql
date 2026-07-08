-- PACKAGE DMT_AP_PAY_TERM_FBL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AP_PAY_TERM_FBL_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AP_PAY_TERM_FBL_GEN_PKG
-- Generates pipe-delimited FBL files for AP Payment Terms.
-- TWO files in one zip:
--   PayTermHeader.csv  (pipe-delimited, WITH header)
--   PayTermLine.csv    (pipe-delimited, WITH header)
-- ============================================================

    PROCEDURE GENERATE_FBL (
        p_run_id  IN  NUMBER,
        x_fbl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );

END DMT_AP_PAY_TERM_FBL_GEN_PKG;
/
