-- PACKAGE DMT_EGP_ITEM_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_EGP_ITEM_FBDI_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_EGP_ITEM_FBDI_GEN_PKG
-- Generates the Items FBDI zip (ItemImportJobDef).
-- ONE zip containing TWO CSVs (one import job):
--   EgpSystemItemsInterface.csv      -> EGP_SYSTEM_ITEMS_INTERFACE   (item master)
--   EgpItemCategoriesInterface.csv   -> EGP_ITEM_CATEGORIES_INTERFACE (item categories)
-- The categories CSV is produced by DMT_EGP_ITEM_CAT_FBDI_GEN_PKG.GENERATE_CSV
-- and bundled here; Item Categories is a tab of the Items zip, not a standalone
-- import (ItemCategoryImportJobDef is not standalone -- ESS discovery 2026-05-21).
-- FBDI pattern: no header, comma-delimited, position-based.
-- NOTE: CTL position mapping may need adjustment once the actual
-- EgpItemImportTemplate CTL file is verified.
-- ============================================================

    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER,
        p_batch_id        IN  VARCHAR2 DEFAULT NULL
    );

END DMT_EGP_ITEM_FBDI_GEN_PKG;
/
