-- PACKAGE BODY DMT_INV_UOM_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_INV_UOM_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_INV_UOM_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_INV_UOM_TRANSFORM_PKG';

    -- Fusion field limit for the UOM name (unitsOfMeasure REST describe: UOM
    -- maxLength 25; the TFM column is the same width).
    C_UOM_NAME_MAX CONSTANT PLS_INTEGER := 25;

    -- Run-prefix derivation for the 3-char UOM code (see the spec header).
    C_UOM_LEAD  CONSTANT VARCHAR2(8)  := '12345679';
    C_UOM_SLOTS CONSTANT PLS_INTEGER  := 4;
    C_B36       CONSTANT VARCHAR2(36) := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

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

    -- --------------------------------------------------------
    -- DERIVE_UOM_CODE -- see the spec for the documented derivation.
    -- --------------------------------------------------------
    FUNCTION DERIVE_UOM_CODE (
        p_prefix      IN VARCHAR2,
        p_ordinal     IN NUMBER,
        p_source_code IN VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC IS
        l_space CONSTANT PLS_INTEGER := LENGTH(C_UOM_LEAD) * 1296;
        l_n     PLS_INTEGER;
    BEGIN
        IF p_prefix IS NULL OR p_source_code IS NULL THEN
            RETURN p_source_code;   -- production cutover: no prefix, code as-is
        END IF;
        l_n := MOD(TO_NUMBER(p_prefix) * C_UOM_SLOTS + (p_ordinal - 1), l_space);
        RETURN SUBSTR(C_UOM_LEAD, TRUNC(l_n / 1296) + 1, 1)
            || SUBSTR(C_B36, TRUNC(MOD(l_n, 1296) / 36) + 1, 1)
            || SUBSTR(C_B36, MOD(l_n, 36) + 1, 1);
    END DERIVE_UOM_CODE;

    PROCEDURE TRANSFORM (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
        l_prefix     VARCHAR2(30);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM');

        l_prefix := get_prefix(p_run_id);

        IF p_reprocess_errors THEN
            UPDATE DMT_INV_UOM_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED')
            AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                    OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
        END IF;

        -- Prefix-fit guard: a UOM name that cannot carry the full run prefix
        -- within the Fusion limit is NOT truncated (truncation could collide
        -- two names). The row is recorded FAILED with a [TRANSFORM_ERROR]
        -- naming the limit, and is excluded from the TFM insert below.
        INSERT INTO DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'UnitsOfMeasure', 'Units of Measure', s.STG_SEQUENCE_ID,
               '[TRANSFORM_ERROR] UNIT_OF_MEASURE "' || s.UNIT_OF_MEASURE
               || '" cannot carry run prefix ' || l_prefix || ': '
               || LENGTH(l_prefix || s.UNIT_OF_MEASURE) || ' chars exceeds the Fusion limit of '
               || C_UOM_NAME_MAX || ' (not truncated, to avoid a key collision).'
        FROM   DMT_INV_UOM_STG_TBL s
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND LENGTH(l_prefix || s.UNIT_OF_MEASURE) > C_UOM_NAME_MAX
        AND NOT EXISTS (SELECT 1 FROM DMT_INV_UOM_TFM_TBL t
                        WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
        AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                        WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                        AND e.SUB_OBJECT = 'Units of Measure');
        l_fail_count := SQL%ROWCOUNT;
        UPDATE DMT_INV_UOM_STG_TBL
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Units of Measure')
        AND    STG_STATUS IN ('NEW','TRANSFORMED');

        INSERT INTO DMT_INV_UOM_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    -- Business columns
                    UOM_CODE,
                    UOM_CLASS,
                    UNIT_OF_MEASURE,
                    DESCRIPTION,
                    BASE_UOM_FLAG,
                    DISABLE_DATE,
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

                    -- Run prefix on the user-facing unique keys (owner decision,
                    -- like Suppliers/Customers/Items): the 3-char code gets the
                    -- documented deterministic derivation; the name gets the full
                    -- prefix (fit guaranteed by the guard above). The reconciler
                    -- matches the base table on this same TFM UOM_CODE.
                    DMT_INV_UOM_TRANSFORM_PKG.DERIVE_UOM_CODE(l_prefix,
                        ROW_NUMBER() OVER (ORDER BY s.STG_SEQUENCE_ID),
                        s.UOM_CODE),
                    s.UOM_CLASS,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.UNIT_OF_MEASURE, C_UOM_NAME_MAX),
                    s.DESCRIPTION,
                    s.BASE_UOM_FLAG,
                    s.DISABLE_DATE,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,
                    s.ATTRIBUTE2,
                    s.ATTRIBUTE3,
                    s.ATTRIBUTE4,
                    s.ATTRIBUTE5,

                    'STAGED',
                    SYSDATE
        FROM DMT_INV_UOM_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_INV_UOM_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND LENGTH(l_prefix || s.UNIT_OF_MEASURE) <= C_UOM_NAME_MAX
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_INV_UOM_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND    EXISTS (
            SELECT 1 FROM DMT_INV_UOM_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM');

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
                SELECT p_run_id, 'UnitsOfMeasure', 'Units of Measure', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_INV_UOM_STG_TBL s
                WHERE  (
                        DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
                        /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL
                     OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_INV_UOM_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Units of Measure');
                UPDATE DMT_INV_UOM_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Units of Measure')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
            EXCEPTION WHEN OTHERS THEN NULL;  -- fail-path diagnostics must never throw
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM');
            RAISE;
    END TRANSFORM;

END DMT_INV_UOM_TRANSFORM_PKG;
/
