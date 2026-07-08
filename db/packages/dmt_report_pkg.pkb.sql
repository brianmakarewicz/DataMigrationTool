-- PACKAGE BODY DMT_REPORT_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_REPORT_PKG" AS
-- ============================================================
-- DMT_REPORT_PKG Body
-- ============================================================

    FUNCTION GET_INTEGRATION_SUMMARY (p_run_id IN NUMBER) RETURN t_integration_summary IS
        l_rec t_integration_summary;
    BEGIN
        SELECT RUN_ID, PIPELINE_CODES, RUN_STATUS,
               SUBMITTED_DATE, COMPLETED_DATE,
               CEMLI_SEQUENCE, CURRENT_CEMLI, CURRENT_STEP,
               PREFIX, ERROR_MESSAGE
        INTO   l_rec.run_id, l_rec.pipeline_code, l_rec.run_status,
               l_rec.submitted_date, l_rec.completed_date,
               l_rec.cemli_sequence, l_rec.current_cemli, l_rec.current_step,
               l_rec.prefix, l_rec.error_message
        FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;

        RETURN l_rec;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20020, 'Integration not found: ' || p_run_id);
    END GET_INTEGRATION_SUMMARY;

    -- --------------------------------------------------------
    PROCEDURE GET_SUPPLIER_ERRORS (
        p_run_id  IN  NUMBER,
        p_cursor          OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT s.STG_SEQUENCE_ID,
                   s.SOURCE_ID,
                   s.VENDOR_NAME,
                   s.SEGMENT1,
                   s.STATUS,
                   s.ERROR_TEXT,
                   s.STAGE_DATE
            FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL s
            WHERE  s.STATUS = 'FAILED'
            AND    s.STG_SEQUENCE_ID IN (
                SELECT t.STG_SEQUENCE_ID
                FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id)
            ORDER  BY s.STG_SEQUENCE_ID;
    END GET_SUPPLIER_ERRORS;

END DMT_REPORT_PKG;
/
