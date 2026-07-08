-- PACKAGE BODY DMT_EBS_ADAPTOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_EBS_ADAPTOR_PKG" AS
-- ============================================================
-- DMT_EBS_ADAPTOR_PKG Body
-- ============================================================

    FUNCTION STAGE_SUPPLIERS (
        p_source_system  IN VARCHAR2 DEFAULT 'EBS',
        p_vendor_id_from IN NUMBER   DEFAULT NULL,
        p_vendor_id_to   IN NUMBER   DEFAULT NULL
    ) RETURN NUMBER IS
        l_run_id NUMBER;
    BEGIN
        -- Create integration record
        l_run_id := DMT_OWNER.DMT_PIPELINE_RUN_SEQ.NEXTVAL;

        -- NOTE: In the new pipeline model, SUBMIT_PIPELINE creates the
        -- DMT_PIPELINE_RUN_TBL row. The adaptor only stages data.
        -- The run_id is passed in from the pipeline orchestrator.

        DMT_UTIL_PKG.LOG(l_run_id, 'EBS supplier extract started');

        -- TODO: query source EBS AP_SUPPLIERS and AP_SUPPLIER_SITES_ALL via DB link
        --       Map EBS columns to DMT canonical staging columns
        --       EBS source tables:
        --         AP_SUPPLIERS         -> DMT_POZ_SUPPLIERS_STG_TBL
        --         AP_SUPPLIER_SITES_ALL -> DMT_POZ_SUP_SITE_STG_TBL
        --         AP_SUPPLIER_CONTACTS  -> DMT_POZ_SUP_CONTACTS_STG_TBL

        COMMIT;
        DMT_UTIL_PKG.LOG(l_run_id, 'EBS supplier extract complete');
        RETURN l_run_id;
    END STAGE_SUPPLIERS;

END DMT_EBS_ADAPTOR_PKG;
/
