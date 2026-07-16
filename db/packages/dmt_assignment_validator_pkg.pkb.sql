-- PACKAGE BODY DMT_ASSIGNMENT_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_ASSIGNMENT_VALIDATOR_PKG" 
AS
-- ============================================================
-- DMT_ASSIGNMENT_VALIDATOR_PKG body
-- Worker Assignment HDL pre- and post-transform validation.
-- Stub — no rules implemented yet.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_ASSIGNMENT_VALIDATOR_PKG';

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Stub — no upstream dependency rules implemented yet.
    -- Future: check that referenced Workers exist and are LOADED.
    -- --------------------------------------------------------
    -- ============================================================
    -- FLAG_STG_FAILED — STANDARD helper (design §7). Marks every STG row FAILED
    -- (status only, no message) that has a DMT_STG_TFM_ERROR_TBL row for this run.
    -- The pre-validation checks above record WHY in the error table; this sets the
    -- STG status so FAILED-mode reruns select on it. Byte-identical across validator
    -- packages except the STG table name(s) and the SUB_OBJECT filter (tagged EDIT
    -- regions), like SWEEP_UNACCOUNTED. Does NOT commit — the caller owns the txn.
    -- ============================================================
    PROCEDURE FLAG_STG_FAILED (p_run_id IN NUMBER) IS
    BEGIN
        -- <<EDIT-TABLE — the object's STG table. Repeat this whole UPDATE block
        --   (EDIT-TABLE through the ';') once per STG table the object owns.>>
        UPDATE DMT_OWNER.DMT_WORK_REL_STG_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-SCOPE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — this table's SUB_OBJECT>>
                                   AND SUB_OBJECT = 'Work Relationships'
        -- <<END EDIT-SCOPE — nothing below this changes>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_ASSIGNMENT_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Assignments'
        -- <<END EDIT-SCOPE>>
                                  );
    END FLAG_STG_FAILED;

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM start. (stub — no rules)',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

        -- No pre-transform validations implemented yet.
        NULL;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM complete. (stub — no rules)',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');


        -- Standard final step: flag the STG rows FAILED from the recorded error
        -- rows (status only, no message) so FAILED-mode reruns select on them (§7).
        FLAG_STG_FAILED(p_run_id);
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
    -- Stub — no data quality rules implemented yet.
    -- Future: check ACTION_CODE valid, WORKER_TYPE E/C, dates logical, etc.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM start. (stub — no rules)',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_POST_TRANSFORM');

        -- No post-transform validations implemented yet.
        NULL;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM complete. (stub — no rules)',
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

END DMT_ASSIGNMENT_VALIDATOR_PKG;
/
