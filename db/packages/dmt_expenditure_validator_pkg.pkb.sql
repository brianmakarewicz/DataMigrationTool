-- PACKAGE BODY DMT_EXPENDITURE_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_EXPENDITURE_VALIDATOR_PKG" 
AS
-- ============================================================
-- DMT_EXPENDITURE_VALIDATOR_PKG body
-- Expenditures pre- and post-transform validation.
-- Upstream dependency: PROJECT_NUMBER must be LOADED in projects STG.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_EXPENDITURE_VALIDATOR_PKG';

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Upstream dependency: PROJECT_NUMBER must match a LOADED project.
    -- For migrated projects: NVL(dep_prefix,'') || exp.PROJECT_NUMBER
    --   must exist in DMT_PJF_PROJECTS_STG_TBL with STG_STATUS='LOADED'.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL
    )
    IS
        l_dep_prefix   VARCHAR2(30);
        l_failed       NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM start. dep_prefix=' ||
                                NVL(p_dependent_prefix, '(from CONVERSION_MASTER)'),
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

        -- Resolve dependent prefix
        IF p_dependent_prefix IS NOT NULL THEN
            l_dep_prefix := p_dependent_prefix;
        ELSE
            SELECT PREFIX
            INTO   l_dep_prefix
            FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
            WHERE  RUN_ID = p_run_id;
        END IF;

        -- Check PROJECT_NUMBER upstream dependency.
        -- Only enforced when projects have been migrated (at least one LOADED row exists).
        DECLARE
            l_any_loaded NUMBER;
        BEGIN
            -- LOADED is a TFM-only status (STG never carries it, design §5), so the
            -- "have projects migrated?" gate reads the projects TFM table.
            SELECT COUNT(*) INTO l_any_loaded
            FROM   DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
            WHERE  TFM_STATUS = 'LOADED' AND ROWNUM = 1;

            IF l_any_loaded > 0 THEN
                UPDATE DMT_OWNER.DMT_PJC_EXPENDITURES_STG_TBL e
                SET    STG_STATUS            = 'FAILED',
                       ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                               ERROR_TEXT,
                                               '[PRE_VALIDATION] Project ''' ||
                                               e.PROJECT_NUMBER ||
                                               ''' is not loaded — expenditure record skipped.'),
                       LAST_UPDATED_DATE = SYSDATE
                WHERE  e.STG_STATUS IN ('NEW', 'RETRY')
                AND    e.PROJECT_NUMBER IS NOT NULL
                AND    NOT EXISTS (
                           SELECT 1
                           FROM   DMT_OWNER.DMT_PJF_PROJECTS_STG_TBL p
                           JOIN   DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL pt
                                  ON pt.STG_SEQUENCE_ID = p.STG_SEQUENCE_ID
                           WHERE  p.PROJECT_NUMBER = e.PROJECT_NUMBER
                           AND    pt.TFM_STATUS    = 'LOADED'
                       );
                l_failed := SQL%ROWCOUNT;
            END IF;
        END;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM complete. Pre-validation failures: ' || l_failed,
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
    -- Future: check EXPENDITURE_ITEM_DATE not future, required fields, etc.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
    BEGIN
        -- No post-transform validations implemented yet.
        NULL;
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

END DMT_EXPENDITURE_VALIDATOR_PKG;
/
