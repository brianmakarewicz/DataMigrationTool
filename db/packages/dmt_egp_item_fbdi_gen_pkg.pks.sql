-- PACKAGE DMT_EGP_ITEM_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_EGP_ITEM_FBDI_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_EGP_ITEM_FBDI_GEN_PKG
-- Generates FBDI CSV for Items (EgpItemImportTemplate).
-- ONE zip containing ONE CSV: EgpSystemItemsInterface.csv
-- FBDI pattern: no header, comma-delimited, position-based.
-- NOTE: CTL position mapping may need adjustment once the actual
-- EgpItemImportTemplate CTL file is verified.
-- ============================================================

    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );

END DMT_EGP_ITEM_FBDI_GEN_PKG;
/
