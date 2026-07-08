-- PACKAGE BODY DMT_ASSIGNMENT_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_ASSIGNMENT_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_ASSIGNMENT_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_ASSIGNMENT_TRANSFORM_PKG';

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

    -- --------------------------------------------------------
    -- Private: read dependent prefix from CONVERSION_MASTER
    -- --------------------------------------------------------
    FUNCTION get_dep_prefix (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_dep_prefix VARCHAR2(30);
    BEGIN
        SELECT PREFIX
        INTO   l_dep_prefix
        FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;
        RETURN l_dep_prefix;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'RUN_ID ' || p_run_id || ' not found in DMT_PIPELINE_RUN_TBL');
    END get_dep_prefix;


    -- ============================================================
    -- TRANSFORM_WORK_RELS
    -- ============================================================
    PROCEDURE TRANSFORM_WORK_RELS (
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
            p_message        => 'TRANSFORM_WORK_RELS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_WORK_RELS');

        l_prefix := get_prefix(p_run_id);

        INSERT INTO DMT_OWNER.DMT_WORK_REL_TFM_TBL (
            TFM_SEQUENCE_ID,
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            EFFECTIVE_START_DATE,
            EFFECTIVE_END_DATE,
            PERSON_NUMBER,
            LEGAL_EMPLOYER_NAME,
            ACTION_CODE,
            WORKER_TYPE,
            DATE_START,
            PRIMARY_FLAG,
            STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            DMT_OWNER.DMT_WORK_REL_TFM_SEQ.NEXTVAL,
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            s.EFFECTIVE_START_DATE,
            s.EFFECTIVE_END_DATE,
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.PERSON_NUMBER, 30),
            s.LEGAL_EMPLOYER_NAME,
            s.ACTION_CODE,
            s.WORKER_TYPE,
            s.DATE_START,
            s.PRIMARY_FLAG,
            'STAGED',
            SYSDATE
        FROM DMT_OWNER.DMT_WORK_REL_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_WORK_REL_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_WORK_REL_STG_TBL
        SET    STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_OWNER.DMT_WORK_REL_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            (p_run_mode = 'NEW' AND STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_WORK_RELS complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_WORK_RELS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_WORK_RELS failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_WORK_RELS');
            RAISE;
    END TRANSFORM_WORK_RELS;


    -- ============================================================
    -- TRANSFORM_ASSIGNMENTS
    -- ============================================================
    PROCEDURE TRANSFORM_ASSIGNMENTS (
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
            p_message        => 'TRANSFORM_ASSIGNMENTS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_ASSIGNMENTS');

        l_prefix := get_prefix(p_run_id);

        INSERT INTO DMT_OWNER.DMT_ASSIGNMENT_TFM_TBL (
            TFM_SEQUENCE_ID,
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            EFFECTIVE_START_DATE,
            EFFECTIVE_END_DATE,
            PERSON_NUMBER,
            ASSIGNMENT_NAME,
            ASSIGNMENT_NUMBER,
            ASSIGNMENT_STATUS_TYPE_CODE,
            BUSINESS_UNIT_NAME,
            ACTION_CODE,
            JOB_CODE,
            GRADE_CODE,
            LOCATION_CODE,
            DEPARTMENT_NAME,
            POSITION_CODE,
            WORKER_CATEGORY,
            ASSIGNMENT_CATEGORY,
            FULL_PART_TIME,
            PERMANENT_TEMPORARY,
            NORMAL_HOURS,
            FREQUENCY,
            MANAGER_PERSON_NUMBER,
            MANAGER_ASSIGNMENT_NUMBER,
            PRIMARY_ASSIGNMENT_FLAG,
            STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            DMT_OWNER.DMT_ASSIGNMENT_TFM_SEQ.NEXTVAL,
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            s.EFFECTIVE_START_DATE,
            s.EFFECTIVE_END_DATE,
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.PERSON_NUMBER, 30),
            s.ASSIGNMENT_NAME,
            s.ASSIGNMENT_NUMBER,
            s.ASSIGNMENT_STATUS_TYPE_CODE,
            s.BUSINESS_UNIT_NAME,
            s.ACTION_CODE,
            s.JOB_CODE,
            s.GRADE_CODE,
            s.LOCATION_CODE,
            s.DEPARTMENT_NAME,
            s.POSITION_CODE,
            s.WORKER_CATEGORY,
            s.ASSIGNMENT_CATEGORY,
            s.FULL_PART_TIME,
            s.PERMANENT_TEMPORARY,
            s.NORMAL_HOURS,
            s.FREQUENCY,
            CASE WHEN s.MANAGER_PERSON_NUMBER IS NOT NULL
                 THEN DMT_UTIL_PKG.PREFIXED(l_prefix, s.MANAGER_PERSON_NUMBER, 30)
                 ELSE NULL
            END,
            s.MANAGER_ASSIGNMENT_NUMBER,
            s.PRIMARY_ASSIGNMENT_FLAG,
            'STAGED',
            SYSDATE
        FROM DMT_OWNER.DMT_ASSIGNMENT_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_ASSIGNMENT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_ASSIGNMENT_STG_TBL
        SET    STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_OWNER.DMT_ASSIGNMENT_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            (p_run_mode = 'NEW' AND STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_ASSIGNMENTS complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_ASSIGNMENTS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_ASSIGNMENTS failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_ASSIGNMENTS');
            RAISE;
    END TRANSFORM_ASSIGNMENTS;

END DMT_ASSIGNMENT_TRANSFORM_PKG;
/
