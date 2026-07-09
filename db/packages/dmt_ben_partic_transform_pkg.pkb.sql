-- PACKAGE BODY DMT_BEN_PARTIC_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BEN_PARTIC_TRANSFORM_PKG" 
AS
-- ============================================================
-- DMT_BEN_PARTIC_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_BEN_PARTIC_TRANSFORM_PKG';

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


    PROCEDURE TRANSFORM_PARTICIPANTENROLLMENTS (
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
            p_message        => 'TRANSFORM_PARTICIPANTENROLLMENTS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PARTICIPANTENROLLMENTS');

        l_prefix := get_prefix(p_run_id);

        -- ParticipantEnrollment
        INSERT INTO DMT_OWNER.DMT_BEN_PARTIC_TFM_TBL (
            TFM_SEQUENCE_ID,
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            PERSON_NUMBER,
            BENEFIT_RELATIONSHIP_NAME,
            PROGRAM_NAME,
            PLAN_NAME,
            OPTION_NAME,
            ORIGINAL_ENROLLMENT_DATE,
            ENROLLMENT_START_DATE,
            ENROLLMENT_END_DATE,
            ENROLLMENT_STATUS,
            LEGAL_EMPLOYER_NAME,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            DMT_OWNER.DMT_BEN_PARTIC_TFM_SEQ.NEXTVAL,
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.PERSON_NUMBER, 30),
            s.BENEFIT_RELATIONSHIP_NAME,
            s.PROGRAM_NAME,
            s.PLAN_NAME,
            s.OPTION_NAME,
            s.ORIGINAL_ENROLLMENT_DATE,
            s.ENROLLMENT_START_DATE,
            s.ENROLLMENT_END_DATE,
            s.ENROLLMENT_STATUS,
            s.LEGAL_EMPLOYER_NAME,
            'STAGED',
            SYSDATE
        FROM DMT_OWNER.DMT_BEN_PARTIC_STG_TBL s
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
            FROM   DMT_OWNER.DMT_BEN_PARTIC_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := l_ok_count + SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_BEN_PARTIC_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_OWNER.DMT_BEN_PARTIC_TFM_TBL
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
            p_message        => 'TRANSFORM_PARTICIPANTENROLLMENTS complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PARTICIPANTENROLLMENTS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_PARTICIPANTENROLLMENTS failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_PARTICIPANTENROLLMENTS');
            RAISE;
    END TRANSFORM_PARTICIPANTENROLLMENTS;

END DMT_BEN_PARTIC_TRANSFORM_PKG;
/
