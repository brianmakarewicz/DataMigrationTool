-- PACKAGE BODY DMT_FND_VS_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_FND_VS_VALIDATOR_PKG" 
AS
-- ============================================================
-- DMT_FND_VS_VALIDATOR_PKG body
-- Value Set pre- and post-transform validation.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_FND_VS_VALIDATOR_PKG';

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Upstream dependency check before transformation.
    -- Value sets have no upstream dependencies — stub for now.
    -- --------------------------------------------------------
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
        -- Value sets are standalone master data with no upstream dependencies.
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

    -- --------------------------------------------------------
    -- VALIDATE_POST_TRANSFORM
    -- Data quality checks on TFM rows after transformation.
    -- Validates that every TFM value row has a corresponding
    -- TFM set row (matched on VALUE_SET_CODE within the same
    -- integration run). Orphan values are marked FAILED.
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

        -- Mark orphan value rows whose VALUE_SET_CODE has no matching set row
        UPDATE DMT_OWNER.DMT_FND_VS_VALUE_TFM_TBL v
        SET    v.TFM_STATUS        = 'FAILED',
               v.ERROR_TEXT        = NVL2(v.ERROR_TEXT,
                                        v.ERROR_TEXT || ' | ',
                                        '')
                                    || '[POST_VALIDATION] Parent value set not found for VALUE_SET_CODE='
                                    || v.VALUE_SET_CODE,
               v.LAST_UPDATED_DATE = SYSDATE
        WHERE  v.RUN_ID = p_run_id
        AND    v.TFM_STATUS     = 'STAGED'
        AND    NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_FND_VS_SET_TFM_TBL t
            WHERE  t.RUN_ID  = p_run_id
            AND    t.VALUE_SET_CODE  = v.VALUE_SET_CODE
            AND    t.TFM_STATUS      = 'STAGED'
        );

        l_orphan_count := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM complete. Orphan values marked FAILED: '
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

END DMT_FND_VS_VALIDATOR_PKG;
/
