-- PACKAGE DMT_GL_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GL_FBDI_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_GL_FBDI_GEN_PKG
-- Generates the GL Balances FBDI zip from TFM rows.
-- ONE zip containing ONE CSV: GlInterface.csv
-- Single submission (not grouped).
-- ============================================================
    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER,
        p_ledger_name     IN  VARCHAR2 DEFAULT NULL  -- NULL = all ledgers (backward compat)
    );
END DMT_GL_FBDI_GEN_PKG;
/
