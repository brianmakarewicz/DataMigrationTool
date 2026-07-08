-- PACKAGE DMT_REPORT_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_REPORT_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_REPORT_PKG
-- Result reporting: integration summaries, error details, load outcomes
-- Designed to back APEX report regions directly
-- ============================================================

    TYPE t_integration_summary IS RECORD (
        run_id              NUMBER,
        pipeline_code       VARCHAR2(50),
        run_status          VARCHAR2(30),
        submitted_date      TIMESTAMP,
        completed_date      TIMESTAMP,
        cemli_sequence      VARCHAR2(4000),
        current_cemli       VARCHAR2(60),
        current_step        VARCHAR2(30),
        prefix              VARCHAR2(20),
        error_message       VARCHAR2(4000)
    );

    TYPE t_integration_summary_tab IS TABLE OF t_integration_summary;

    -- Return summary for a single integration run
    FUNCTION GET_INTEGRATION_SUMMARY (p_run_id IN NUMBER) RETURN t_integration_summary;

    -- Return error rows for an integration run (suppliers)
    -- Use as basis for APEX interactive report on invalid records
    PROCEDURE GET_SUPPLIER_ERRORS (
        p_run_id  IN  NUMBER,
        p_cursor          OUT SYS_REFCURSOR
    );

END DMT_REPORT_PKG;
/
