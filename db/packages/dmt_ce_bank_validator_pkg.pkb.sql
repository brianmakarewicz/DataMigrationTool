-- PACKAGE BODY DMT_CE_BANK_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CE_BANK_VALIDATOR_PKG" 
AS
-- ============================================================
-- DMT_CE_BANK_VALIDATOR_PKG body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_CE_BANK_VALIDATOR_PKG';

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Banks are standalone master data — stub.
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
        UPDATE DMT_OWNER.DMT_CE_BANK_STG_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-SCOPE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — this table's SUB_OBJECT>>
                                   AND SUB_OBJECT = 'Banks'
        -- <<END EDIT-SCOPE — nothing below this changes>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_CE_BRANCH_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Bank Branches'
        -- <<END EDIT-SCOPE>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_CE_BANK_ACCT_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Bank Accounts'
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
    -- Two checks:
    --   1. Orphan branches: SOURCE_GROUP_ID not in any bank
    --   2. Orphan accounts: SOURCE_LINE_ID not in any branch
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
        l_orphan_branches NUMBER := 0;
        l_orphan_accounts NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM start.',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_POST_TRANSFORM');

        -- Check 1: Orphan branches (SOURCE_GROUP_ID must match a bank)
        UPDATE DMT_OWNER.DMT_CE_BRANCH_TFM_TBL br
        SET    br.TFM_STATUS        = 'FAILED',
               br.ERROR_TEXT        = NVL2(br.ERROR_TEXT,
                                         br.ERROR_TEXT || ' | ',
                                         '')
                                     || '[POST_VALIDATION] Parent bank not found for SOURCE_GROUP_ID='
                                     || br.SOURCE_GROUP_ID,
               br.LAST_UPDATED_DATE = SYSDATE
        WHERE  br.RUN_ID = p_run_id
        AND    br.TFM_STATUS     = 'STAGED'
        AND    NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_CE_BANK_TFM_TBL bk
            WHERE  bk.RUN_ID  = p_run_id
            AND    bk.SOURCE_GROUP_ID  = br.SOURCE_GROUP_ID
            AND    bk.TFM_STATUS       = 'STAGED'
        );

        l_orphan_branches := SQL%ROWCOUNT;

        -- Check 2: Orphan accounts (SOURCE_LINE_ID must match a branch SOURCE_LINE_ID)
        UPDATE DMT_OWNER.DMT_CE_BANK_ACCT_TFM_TBL acct
        SET    acct.TFM_STATUS        = 'FAILED',
               acct.ERROR_TEXT        = NVL2(acct.ERROR_TEXT,
                                            acct.ERROR_TEXT || ' | ',
                                            '')
                                       || '[POST_VALIDATION] Parent branch not found for SOURCE_LINE_ID='
                                       || acct.SOURCE_LINE_ID,
               acct.LAST_UPDATED_DATE = SYSDATE
        WHERE  acct.RUN_ID = p_run_id
        AND    acct.TFM_STATUS     = 'STAGED'
        AND    NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_CE_BRANCH_TFM_TBL br
            WHERE  br.RUN_ID = p_run_id
            AND    br.SOURCE_LINE_ID  = acct.SOURCE_LINE_ID
            AND    br.TFM_STATUS      = 'STAGED'
        );

        l_orphan_accounts := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM complete. Orphan branches: '
                                || l_orphan_branches || ', Orphan accounts: '
                                || l_orphan_accounts,
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

END DMT_CE_BANK_VALIDATOR_PKG;
/
