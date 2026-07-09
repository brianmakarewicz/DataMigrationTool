-- PACKAGE BODY DMT_SALARY_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_SALARY_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_SALARY_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_SALARY_TRANSFORM_PKG';

    -- --------------------------------------------------------
    -- Private: read run prefix from CONVERSION_MASTER
    -- --------------------------------------------------------
    FUNCTION get_prefix (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_prefix VARCHAR2(30);
    BEGIN
        SELECT PREFIX
        INTO   l_prefix
        FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;
        RETURN l_prefix;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'RUN_ID ' || p_run_id || ' not found in DMT_PIPELINE_RUN_TBL');
    END get_prefix;


    -- ============================================================
    -- TRANSFORM_SALARIES
    -- ============================================================
    PROCEDURE TRANSFORM_SALARIES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix     VARCHAR2(30);
        l_ok_count   NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_SALARIES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_SALARIES');

        l_prefix := get_prefix(p_run_id);

        INSERT INTO DMT_OWNER.DMT_SALARY_TFM_TBL (
            TFM_SEQUENCE_ID,
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            EFFECTIVE_START_DATE,
            EFFECTIVE_END_DATE,
            PERSON_NUMBER,
            ASSIGNMENT_NUMBER,
            SALARY_AMOUNT,
            SALARY_BASIS_NAME,
            ANNUAL_SALARY,
            ANNUAL_FULL_TIME_SALARY,
            CURRENCY_CODE,
            ACTION_CODE,
            FREQUENCY_NAME,
            NEXT_SAL_REVIEW_DATE,
            DATE_FROM,
            DATE_TO,
            SALARY_APPROVED,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            DMT_OWNER.DMT_SALARY_TFM_SEQ.NEXTVAL,
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            s.EFFECTIVE_START_DATE,
            s.EFFECTIVE_END_DATE,
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.PERSON_NUMBER, 30),
            CASE WHEN s.ASSIGNMENT_NUMBER IS NOT NULL
                 THEN DMT_UTIL_PKG.PREFIXED(l_prefix, s.ASSIGNMENT_NUMBER, 80)
                 ELSE NULL
            END,
            s.SALARY_AMOUNT,
            s.SALARY_BASIS_NAME,
            s.ANNUAL_SALARY,
            s.ANNUAL_FULL_TIME_SALARY,
            s.CURRENCY_CODE,
            s.ACTION_CODE,
            s.FREQUENCY_NAME,
            s.NEXT_SAL_REVIEW_DATE,
            s.DATE_FROM,
            s.DATE_TO,
            s.SALARY_APPROVED,
            'STAGED',
            SYSDATE
        FROM DMT_OWNER.DMT_SALARY_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_SALARY_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_SALARY_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_OWNER.DMT_SALARY_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            (p_run_mode = 'NEW' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_SALARIES complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_SALARIES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_SALARIES failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_SALARIES');
            RAISE;
    END TRANSFORM_SALARIES;

END DMT_SALARY_TRANSFORM_PKG;
/
