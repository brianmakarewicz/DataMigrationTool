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
            UPDATE DMT_OWNER.DMT_INV_UOM_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        INSERT INTO DMT_OWNER.DMT_INV_UOM_TFM_TBL (
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
        FROM DMT_OWNER.DMT_INV_UOM_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_INV_UOM_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_INV_UOM_STG_TBL s
        SET    s.STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_INV_UOM_TFM_TBL t
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

END DMT_INV_UOM_TRANSFORM_PKG;
/
