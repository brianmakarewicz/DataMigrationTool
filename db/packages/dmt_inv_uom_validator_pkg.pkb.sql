-- PACKAGE BODY DMT_INV_UOM_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_INV_UOM_VALIDATOR_PKG" AS
-- ============================================================
-- DMT_INV_UOM_VALIDATOR_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_INV_UOM_VALIDATOR_PKG';

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
        -- UOM is standalone master data with no upstream dependencies.
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

        -- Check UOM_CODE is not null
        UPDATE DMT_OWNER.DMT_INV_UOM_TFM_TBL
        SET    TFM_STATUS        = 'FAILED',
               ERROR_TEXT        = NVL2(ERROR_TEXT, ERROR_TEXT || ' | ', '')
                                   || '[POST_VALIDATION] UOM_CODE is required.',
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS     = 'STAGED'
        AND    UOM_CODE IS NULL;

        l_fail_count := l_fail_count + SQL%ROWCOUNT;

        -- Check UOM_CLASS is not null (only for rows still STAGED)
        UPDATE DMT_OWNER.DMT_INV_UOM_TFM_TBL
        SET    TFM_STATUS        = 'FAILED',
               ERROR_TEXT        = NVL2(ERROR_TEXT, ERROR_TEXT || ' | ', '')
                                   || '[POST_VALIDATION] UOM_CLASS is required.',
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS     = 'STAGED'
        AND    UOM_CLASS IS NULL;

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

END DMT_INV_UOM_VALIDATOR_PKG;
/
