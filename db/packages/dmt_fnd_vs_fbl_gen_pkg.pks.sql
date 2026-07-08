-- PACKAGE DMT_FND_VS_FBL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FND_VS_FBL_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_FND_VS_FBL_GEN_PKG
-- Generates pipe-delimited FBL files for Fusion Value Sets.
-- TWO files in one zip:
--   ValueSetCode.csv  (pipe-delimited, WITH header)
--   ValueSetValue.csv (pipe-delimited, WITH header)
-- Key difference from FBDI: FBL files have headers and use
-- pipe delimiter. Values are NOT quoted.
-- ============================================================

    PROCEDURE GENERATE_FBL (
        p_run_id  IN  NUMBER,
        x_fbl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );

END DMT_FND_VS_FBL_GEN_PKG;
/
