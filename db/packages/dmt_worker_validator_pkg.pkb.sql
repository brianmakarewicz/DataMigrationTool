-- PACKAGE BODY DMT_WORKER_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_WORKER_VALIDATOR_PKG"
AS
-- ============================================================
-- DMT_WORKER_VALIDATOR_PKG body
-- Worker HDL pre- and post-transform validation.
--
-- Accepted architecture (design section 7):
--   - Validation runs on STG rows (pre) / TFM rows (post).
--   - A failing row is tagged with STG_STATUS/TFM_STATUS = 'FAILED'
--     and its ERROR_TEXT gets an appended, prefixed message via
--     DMT_UTIL_PKG.APPEND_ERROR (accumulate, never overwrite).
--   - Never writes a staging status of 'LOADED'; never reads
--     STG_STATUS = 'LOADED'; no INSTR/SUBSTR parsing; no network.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_WORKER_VALIDATOR_PKG';

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Data-quality checks on the Worker STG rows before transform.
    -- Offline, structural rules only (no Fusion dependency lookups):
    --   R1  PERSON_NUMBER must be present (the HDL SourceSystemId /
    --       PersonNumber; a worker with no number cannot be loaded).
    --   R2  ACTION_CODE must be one of the supported new-hire actions
    --       (HIRE, ADD_CWK) -- an unknown action fails the HDL load.
    -- A failing row is set to STG_STATUS='FAILED' with an appended
    -- [PRE_VALIDATION] message; passing rows are left untouched (NEW).
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
        C_PROC CONSTANT VARCHAR2(30) := 'VALIDATE_PRE_TRANSFORM';
        l_bad  PLS_INTEGER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' start.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

        UPDATE DMT_OWNER.DMT_WORKER_STG_TBL w
        SET    w.STG_STATUS        = 'FAILED',
               w.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                   w.ERROR_TEXT,
                   '[PRE_VALIDATION] ' ||
                   CASE WHEN w.PERSON_NUMBER IS NULL
                        THEN 'PERSON_NUMBER is required.'
                        ELSE 'ACTION_CODE ' || w.ACTION_CODE ||
                             ' is not a supported worker action (HIRE, ADD_CWK).'
                   END),
               w.LAST_UPDATED_DATE = SYSDATE
        WHERE  w.STG_STATUS = 'NEW'
        AND (  w.PERSON_NUMBER IS NULL
            OR NVL(w.ACTION_CODE, 'X') NOT IN ('HIRE', 'ADD_CWK') );
        l_bad := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rows tagged FAILED: ' || l_bad,
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END VALIDATE_PRE_TRANSFORM;


    -- --------------------------------------------------------
    -- VALIDATE_POST_TRANSFORM
    -- Content checks on the Worker TFM rows for this run (after the
    -- prefix has been applied). Currently no post-transform rules are
    -- required for Workers -- the pre-transform structural checks plus
    -- the Fusion HDL load itself cover the known failure modes -- so
    -- this runs as a no-op that logs start/complete. Kept as a named
    -- entry point so the orchestration contract is stable.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
        C_PROC CONSTANT VARCHAR2(30) := 'VALIDATE_POST_TRANSFORM';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' start. (no post-transform rules for Workers)',
            p_package   => C_PKG,
            p_procedure => C_PROC);

        NULL;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END VALIDATE_POST_TRANSFORM;

END DMT_WORKER_VALIDATOR_PKG;
/
