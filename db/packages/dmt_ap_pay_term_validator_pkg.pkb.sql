-- PACKAGE BODY DMT_AP_PAY_TERM_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AP_PAY_TERM_VALIDATOR_PKG" 
AS
-- ============================================================
-- DMT_AP_PAY_TERM_VALIDATOR_PKG body
-- Payment Terms pre- and post-transform validation.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_AP_PAY_TERM_VALIDATOR_PKG';

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Upstream dependency check before transformation.
    -- Payment terms have no upstream dependencies — stub.
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
        UPDATE DMT_OWNER.DMT_AP_PAY_TERM_HDR_STG_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-SCOPE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — this table's SUB_OBJECT>>
                                   AND SUB_OBJECT = 'Payment Term Headers'
        -- <<END EDIT-SCOPE — nothing below this changes>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_AP_PAY_TERM_LINE_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Payment Term Lines'
        -- <<END EDIT-SCOPE>>
                                  );
    END FLAG_STG_FAILED;

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id   IN NUMBER,
        p_dependent_prefix IN VARCHAR2 DEFAULT NULL
    )
    IS
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM start. dep_prefix=' ||
                                NVL(p_dependent_prefix, '(none)'),
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

        -- No pre-transform validations implemented yet.
        -- Payment terms are standalone master data with no upstream dependencies.
        NULL;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM complete. No rules applied (stub).',
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
    -- Checks for orphan lines whose SOURCE_GROUP_ID does not
    -- match any header row in the same integration run.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
        l_orphan_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM start.',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_POST_TRANSFORM');

        UPDATE DMT_OWNER.DMT_AP_PAY_TERM_LINE_TFM_TBL ln
        SET    ln.TFM_STATUS        = 'FAILED',
               ln.ERROR_TEXT        = NVL2(ln.ERROR_TEXT,
                                         ln.ERROR_TEXT || ' | ',
                                         '')
                                     || '[POST_VALIDATION] Parent payment term header not found for SOURCE_GROUP_ID='
                                     || ln.SOURCE_GROUP_ID,
               ln.LAST_UPDATED_DATE = SYSDATE
        WHERE  ln.RUN_ID = p_run_id
        AND    ln.TFM_STATUS     = 'STAGED'
        AND    NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_AP_PAY_TERM_HDR_TFM_TBL h
            WHERE  h.RUN_ID  = p_run_id
            AND    h.SOURCE_GROUP_ID  = ln.SOURCE_GROUP_ID
            AND    h.TFM_STATUS       = 'STAGED'
        );

        l_orphan_count := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM complete. Orphan lines marked FAILED: '
                                || l_orphan_count,
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

END DMT_AP_PAY_TERM_VALIDATOR_PKG;
/
