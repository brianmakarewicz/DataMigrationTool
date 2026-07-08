-- PACKAGE DMT_SALARY_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_SALARY_HDL_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_SALARY_HDL_GEN_PKG
-- Generates the Salary.dat HDL file from TFM staging records.
--
-- Salary HDL is ONE zip containing ONE DAT file with 1 business object:
--   Salary.
--
-- The business object section has a METADATA| header line followed
-- by MERGE| data lines (pipe-delimited).
--
-- The DAT CLOB is stored in DMT_FBDI_CSV_TBL.CSV_CONTENT (reusing
-- the table even though it is a DAT file). OBJECT_TYPE = 'Salaries'.
--
-- Column order in the METADATA line matches the HDL spec exactly.
-- NULLs are rendered as empty strings in pipe-delimited output.
-- Dates are formatted as YYYY/MM/DD.
--
-- SourceSystemOwner = 'DMT', SourceSystemId = PERSON_NUMBER.
-- ============================================================

    PROCEDURE GENERATE_HDL (
        p_run_id  IN  NUMBER,
        x_hdl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_csv_id          OUT NUMBER
    );

END DMT_SALARY_HDL_GEN_PKG;
/
