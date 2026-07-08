-- PACKAGE BODY DMT_GRANTS_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GRANTS_VALIDATOR_PKG" 
AS
-- ============================================================
-- DMT_GRANTS_VALIDATOR_PKG body
-- Grants pre- and post-transform validation.
-- Upstream dependency: Projects must be LOADED.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_GRANTS_VALIDATOR_PKG';

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Check that referenced projects exist and are LOADED.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL
    )
    IS
        l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM start. Checking upstream project dependencies.',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

        -- Check award-project links: PROJECT_NUMBER must be LOADED in projects STG
        FOR r IN (
            SELECT DISTINCT s.STG_SEQUENCE_ID, s.PROJECT_NUMBER
            FROM   DMT_OWNER.DMT_GMS_AWD_PROJECTS_STG_TBL s
            WHERE  s.STATUS IN ('NEW', 'RETRY')
            AND    s.PROJECT_NUMBER IS NOT NULL
            AND    NOT EXISTS (
                SELECT 1
                FROM   DMT_OWNER.DMT_PJF_PROJECTS_STG_TBL p
                WHERE  p.PROJECT_NUMBER = NVL(p_dependent_prefix, '') || s.PROJECT_NUMBER
                AND    p.STATUS = 'LOADED')
        ) LOOP
            UPDATE DMT_OWNER.DMT_GMS_AWD_PROJECTS_STG_TBL
            SET    STATUS    = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[PRE_VALIDATION] Upstream error: Project ''' || r.PROJECT_NUMBER ||
                       ''' did not load successfully — record skipped.'),
                   LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_SEQUENCE_ID = r.STG_SEQUENCE_ID;
            l_fail_count := l_fail_count + 1;
        END LOOP;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM complete. Failed: ' || l_fail_count || '.',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_PRE_TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_PRE_TRANSFORM');
            RAISE;
    END VALIDATE_PRE_TRANSFORM;


    -- --------------------------------------------------------
    -- VALIDATE_POST_TRANSFORM
    -- Stub: no post-transform rules implemented yet.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM start. No rules implemented yet (stub).',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_POST_TRANSFORM');

        NULL;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM complete. No failures (stub).',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_POST_TRANSFORM');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_POST_TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_POST_TRANSFORM');
            RAISE;
    END VALIDATE_POST_TRANSFORM;

END DMT_GRANTS_VALIDATOR_PKG;
/
