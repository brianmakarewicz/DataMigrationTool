-- PACKAGE DMT_PERF_EVAL_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PERF_EVAL_HDL_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_PERF_EVAL_HDL_GEN_PKG
-- Generates the PerformanceDocument.dat HDL file from TFM staging records.
--
-- PerformanceDocument HDL is ONE zip containing ONE DAT file with 2 business object(s):
--   PerformanceDocument, PerformanceRating.
--
-- OBJECT_TYPE = 'PerformanceDocuments'.
-- ============================================================

    PROCEDURE GENERATE_HDL (
        p_run_id  IN  NUMBER,
        x_hdl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_csv_id          OUT NUMBER
    );

END DMT_PERF_EVAL_HDL_GEN_PKG;
/
