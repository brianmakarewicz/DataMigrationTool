-- PACKAGE BODY DMT_GRANTS_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GRANTS_VALIDATOR_PKG" 
AS
-- ============================================================
-- DMT_GRANTS_VALIDATOR_PKG body
-- Grants pre- and post-transform validation.
-- Upstream dependency: Projects must be LOADED.
--
-- Pre-validation rejections are recorded in the run-stamped error table
-- DMT_OWNER.DMT_STG_TFM_ERROR_TBL (design §7); the STG rows keep their
-- status only (no message) and are flagged FAILED afterwards by the
-- standard FLAG_STG_FAILED helper. No validator writes ERROR_TEXT on a
-- *_STG_TBL row.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_GRANTS_VALIDATOR_PKG';

    -- ============================================================
    -- FLAG_STG_FAILED — STANDARD helper (design §7). Marks every STG row FAILED
    -- (status only, no message) that has a DMT_STG_TFM_ERROR_TBL row for this run.
    -- The pre-validation checks record WHY in the error table; this sets the STG
    -- status so FAILED-mode reruns select on it. Byte-identical across validator
    -- packages except the STG table name(s) and the SUB_OBJECT filter (tagged EDIT
    -- regions), like SWEEP_UNACCOUNTED. Does NOT commit — the caller owns the txn.
    -- ============================================================
    PROCEDURE FLAG_STG_FAILED (p_run_id IN NUMBER) IS
    BEGIN
        -- <<EDIT-TABLE — the object's STG table. Repeat this whole UPDATE block
        --   (EDIT-TABLE through the ';') once per STG table the object owns.>>
        UPDATE DMT_OWNER.DMT_GMS_AWD_PROJECTS_STG_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-SCOPE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — this table's SUB_OBJECT>>
                                   AND SUB_OBJECT = 'Award Projects'
        -- <<END EDIT-SCOPE — nothing below this changes>>
                                  );
    END FLAG_STG_FAILED;

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

        -- Check award-project links: PROJECT_NUMBER must be LOADED in projects.
        -- LOADED is a TFM-only status (STG never carries it, design §5): the source
        -- project must have a projects TFM row marked LOADED (joined 1:1 by
        -- STG_SEQUENCE_ID). Match the raw source PROJECT_NUMBER on the STG side.
        -- Rejections are recorded in the run-stamped error table; the STG row keeps
        -- its status only (no message), flagged FAILED later by FLAG_STG_FAILED (§7).
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT DISTINCT p_run_id, 'Grants', 'Award Projects', s.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Upstream error: Project ''' || s.PROJECT_NUMBER ||
               ''' did not load successfully — record skipped.'
        FROM   DMT_OWNER.DMT_GMS_AWD_PROJECTS_STG_TBL s
        WHERE  s.STG_STATUS IN ('NEW', 'RETRY')
        AND    s.PROJECT_NUMBER IS NOT NULL
        AND    NOT EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_PJF_PROJECTS_STG_TBL p
                   JOIN   DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL pt
                          ON pt.STG_SEQUENCE_ID = p.STG_SEQUENCE_ID
                   WHERE  p.PROJECT_NUMBER = s.PROJECT_NUMBER
                   AND    pt.TFM_STATUS = 'LOADED');
        l_fail_count := SQL%ROWCOUNT;

        -- Standard final step: flag the STG rows FAILED from the recorded error
        -- rows (status only, no message) so FAILED-mode reruns select on them (§7).
        FLAG_STG_FAILED(p_run_id);

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
