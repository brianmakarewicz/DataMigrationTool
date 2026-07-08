-- PACKAGE DMT_AP_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AP_FBDI_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AP_FBDI_GEN_PKG
-- Generates the AP Invoices FBDI zip from TFM staging records.
--
-- AP FBDI is ONE zip containing TWO CSVs:
--   ApInvoicesInterface.csv          -> AP_INVOICES_INTERFACE
--   ApInvoiceLinesInterface.csv      -> AP_INVOICE_LINES_INTERFACE
--
-- NO distributions CSV — distributions are auto-created by Fusion
-- from line-level data.
--
-- Grouped by OPERATING_UNIT: when p_operating_unit is non-NULL,
-- only includes rows for that operating unit. Each OU gets its own
-- zip, its own load, and its own import ESS job.
--
-- Column order in each CSV must match the Fusion FBDI CTL file exactly.
-- No header row — Oracle FBDI CSVs are data-only, position-based.
-- ============================================================

    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        p_operating_unit  IN  VARCHAR2 DEFAULT NULL,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );

END DMT_AP_FBDI_GEN_PKG;
/
