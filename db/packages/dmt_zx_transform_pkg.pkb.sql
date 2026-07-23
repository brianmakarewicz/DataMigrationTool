-- PACKAGE BODY DMT_ZX_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_ZX_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_ZX_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_ZX_TRANSFORM_PKG';

    -- ============================================================
    -- TRANSFORM_REGIMES
    -- Inserts from STG to TFM for tax regimes.
    -- ============================================================
    PROCEDURE TRANSFORM_REGIMES (
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
            p_message        => 'TRANSFORM_REGIMES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_REGIMES');

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_ZX_REGIME_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_ZX_REGIME_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    SOURCE_GROUP_ID,
                    -- Business columns
                    TAX_REGIME_CODE,
                    TAX_REGIME_NAME,
                    DESCRIPTION,
                    EFFECTIVE_FROM,
                    EFFECTIVE_TO,
                    COUNTRY_CODE,
                    REGIME_TYPE_FLAG,
                    HAS_SUB_REGIME_FLAG,
                    PARENT_REGIME_CODE,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,
                    ATTRIBUTE2,
                    ATTRIBUTE3,
                    ATTRIBUTE4,
                    ATTRIBUTE5,
                    -- Pipeline columns
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    s.SOURCE_GROUP_ID,

                    s.TAX_REGIME_CODE,
                    s.TAX_REGIME_NAME,
                    s.DESCRIPTION,
                    s.EFFECTIVE_FROM,
                    s.EFFECTIVE_TO,
                    s.COUNTRY_CODE,
                    s.REGIME_TYPE_FLAG,
                    s.HAS_SUB_REGIME_FLAG,
                    s.PARENT_REGIME_CODE,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,
                    s.ATTRIBUTE2,
                    s.ATTRIBUTE3,
                    s.ATTRIBUTE4,
                    s.ATTRIBUTE5,

                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_ZX_REGIME_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'Tax Regimes'
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID)
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_ZX_REGIME_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_ZX_REGIME_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'Tax Regimes'
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID)
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_ZX_REGIME_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_REGIMES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_REGIMES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_REGIMES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_REGIMES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_REGIMES;


    -- ============================================================
    -- TRANSFORM_RATES
    -- Inserts from STG to TFM for tax rates.
    -- ============================================================
    PROCEDURE TRANSFORM_RATES (
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
            p_message        => 'TRANSFORM_RATES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_RATES');

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_ZX_RATE_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_OWNER.DMT_ZX_RATE_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    SOURCE_GROUP_ID,
                    -- Business columns
                    TAX_REGIME_CODE,
                    TAX,
                    TAX_STATUS_CODE,
                    TAX_RATE_CODE,
                    TAX_RATE_NAME,
                    RATE_TYPE_CODE,
                    PERCENTAGE_RATE,
                    EFFECTIVE_FROM,
                    EFFECTIVE_TO,
                    ACTIVE_FLAG,
                    DESCRIPTION,
                    DEFAULT_RATE_FLAG,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,
                    ATTRIBUTE2,
                    ATTRIBUTE3,
                    ATTRIBUTE4,
                    ATTRIBUTE5,
                    -- Pipeline columns
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    s.SOURCE_GROUP_ID,

                    s.TAX_REGIME_CODE,
                    s.TAX,
                    s.TAX_STATUS_CODE,
                    s.TAX_RATE_CODE,
                    s.TAX_RATE_NAME,
                    s.RATE_TYPE_CODE,
                    s.PERCENTAGE_RATE,
                    s.EFFECTIVE_FROM,
                    s.EFFECTIVE_TO,
                    s.ACTIVE_FLAG,
                    s.DESCRIPTION,
                    s.DEFAULT_RATE_FLAG,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,
                    s.ATTRIBUTE2,
                    s.ATTRIBUTE3,
                    s.ATTRIBUTE4,
                    s.ATTRIBUTE5,

                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_ZX_RATE_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'Tax Rates'
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID)
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_ZX_RATE_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_ZX_RATE_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'Tax Rates'
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID)
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_ZX_RATE_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_RATES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_RATES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_RATES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_RATES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_RATES;

END DMT_ZX_TRANSFORM_PKG;
/
