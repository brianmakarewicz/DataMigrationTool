-- PACKAGE DMT_FA_ASSET_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FA_ASSET_FBDI_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_FA_ASSET_FBDI_GEN_PKG
-- Assets FBDI zip generation.
-- ONE zip with THREE CSVs: FaAssetHeaders.csv, FaAssetAssignments.csv, FaAssetBooks.csv
-- ============================================================
    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER,
        p_book            IN  VARCHAR2 DEFAULT NULL  -- multi-book: one FBDI per BOOK_TYPE_CODE
    );
END DMT_FA_ASSET_FBDI_GEN_PKG;
/
