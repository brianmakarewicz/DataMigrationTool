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
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM start.', 'INFO', C_PKG, 'TRANSFORM');

        INSERT INTO DMT_PLAN_BUDGET_TFM_TBL (
            STG_SEQUENCE_ID, RUN_ID,
            SCENARIO, VERSION, ENTITY, ACCOUNT, PERIOD,
            AMOUNT, CURRENCY, DATA_LOAD_DEFINITION_NAME,
            ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5,
            TFM_STATUS
        )
        SELECT
            s.STG_SEQUENCE_ID, p_run_id,
            s.SCENARIO, s.VERSION, s.ENTITY, s.ACCOUNT, s.PERIOD,
            s.AMOUNT, s.CURRENCY, s.DATA_LOAD_DEFINITION_NAME,
            s.ATTRIBUTE1, s.ATTRIBUTE2, s.ATTRIBUTE3, s.ATTRIBUTE4, s.ATTRIBUTE5,
            'STAGED'
        FROM   DMT_PLAN_BUDGET_STG_TBL s
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        l_ok := SQL%ROWCOUNT;

        UPDATE DMT_PLAN_BUDGET_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
          )
        AND (p_scenario_id IS NULL
             OR SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));

        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM complete. Rows: ' || l_ok, 'INFO', C_PKG, 'TRANSFORM');
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
                SELECT p_run_id, 'PlanningBudgets', 'Planning Budget Lines', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_PLAN_BUDGET_STG_TBL s
                WHERE  (
                        DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
                        /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
                      )
                AND (p_scenario_id IS NULL
                     OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_PLAN_BUDGET_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Planning Budget Lines');
                UPDATE DMT_PLAN_BUDGET_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Planning Budget Lines')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
            EXCEPTION WHEN OTHERS THEN NULL;  -- fail-path diagnostics must never throw
            END;
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'TRANSFORM failed.', SQLERRM, C_PKG, 'TRANSFORM');
            RAISE;
    END TRANSFORM;

END DMT_PLAN_BUDGET_TRANSFORM_PKG;
/
