-- PACKAGE BODY DMT_AP_PAY_TERM_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AP_PAY_TERM_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_AP_PAY_TERM_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_AP_PAY_TERM_TRANSFORM_PKG';

    -- ============================================================
    -- TRANSFORM_HEADERS
    -- Inserts from STG to TFM for payment term headers.
    -- ============================================================
    PROCEDURE TRANSFORM_HEADERS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_HEADERS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_HEADERS');

        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_AP_PAY_TERM_HDR_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        INSERT INTO DMT_OWNER.DMT_AP_PAY_TERM_HDR_TFM_TBL (
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
                    s.NAME,
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
        FROM DMT_OWNER.DMT_AP_PAY_TERM_HDR_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_AP_PAY_TERM_HDR_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_AP_PAY_TERM_HDR_STG_TBL s
        SET    s.STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_AP_PAY_TERM_HDR_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_HEADERS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_HEADERS');

    EXCEPTION
        WHEN OTHERS THEN
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
            UPDATE DMT_OWNER.DMT_AP_PAY_TERM_LINE_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        INSERT INTO DMT_OWNER.DMT_AP_PAY_TERM_LINE_TFM_TBL (
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
        FROM DMT_OWNER.DMT_AP_PAY_TERM_LINE_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_AP_PAY_TERM_LINE_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_AP_PAY_TERM_LINE_STG_TBL s
        SET    s.STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_AP_PAY_TERM_LINE_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_LINES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_LINES');

    EXCEPTION
        WHEN OTHERS THEN
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
