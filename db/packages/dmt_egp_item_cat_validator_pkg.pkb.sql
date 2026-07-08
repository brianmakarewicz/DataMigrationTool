-- PACKAGE BODY DMT_EGP_ITEM_CAT_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_EGP_ITEM_CAT_VALIDATOR_PKG" AS
-- ============================================================
-- DMT_EGP_ITEM_CAT_VALIDATOR_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_EGP_ITEM_CAT_VALIDATOR_PKG';

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
