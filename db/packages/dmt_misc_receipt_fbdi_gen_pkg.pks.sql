-- PACKAGE DMT_MISC_RECEIPT_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_MISC_RECEIPT_FBDI_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_MISC_RECEIPT_FBDI_GEN_PKG
-- MiscReceipts (On Hand Qty) FBDI zip generation.
--
-- ONE zip containing 1-3 CSVs:
--   InvTransactionsInterface.csv      -> INV_TRANSACTIONS_INTERFACE (always)
--   InvTransactionLotsInterface.csv   -> INV_TRANSACTIONS_LOTS_INTERFACE (if lots exist)
--   InvSerialNumbersInterface.csv     -> INV_SERIAL_NUMBERS_INTERFACE (if serials exist)
--
-- Column order per InvTransactionsInterface.ctl (273 CSV columns).
-- No header row — Oracle FBDI CSVs are data-only, position-based.
-- Per MCCS RICE_011/012 pattern.
-- ============================================================

    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );

    -- FAIL_GENERATED_ROWS -- the zip's load failed (backlog #633).
    -- Marks every GENERATED row of the run's MiscReceipts zip FAILED with
    -- p_error_text, in ALL THREE record types (transactions, lots, serials),
    -- so no record of the failed load is left behind as GENERATED. The caller
    -- (DMT_LOADER_PKG.RUN_MISC_RECEIPTS, synchronous load-failure path) passes
    -- the [LOAD_ERROR] text; this procedure never composes one. LOADED and
    -- FAILED rows are never touched. NO COMMIT (the caller commits).
    -- x_rows_failed = rows changed across the three tables.
    -- x_error_code  = DMT_UTIL_PKG.C_SUCCESS / C_ERROR (failure logged).
    PROCEDURE FAIL_GENERATED_ROWS (
        p_run_id      IN  NUMBER,
        p_error_text  IN  VARCHAR2,
        x_rows_failed OUT NUMBER,
        x_error_code  OUT NUMBER
    );

END DMT_MISC_RECEIPT_FBDI_GEN_PKG;
/
