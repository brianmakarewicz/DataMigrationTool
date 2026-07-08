-- PACKAGE BODY DMT_FND_VS_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_FND_VS_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_FND_VS_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_FND_VS_TRANSFORM_PKG';

    -- ============================================================
    -- TRANSFORM_SETS
    -- Inserts from STG to TFM for value set definitions.
    -- ============================================================
    PROCEDURE TRANSFORM_SETS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count      NUMBER := 0;
        l_fail_count    NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_SETS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_SETS');

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_FND_VS_SET_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_FND_VS_SET_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    SOURCE_GROUP_ID,
                    -- Business columns
                    VALUE_SET_CODE,
                    DESCRIPTION,
                    MODULE_ID,
                    VALIDATION_TYPE,
                    VALUE_DATA_TYPE,
                    MAXIMUM_SIZE,
                    FORMAT_TYPE,
                    PROTECTED_FLAG,
                    SECURITY_ENABLED_FLAG,
                    -- Pipeline columns
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    s.SOURCE_GROUP_ID,

                    s.VALUE_SET_CODE,
                    s.DESCRIPTION,
                    s.MODULE_ID,
                    s.VALIDATION_TYPE,
                    s.VALUE_DATA_TYPE,
                    s.MAXIMUM_SIZE,
                    s.FORMAT_TYPE,
                    s.PROTECTED_FLAG,
                    s.SECURITY_ENABLED_FLAG,

                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_FND_VS_SET_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_FND_VS_SET_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_FND_VS_SET_STG_TBL s
        SET    s.STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_FND_VS_SET_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_SETS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_SETS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_SETS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_SETS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_SETS;


    -- ============================================================
    -- TRANSFORM_VALUES
    -- Inserts from STG to TFM for value set values.
    -- ============================================================
    PROCEDURE TRANSFORM_VALUES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count      NUMBER := 0;
        l_fail_count    NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_VALUES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_VALUES');

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_FND_VS_VALUE_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_FND_VS_VALUE_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    SOURCE_GROUP_ID,
                    -- Business columns
                    VALUE_SET_CODE,
                    VALUE,
                    DESCRIPTION,
                    ENABLED_FLAG,
                    EFFECTIVE_START_DATE,
                    EFFECTIVE_END_DATE,
                    INDEPENDENT_VALUE,
                    TAG,
                    -- Pipeline columns
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    s.SOURCE_GROUP_ID,

                    s.VALUE_SET_CODE,
                    s.VALUE,
                    s.DESCRIPTION,
                    s.ENABLED_FLAG,
                    s.EFFECTIVE_START_DATE,
                    s.EFFECTIVE_END_DATE,
                    s.INDEPENDENT_VALUE,
                    s.TAG,

                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_FND_VS_VALUE_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_FND_VS_VALUE_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_FND_VS_VALUE_STG_TBL s
        SET    s.STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_FND_VS_VALUE_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_VALUES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_VALUES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_VALUES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_VALUES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_VALUES;

END DMT_FND_VS_TRANSFORM_PKG;
/
