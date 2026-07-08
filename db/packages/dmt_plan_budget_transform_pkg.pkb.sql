-- PACKAGE BODY DMT_PLAN_BUDGET_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PLAN_BUDGET_TRANSFORM_PKG" AS

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_PLAN_BUDGET_TRANSFORM_PKG';

    PROCEDURE TRANSFORM (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM start.', C_PKG, 'TRANSFORM');

        INSERT INTO DMT_OWNER.DMT_PLAN_BUDGET_TFM_TBL (
            STG_SEQUENCE_ID, RUN_ID,
            SCENARIO, VERSION, ENTITY, ACCOUNT, PERIOD,
            AMOUNT, CURRENCY, DATA_LOAD_DEFINITION_NAME,
            ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5,
            STATUS
        )
        SELECT
            s.STG_SEQUENCE_ID, p_run_id,
            s.SCENARIO, s.VERSION, s.ENTITY, s.ACCOUNT, s.PERIOD,
            s.AMOUNT, s.CURRENCY, s.DATA_LOAD_DEFINITION_NAME,
            s.ATTRIBUTE1, s.ATTRIBUTE2, s.ATTRIBUTE3, s.ATTRIBUTE4, s.ATTRIBUTE5,
            'STAGED'
        FROM   DMT_OWNER.DMT_PLAN_BUDGET_STG_TBL s
        WHERE  (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        l_ok := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_PLAN_BUDGET_STG_TBL
        SET    STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STATUS IN ('NEW', 'RETRY'))
          )
        AND (p_scenario_id IS NULL
             OR SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));

        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM complete. Rows: ' || l_ok, C_PKG, 'TRANSFORM');
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'TRANSFORM failed.', SQLERRM, C_PKG, 'TRANSFORM');
            RAISE;
    END TRANSFORM;

END DMT_PLAN_BUDGET_TRANSFORM_PKG;
/
