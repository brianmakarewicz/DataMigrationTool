-- PACKAGE BODY DMT_INV_UOM_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_INV_UOM_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_INV_UOM_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_INV_UOM_TRANSFORM_PKG';

    PROCEDURE TRANSFORM (
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
            p_message        => 'TRANSFORM start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM');

        IF p_reprocess_errors THEN
            UPDATE DMT_INV_UOM_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

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

                    s.UOM_CODE,
                    s.UOM_CLASS,
                    s.UNIT_OF_MEASURE,
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
                AND    STG_STATUS IN ('NEW','TRANSFORMED');
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
