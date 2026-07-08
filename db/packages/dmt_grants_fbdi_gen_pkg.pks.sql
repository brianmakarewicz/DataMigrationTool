-- PACKAGE DMT_GRANTS_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GRANTS_FBDI_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_GRANTS_FBDI_GEN_PKG spec
-- Grants FBDI zip generation.
-- 15 CSVs in one ZIP. Single submission (not grouped).
-- UCM account: prj/grantsManagement/import
-- ============================================================
    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );
END DMT_GRANTS_FBDI_GEN_PKG;
/
