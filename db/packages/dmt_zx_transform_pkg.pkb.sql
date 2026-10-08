-- PACKAGE BODY DMT_ZX_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_ZX_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_ZX_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_ZX_TRANSFORM_PKG';

    -- --------------------------------------------------------
    -- Private: read run prefix from DMT_PIPELINE_RUN_TBL
    -- (same helper every prefixing transform carries).
    -- --------------------------------------------------------
    FUNCTION get_prefix (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_prefix VARCHAR2(30);
    BEGIN
        SELECT PREFIX
        INTO   l_prefix
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;
        RETURN l_prefix;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'RUN_ID ' || p_run_id || ' not found in DMT_PIPELINE_RUN_TBL');
    END get_prefix;

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
        l_prefix        VARCHAR2(30);

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_REGIMES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_REGIMES');

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_ZX_REGIME_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED')
            AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                    OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
        END IF;

        l_prefix := get_prefix(p_run_id);

        -- Run prefix on the user-facing unique key(s) (owner decision: config
        -- objects prefix keys exactly like Suppliers/Customers/Items). Prefix-fit
        -- guard: a key that cannot carry the full prefix within its Fusion limit
        -- is NOT truncated (a truncated key can collide). The row is recorded
        -- FAILED with a [TRANSFORM_ERROR] naming the limit and is excluded from
        -- the TFM insert below.
        INSERT INTO DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'TaxConfig', 'Tax Regimes', s.STG_SEQUENCE_ID,
               '[TRANSFORM_ERROR] '
               || CASE WHEN LENGTH(l_prefix || s.TAX_REGIME_CODE) > 30
                       THEN 'TAX_REGIME_CODE "' || s.TAX_REGIME_CODE || '" (' || LENGTH(l_prefix || s.TAX_REGIME_CODE)
                            || ' chars with prefix, Fusion limit 30) ' END
               || 'cannot carry run prefix ' || l_prefix
               || ' (not truncated, to avoid a key collision).'
        FROM   DMT_ZX_REGIME_STG_TBL s
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_ZX_REGIME_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND (LENGTH(l_prefix || s.TAX_REGIME_CODE) > 30)
        AND NOT EXISTS (SELECT 1 FROM DMT_ZX_REGIME_TFM_TBL t
                        WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
        AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                        WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                        AND e.SUB_OBJECT = 'Tax Regimes');
        l_fail_count := SQL%ROWCOUNT;
        UPDATE DMT_ZX_REGIME_STG_TBL
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Tax Regimes')
        AND    STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_ZX_REGIME_TFM_TBL (
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

                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.TAX_REGIME_CODE, 30),
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
        FROM DMT_ZX_REGIME_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_ZX_REGIME_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
            /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_ZX_REGIME_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND LENGTH(l_prefix || s.TAX_REGIME_CODE) <= 30
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_ZX_REGIME_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_ZX_REGIME_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
            /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
          )
        AND    EXISTS (
            SELECT 1 FROM DMT_ZX_REGIME_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_REGIMES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_REGIMES');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- record-detail anti-join surfaces them as FAILED instead of leaving
            -- the object unaccounted. SQLERRM captured to a local first (not a
            -- valid SQL identifier inside INSERT..SELECT). Backlog #14.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'TaxConfig', 'Tax Regimes', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_ZX_REGIME_STG_TBL s
                WHERE  (
                        DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_ZX_REGIME_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
                        /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
                      )
                AND (p_scenario_id IS NULL
                     OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_ZX_REGIME_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Tax Regimes');
                UPDATE DMT_ZX_REGIME_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Tax Regimes')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
            EXCEPTION WHEN OTHERS THEN NULL;  -- fail-path diagnostics must never throw
            END;
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
        l_prefix        VARCHAR2(30);

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_RATES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_RATES');

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_ZX_RATE_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED')
            AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                    OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
        END IF;

        l_prefix := get_prefix(p_run_id);

        -- Run prefix on the user-facing unique key(s) (owner decision: config
        -- objects prefix keys exactly like Suppliers/Customers/Items). Prefix-fit
        -- guard: a key that cannot carry the full prefix within its Fusion limit
        -- is NOT truncated (a truncated key can collide). The row is recorded
        -- FAILED with a [TRANSFORM_ERROR] naming the limit and is excluded from
        -- the TFM insert below.
        INSERT INTO DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'TaxConfig', 'Tax Rates', s.STG_SEQUENCE_ID,
               '[TRANSFORM_ERROR] '
               || CASE WHEN LENGTH(l_prefix || s.TAX_REGIME_CODE) > 30
                       THEN 'parent TAX_REGIME_CODE "' || s.TAX_REGIME_CODE || '" (' || LENGTH(l_prefix || s.TAX_REGIME_CODE)
                            || ' chars with prefix, Fusion limit 30) ' END
               || 'cannot carry run prefix ' || l_prefix
               || ' (not truncated, to avoid a key collision).'
        FROM   DMT_ZX_RATE_STG_TBL s
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_ZX_RATE_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND (LENGTH(l_prefix || s.TAX_REGIME_CODE) > 30)
        AND NOT EXISTS (SELECT 1 FROM DMT_ZX_RATE_TFM_TBL t
                        WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
        AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                        WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                        AND e.SUB_OBJECT = 'Tax Rates');
        l_fail_count := SQL%ROWCOUNT;
        UPDATE DMT_ZX_RATE_STG_TBL
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Tax Rates')
        AND    STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_ZX_RATE_TFM_TBL (
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

                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.TAX_REGIME_CODE, 30),
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
        FROM DMT_ZX_RATE_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_ZX_RATE_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
            /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_ZX_RATE_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND LENGTH(l_prefix || s.TAX_REGIME_CODE) <= 30
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_ZX_RATE_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_ZX_RATE_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
            /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
          )
        AND    EXISTS (
            SELECT 1 FROM DMT_ZX_RATE_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_RATES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_RATES');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- record-detail anti-join surfaces them as FAILED instead of leaving
            -- the object unaccounted. SQLERRM captured to a local first (not a
            -- valid SQL identifier inside INSERT..SELECT). Backlog #14.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'TaxConfig', 'Tax Rates', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_ZX_RATE_STG_TBL s
                WHERE  (
                        DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_ZX_RATE_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
                        /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
                      )
                AND (p_scenario_id IS NULL
                     OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_ZX_RATE_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Tax Rates');
                UPDATE DMT_ZX_RATE_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Tax Rates')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
            EXCEPTION WHEN OTHERS THEN NULL;  -- fail-path diagnostics must never throw
            END;
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
