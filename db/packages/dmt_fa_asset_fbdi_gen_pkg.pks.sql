-- PACKAGE DMT_FA_ASSET_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FA_ASSET_FBDI_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_FA_ASSET_FBDI_GEN_PKG
-- Assets FBDI zip generation (Fixed Asset Mass Additions Import).
-- ONE zip. The Fusion FBDI template (FaMassAdditions.xlsm) exposes THREE tabs /
-- interface tables, but DMT only generates the first two:
--   * FaMassAdditions.csv      -> FA_MASS_ADDITIONS       (built from the HDR
--                                 and BOOK source tables joined on ASSET_NUMBER:
--                                 asset identity + per-book financial/depreciation)
--   * FaMassaddDistributions.csv -> FA_MASSADD_DISTRIBUTIONS (built from the
--                                 ASSIGN source table: units + location + expense
--                                 account distributions)
--   * FaMcMassRates.csv        -> FA_MC_MASS_RATES        (multi-currency rates --
--                                 NOT modeled in DMT; see objects/Assets/README.md
--                                 "Table-name vs FBDI-tab audit" for the finding).
-- NOTE: DMT's three source STG/TFM tables (HDR / BOOK / ASSIGN) do NOT map 1:1 to
-- the FBDI tabs by name. HDR+BOOK together feed the single FaMassAdditions tab, and
-- ASSIGN feeds the FaMassaddDistributions ("Distributions") tab. This is a modeling
-- choice, not a defect; see the README audit before renaming anything.
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
