-- PACKAGE DMT_REQ_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_REQ_FBDI_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_REQ_FBDI_GEN_PKG
-- Generates the Requisitions FBDI zip from TFM staging records.
--
-- Requisition FBDI is ONE zip containing THREE CSVs.
-- All 3 CSVs share one ESS job submission (RequisitionImportJob).
--
-- CSV files (Oracle FBDI filenames):
--   PorReqHeadersInterface.csv     -> POR_REQ_HEADERS_INTERFACE_ALL
--   PorReqLinesInterface.csv       -> POR_REQ_LINES_INTERFACE_ALL
--   PorReqDistsInterface.csv       -> POR_REQ_DISTS_INTERFACE_ALL
--
-- Column order in each CSV must match the Fusion FBDI CTL file exactly.
-- No header row -- Oracle FBDI CSVs are data-only, position-based.
-- ============================================================

    PROCEDURE GENERATE_FBDI (
        p_run_id IN  NUMBER,
        x_fbdi_zip       OUT BLOB,
        x_filename       OUT VARCHAR2,
        x_fbdi_csv_id    OUT NUMBER,
        p_batch_id       IN  VARCHAR2 DEFAULT NULL   -- filters to one batch; NULL = all
    );

END DMT_REQ_FBDI_GEN_PKG;
/
