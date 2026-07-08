-- PACKAGE DMT_CE_BANK_FBL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CE_BANK_FBL_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_CE_BANK_FBL_GEN_PKG
-- Generates pipe-delimited FBL files for Cash Management
-- Banks, Branches, and Accounts.
-- THREE files in one zip:
--   CeBank.csv    (pipe-delimited, WITH header)
--   CeBranch.csv  (pipe-delimited, WITH header)
--   CeAccount.csv (pipe-delimited, WITH header)
-- ============================================================

    PROCEDURE GENERATE_FBL (
        p_run_id  IN  NUMBER,
        x_fbl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );

END DMT_CE_BANK_FBL_GEN_PKG;
/
