-- PACKAGE BODY DMT_PAY_REL_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PAY_REL_TRANSFORM_PKG" 
AS
-- ============================================================
-- DMT_PAY_REL_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_PAY_REL_TRANSFORM_PKG';

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


    PROCEDURE TRANSFORM_PAYROLLRELATIONSHIPS (
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
            p_message        => 'TRANSFORM_PAYROLLRELATIONSHIPS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PAYROLLRELATIONSHIPS');

        l_prefix := get_prefix(p_run_id);

        -- PayrollRelationship
        INSERT INTO DMT_OWNER.DMT_PAY_REL_TFM_TBL (
            TFM_SEQUENCE_ID,
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            EFFECTIVE_START_DATE,
            EFFECTIVE_END_DATE,
            PERSON_NUMBER,
            LEGAL_EMPLOYER_NAME,
            PAYROLL_NAME,
            PAYROLL_RELATIONSHIP_NUMBER,
            PAYROLL_STATUS_CODE,
            LEGISLATIVE_DATA_GROUP_NAME,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            DMT_OWNER.DMT_PAY_REL_TFM_SEQ.NEXTVAL,
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            s.EFFECTIVE_START_DATE,
            s.EFFECTIVE_END_DATE,
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.PERSON_NUMBER, 30),
            s.LEGAL_EMPLOYER_NAME,
            s.PAYROLL_NAME,
            s.PAYROLL_RELATIONSHIP_NUMBER,
            s.PAYROLL_STATUS_CODE,
            s.LEGISLATIVE_DATA_GROUP_NAME,
            'STAGED',
            SYSDATE
        FROM DMT_OWNER.DMT_PAY_REL_STG_TBL s
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
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'Payroll Relationships'
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID)
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_PAY_REL_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := l_ok_count + SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_PAY_REL_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_OWNER.DMT_PAY_REL_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'Payroll Relationships'
            AND    e.STG_SEQUENCE_ID = STG_SEQUENCE_ID)
        AND (
            (p_run_mode = 'NEW' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PAYROLLRELATIONSHIPS complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PAYROLLRELATIONSHIPS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_PAYROLLRELATIONSHIPS failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_PAYROLLRELATIONSHIPS');
            RAISE;
    END TRANSFORM_PAYROLLRELATIONSHIPS;

END DMT_PAY_REL_TRANSFORM_PKG;
/
