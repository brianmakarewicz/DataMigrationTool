-- PACKAGE DMT_PO_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PO_FBDI_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_PO_FBDI_GEN_PKG
-- Generates the Purchase Orders FBDI zip from TFM staging records.
--
-- PO FBDI is ONE zip containing FOUR CSVs (unlike suppliers which
-- use 5 separate zips). All 4 CSVs share one ESS job submission.
--
-- Multi-BU support: when p_prc_bu_name is provided, only rows for
-- that Procurement BU are included. Each BU gets its own zip,
-- its own load, and its own import ESS job.
--
-- CSV files (Oracle FBDI filenames):
--   PoHeadersInterfaceOrder.csv        -> PO_HEADERS_INTERFACE
--   PoLinesInterfaceOrder.csv          -> PO_LINES_INTERFACE
--   PoLineLocationsInterfaceOrder.csv  -> PO_LINE_LOCATIONS_INTERFACE
--   PoDistributionsInterfaceOrder.csv  -> PO_DISTRIBUTIONS_INTERFACE
--
-- Column order in each CSV must match the Fusion FBDI CTL file exactly.
-- No header row -- Oracle FBDI CSVs are data-only, position-based.
-- ============================================================

    PROCEDURE GENERATE_FBDI (
        p_run_id IN  NUMBER,
        p_prc_bu_name    IN  VARCHAR2 DEFAULT NULL,
        x_fbdi_zip       OUT BLOB,
        x_filename       OUT VARCHAR2,
        x_fbdi_csv_id    OUT NUMBER
    );

END DMT_PO_FBDI_GEN_PKG;
/
