-- PACKAGE BODY DMT_AP_PAY_TERM_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AP_PAY_TERM_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_AP_PAY_TERM_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_AP_PAY_TERM_TRANSFORM_PKG';

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
    -- TRANSFORM_HEADERS
    -- Inserts from STG to TFM for payment term headers.
    -- ============================================================
    PROCEDURE TRANSFORM_HEADERS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
        l_prefix        VARCHAR2(30);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_HEADERS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_HEADERS');

        IF p_reprocess_errors THEN
            UPDATE DMT_AP_PAY_TERM_HDR_STG_TBL
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
        SELECT p_run_id, 'PaymentTerms', 'Payment Term Headers', s.STG_SEQUENCE_ID,
               '[TRANSFORM_ERROR] '
               || CASE WHEN LENGTH(l_prefix || s.NAME) > 50
                       THEN 'NAME "' || s.NAME || '" (' || LENGTH(l_prefix || s.NAME)
                            || ' chars with prefix, Fusion limit 50) ' END
               || 'cannot carry run prefix ' || l_prefix
               || ' (not truncated, to avoid a key collision).'
        FROM   DMT_AP_PAY_TERM_HDR_STG_TBL s
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND (LENGTH(l_prefix || s.NAME) > 50)
        AND NOT EXISTS (SELECT 1 FROM DMT_AP_PAY_TERM_HDR_TFM_TBL t
                        WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
        AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                        WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                        AND e.SUB_OBJECT = 'Payment Term Headers');
        l_fail_count := SQL%ROWCOUNT;
        UPDATE DMT_AP_PAY_TERM_HDR_STG_TBL
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Payment Term Headers')
        AND    STG_STATUS IN ('NEW','TRANSFORMED');

        INSERT INTO DMT_AP_PAY_TERM_HDR_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    SOURCE_GROUP_ID,
                    NAME,
                    DESCRIPTION,
                    ENABLED_FLAG,
                    START_DATE_ACTIVE,
                    END_DATE_ACTIVE,
                    PAY_TERM_TYPE,
                    CUTOFF_DAY,
                    RANK,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,
                    ATTRIBUTE2,
                    ATTRIBUTE3,
                    ATTRIBUTE4,
                    ATTRIBUTE5,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    s.SOURCE_GROUP_ID,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.NAME, 50),
                    s.DESCRIPTION,
                    s.ENABLED_FLAG,
                    s.START_DATE_ACTIVE,
                    s.END_DATE_ACTIVE,
                    s.PAY_TERM_TYPE,
                    s.CUTOFF_DAY,
                    s.RANK,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,
                    s.ATTRIBUTE2,
                    s.ATTRIBUTE3,
                    s.ATTRIBUTE4,
                    s.ATTRIBUTE5,
                    'STAGED',
                    SYSDATE
        FROM DMT_AP_PAY_TERM_HDR_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_AP_PAY_TERM_HDR_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND LENGTH(l_prefix || s.NAME) <= 50
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_AP_PAY_TERM_HDR_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND    EXISTS (
            SELECT 1 FROM DMT_AP_PAY_TERM_HDR_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_HEADERS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_HEADERS');

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
                SELECT p_run_id, 'PaymentTerms', 'Payment Term Headers', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_AP_PAY_TERM_HDR_STG_TBL s
                WHERE  (
                        DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
                        /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_AP_PAY_TERM_HDR_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Payment Term Headers');
                UPDATE DMT_AP_PAY_TERM_HDR_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Payment Term Headers')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
            EXCEPTION WHEN OTHERS THEN NULL;  -- fail-path diagnostics must never throw
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_HEADERS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_HEADERS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_HEADERS;

    -- ============================================================
    -- TRANSFORM_LINES
    -- Inserts from STG to TFM for payment term lines (installments).
    -- ============================================================
    PROCEDURE TRANSFORM_LINES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_LINES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_LINES');

        IF p_reprocess_errors THEN
            UPDATE DMT_AP_PAY_TERM_LINE_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED')
            AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                    OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
        END IF;

        INSERT INTO DMT_AP_PAY_TERM_LINE_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    SOURCE_GROUP_ID,
                    SEQUENCE_NUM,
                    DUE_PERCENT,
                    DUE_AMOUNT,
                    DUE_DAYS,
                    DUE_DATE,
                    DISCOUNT_PERCENT,
                    DISCOUNT_DAYS,
                    DISCOUNT_PERCENT_2,
                    DISCOUNT_DAYS_2,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    s.SOURCE_GROUP_ID,
                    s.SEQUENCE_NUM,
                    s.DUE_PERCENT,
                    s.DUE_AMOUNT,
                    s.DUE_DAYS,
                    s.DUE_DATE,
                    s.DISCOUNT_PERCENT,
                    s.DISCOUNT_DAYS,
                    s.DISCOUNT_PERCENT_2,
                    s.DISCOUNT_DAYS_2,
                    'STAGED',
                    SYSDATE
        FROM DMT_AP_PAY_TERM_LINE_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_AP_PAY_TERM_LINE_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_AP_PAY_TERM_LINE_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND    EXISTS (
            SELECT 1 FROM DMT_AP_PAY_TERM_LINE_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_LINES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_LINES');

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
                SELECT p_run_id, 'PaymentTerms', 'Payment Term Lines', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_AP_PAY_TERM_LINE_STG_TBL s
                WHERE  (
                        DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
                        /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_AP_PAY_TERM_LINE_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Payment Term Lines');
                UPDATE DMT_AP_PAY_TERM_LINE_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Payment Term Lines')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
            EXCEPTION WHEN OTHERS THEN NULL;  -- fail-path diagnostics must never throw
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_LINES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_LINES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_LINES;

END DMT_AP_PAY_TERM_TRANSFORM_PKG;
/
