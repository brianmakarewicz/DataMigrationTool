-- PACKAGE BODY DMT_EGP_ITEM_CAT_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_EGP_ITEM_CAT_VALIDATOR_PKG" AS
-- ============================================================
-- DMT_EGP_ITEM_CAT_VALIDATOR_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_EGP_ITEM_CAT_VALIDATOR_PKG';

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
        UPDATE DMT_OWNER.DMT_EGP_ITEM_CAT_STG_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-SCOPE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — this table's SUB_OBJECT>>
                                   AND SUB_OBJECT = 'Item Categories'
        -- <<END EDIT-SCOPE — nothing below this changes>>
                                  );
    END FLAG_STG_FAILED;

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id   IN NUMBER,
        p_dependent_prefix IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM start. dep_prefix=' ||
                                NVL(p_dependent_prefix, '(none)'),
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

        -- No pre-transform validations implemented yet.
        -- Item category upstream dependency on Items can be added later.
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

    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    ) IS
        l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM start.',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_POST_TRANSFORM');

        -- Check ITEM_NUMBER is not null
        UPDATE DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL
        SET    TFM_STATUS        = 'FAILED',
               ERROR_TEXT        = NVL2(ERROR_TEXT, ERROR_TEXT || ' | ', '')
                                   || '[POST_VALIDATION] ITEM_NUMBER is required.',
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS     = 'STAGED'
        AND    ITEM_NUMBER IS NULL;

        l_fail_count := l_fail_count + SQL%ROWCOUNT;

        -- Check ORGANIZATION_CODE is not null
        UPDATE DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL
        SET    TFM_STATUS        = 'FAILED',
               ERROR_TEXT        = NVL2(ERROR_TEXT, ERROR_TEXT || ' | ', '')
                                   || '[POST_VALIDATION] ORGANIZATION_CODE is required.',
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS     = 'STAGED'
        AND    ORGANIZATION_CODE IS NULL;

        l_fail_count := l_fail_count + SQL%ROWCOUNT;

        -- Check CATEGORY_SET_NAME is not null
        UPDATE DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL
        SET    TFM_STATUS        = 'FAILED',
               ERROR_TEXT        = NVL2(ERROR_TEXT, ERROR_TEXT || ' | ', '')
                                   || '[POST_VALIDATION] CATEGORY_SET_NAME is required.',
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS     = 'STAGED'
        AND    CATEGORY_SET_NAME IS NULL;

        l_fail_count := l_fail_count + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM complete. Rows marked FAILED: '
                                || l_fail_count,
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

END DMT_EGP_ITEM_CAT_VALIDATOR_PKG;
/
