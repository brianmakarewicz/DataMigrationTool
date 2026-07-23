-- PACKAGE BODY DMT_GL_CALENDAR_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GL_CALENDAR_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_GL_CALENDAR_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_GL_CALENDAR_TRANSFORM_PKG';

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

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_GL_CALENDAR_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM
        INSERT INTO DMT_OWNER.DMT_GL_CALENDAR_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    -- Business columns
                    PERIOD_SET_NAME,
                    PERIOD_NAME,
                    PERIOD_TYPE,
                    PERIOD_YEAR,
                    PERIOD_NUM,
                    QUARTER_NUM,
                    ENTERED_PERIOD_NAME,
                    START_DATE,
                    END_DATE,
                    YEAR_START_DATE,
                    QUARTER_START_DATE,
                    ADJUSTMENT_PERIOD_FLAG,
                    DESCRIPTION,
                    CONFIRMATION_STATUS,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,
                    ATTRIBUTE2,
                    ATTRIBUTE3,
                    ATTRIBUTE4,
                    ATTRIBUTE5,
                    ATTRIBUTE6,
                    ATTRIBUTE7,
                    ATTRIBUTE8,
                    -- Pipeline columns
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,

                    s.PERIOD_SET_NAME,
                    s.PERIOD_NAME,
                    s.PERIOD_TYPE,
                    s.PERIOD_YEAR,
                    s.PERIOD_NUM,
                    s.QUARTER_NUM,
                    s.ENTERED_PERIOD_NAME,
                    s.START_DATE,
                    s.END_DATE,
                    s.YEAR_START_DATE,
                    s.QUARTER_START_DATE,
                    s.ADJUSTMENT_PERIOD_FLAG,
                    s.DESCRIPTION,
                    s.CONFIRMATION_STATUS,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,
                    s.ATTRIBUTE2,
                    s.ATTRIBUTE3,
                    s.ATTRIBUTE4,
                    s.ATTRIBUTE5,
                    s.ATTRIBUTE6,
                    s.ATTRIBUTE7,
                    s.ATTRIBUTE8,

                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_GL_CALENDAR_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'GL Calendar'
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID)
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_GL_CALENDAR_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_OWNER.DMT_GL_CALENDAR_STG_TBL s
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
            AND    e.SUB_OBJECT = 'GL Calendar'
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID)
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_GL_CALENDAR_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM');
            RAISE;
    END TRANSFORM;

END DMT_GL_CALENDAR_TRANSFORM_PKG;
/
