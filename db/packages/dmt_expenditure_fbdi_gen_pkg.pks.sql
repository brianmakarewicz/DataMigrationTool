-- PACKAGE DMT_EXPENDITURE_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_EXPENDITURE_FBDI_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_EXPENDITURE_FBDI_GEN_PKG spec
-- Expenditures FBDI zip generation.
-- Single CSV: PjcTxnXfaceStageAll.csv
-- Spawn-per-partition: one submission per (USER_TRANSACTION_SOURCE, DOCUMENT_NAME)
-- group. p_txn_source / p_document scope the CSV + the GENERATED update to that
-- partition when set (a spawned child); both null = the whole run (parent /
-- standalone), mirroring the p_batch_id filter on DMT_EGP_ITEM_FBDI_GEN_PKG.
-- ============================================================
    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER,
        p_txn_source      IN  VARCHAR2 DEFAULT NULL,
        p_document        IN  VARCHAR2 DEFAULT NULL
    );
END DMT_EXPENDITURE_FBDI_GEN_PKG;
/
