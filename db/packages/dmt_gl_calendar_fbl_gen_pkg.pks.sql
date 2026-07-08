-- PACKAGE DMT_GL_CALENDAR_FBL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GL_CALENDAR_FBL_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_GL_CALENDAR_FBL_GEN_PKG
-- Generates pipe-delimited FBL file for GL Accounting Calendar.
-- ONE file in one zip: GlAccountingCalendar.csv
-- Pipe-delimited WITH headers (FBL pattern).
-- ============================================================

    PROCEDURE GENERATE_FBL (
        p_run_id  IN  NUMBER,
        x_fbl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );

END DMT_GL_CALENDAR_FBL_GEN_PKG;
/
