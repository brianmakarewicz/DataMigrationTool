-- PACKAGE BODY DMT_POZ_SUP_SITE_ASSN_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_SITE_ASSN_VALIDATOR_PKG" AS
-- Stub: no validation rules yet. Promotes STAGED -> VALIDATED.
-- Add validation rules here without changing the orchestration flow.

    PROCEDURE VALIDATE_BATCH (p_run_id IN NUMBER) IS
        l_valid NUMBER := 0;
        l_invalid NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            'VALIDATE_BATCH start (stub -- all records passed through).',
            'INFO', 'DMT_POZ_SUP_SITE_ASSN_VALIDATOR_PKG', 'VALIDATE_BATCH');

        UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_STG_TBL
        SET    STATUS = 'VALIDATED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STATUS = 'NEW';
        l_valid := SQL%ROWCOUNT;

        SELECT COUNT(*) INTO l_invalid
        FROM   DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_STG_TBL
        WHERE  STATUS = 'INVALID';

        DMT_UTIL_PKG.LOG(p_run_id,
            'VALIDATE_BATCH complete. Valid: ' || l_valid || ' | Invalid: ' || l_invalid,
            'INFO', 'DMT_POZ_SUP_SITE_ASSN_VALIDATOR_PKG', 'VALIDATE_BATCH');
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'VALIDATE_BATCH failed.', SQLERRM,
                'DMT_POZ_SUP_SITE_ASSN_VALIDATOR_PKG', 'VALIDATE_BATCH');
            RAISE;
    END VALIDATE_BATCH;

END DMT_POZ_SUP_SITE_ASSN_VALIDATOR_PKG;
/
