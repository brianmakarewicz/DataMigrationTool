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

END DMT_MISC_RECEIPT_FBDI_GEN_PKG;
/
