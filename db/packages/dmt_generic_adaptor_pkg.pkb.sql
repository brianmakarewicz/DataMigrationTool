-- PACKAGE BODY DMT_GENERIC_ADAPTOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GENERIC_ADAPTOR_PKG" AS
-- ============================================================
-- DMT_GENERIC_ADAPTOR_PKG Body
-- ============================================================

    FUNCTION STAGE_SUPPLIERS_FROM_CSV (
        p_csv_data      IN CLOB,
        p_source_system IN VARCHAR2 DEFAULT 'GENERIC'
    ) RETURN NUMBER IS
        l_run_id NUMBER;
    BEGIN
        l_run_id := DMT_OWNER.DMT_PIPELINE_RUN_SEQ.NEXTVAL;

        -- NOTE: In the new pipeline model, SUBMIT_PIPELINE creates the
        -- DMT_PIPELINE_RUN_TBL row. The adaptor only stages data.
        -- The run_id is passed in from the pipeline orchestrator.

        DMT_UTIL_PKG.LOG(l_run_id, 'Generic CSV supplier staging started');

        -- TODO: parse p_csv_data line by line
        --       Validate header row against expected generic template columns
        --       Map generic columns -> DMT canonical staging columns
        --       Insert one row per data line into DMT_POZ_SUPPLIERS_STG_TBL
        --       Generic template format TBD — design for non-technical users

        COMMIT;
        DMT_UTIL_PKG.LOG(l_run_id, 'Generic CSV supplier staging complete');
        RETURN l_run_id;
    END STAGE_SUPPLIERS_FROM_CSV;

END DMT_GENERIC_ADAPTOR_PKG;
/
