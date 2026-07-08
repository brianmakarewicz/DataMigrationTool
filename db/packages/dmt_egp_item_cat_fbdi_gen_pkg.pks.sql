-- PACKAGE DMT_EGP_ITEM_CAT_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_EGP_ITEM_CAT_FBDI_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_EGP_ITEM_CAT_FBDI_GEN_PKG
-- Generates FBDI CSV for Item Categories
-- (EgpItemCategoriesImportTemplate).
-- ONE zip containing ONE CSV: EgpItemCategoriesInterface.csv
-- FBDI pattern: no header, comma-delimited, position-based.
-- ============================================================

    -- Generate the categories CSV CLOB only (no ZIP, no submit).
    -- Called by DMT_EGP_ITEM_FBDI_GEN_PKG to bundle into the Items ZIP.
    FUNCTION GENERATE_CSV (
        p_run_id  IN  NUMBER
    ) RETURN CLOB;

    -- Standalone FBDI generation (legacy — not used in pipeline since
    -- categories are bundled with Items under ItemImportJobDef).
    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );

END DMT_EGP_ITEM_CAT_FBDI_GEN_PKG;
/
