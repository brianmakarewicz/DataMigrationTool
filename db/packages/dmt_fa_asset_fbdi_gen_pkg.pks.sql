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

    -- FAIL_GENERATED_ROWS -- the book zip's load failed (backlog #673).
    -- Marks every GENERATED row of the run's Assets zip for p_book (NULL = all
    -- books) FAILED with p_error_text, in ALL THREE record types (headers, books,
    -- assignments), scoped exactly as GENERATE_FBDI scoped them. The caller
    -- (DMT_LOADER_PKG.fin_mark_generated_failed, synchronous load-failure path)
    -- passes the [LOAD_ERROR] text; this procedure never composes one. LOADED,
    -- STAGED and FAILED rows are never touched. NO COMMIT (the caller commits).
    -- x_rows_failed = rows changed across the three tables.
    -- x_error_code  = DMT_UTIL_PKG.C_SUCCESS / C_ERROR (failure logged).
    PROCEDURE FAIL_GENERATED_ROWS (
        p_run_id      IN  NUMBER,
        p_book        IN  VARCHAR2,
        p_error_text  IN  VARCHAR2,
        x_rows_failed OUT NUMBER,
        x_error_code  OUT NUMBER
    );
END DMT_FA_ASSET_FBDI_GEN_PKG;
/
