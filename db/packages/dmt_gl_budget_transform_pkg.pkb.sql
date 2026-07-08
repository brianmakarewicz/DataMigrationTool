-- PACKAGE BODY DMT_GL_BUDGET_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GL_BUDGET_TRANSFORM_PKG" AS

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_GL_BUDGET_TRANSFORM_PKG';

    PROCEDURE TRANSFORM (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM start.', C_PKG, 'TRANSFORM');

        INSERT INTO DMT_OWNER.DMT_GL_BUDGET_INT_TFM_TBL (
            STG_SEQUENCE_ID, RUN_ID,
            RUN_NAME, STATUS_FBDI, LEDGER_ID,
            BUDGET_NAME, PERIOD_NAME, CURRENCY_CODE,
            SEGMENT1, SEGMENT2, SEGMENT3, SEGMENT4, SEGMENT5,
            SEGMENT6, SEGMENT7, SEGMENT8, SEGMENT9, SEGMENT10,
            SEGMENT11, SEGMENT12, SEGMENT13, SEGMENT14, SEGMENT15,
            SEGMENT16, SEGMENT17, SEGMENT18, SEGMENT19, SEGMENT20,
            SEGMENT21, SEGMENT22, SEGMENT23, SEGMENT24, SEGMENT25,
            SEGMENT26, SEGMENT27, SEGMENT28, SEGMENT29, SEGMENT30,
            BUDGET_AMOUNT, LEDGER_NAME,
            TFM_STATUS
        )
        SELECT
            s.STG_SEQUENCE_ID, p_run_id,
            -- RUN_NAME: use STG value if provided, otherwise derive from run_id
            NVL(s.RUN_NAME, 'DMT_' || TO_CHAR(p_run_id)),
            -- STATUS_FBDI: Fusion expects 'NEW' for new budget data; honor STG override if set
            NVL(s.JOURNAL_STATUS, 'NEW'),
            -- LEDGER_ID: pass through from STG (user may supply LEDGER_ID or LEDGER_NAME)
            s.LEDGER_ID,
            s.BUDGET_NAME, s.PERIOD_NAME, s.CURRENCY_CODE,
            s.SEGMENT1, s.SEGMENT2, s.SEGMENT3, s.SEGMENT4, s.SEGMENT5,
            s.SEGMENT6, s.SEGMENT7, s.SEGMENT8, s.SEGMENT9, s.SEGMENT10,
            s.SEGMENT11, s.SEGMENT12, s.SEGMENT13, s.SEGMENT14, s.SEGMENT15,
            s.SEGMENT16, s.SEGMENT17, s.SEGMENT18, s.SEGMENT19, s.SEGMENT20,
            s.SEGMENT21, s.SEGMENT22, s.SEGMENT23, s.SEGMENT24, s.SEGMENT25,
            s.SEGMENT26, s.SEGMENT27, s.SEGMENT28, s.SEGMENT29, s.SEGMENT30,
            s.BUDGET_AMOUNT, s.LEDGER_NAME,
            'STAGED'
        FROM   DMT_OWNER.DMT_GL_BUDGET_INT_STG_TBL s
        WHERE  (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        l_ok := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_GL_BUDGET_INT_STG_TBL
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

END DMT_GL_BUDGET_TRANSFORM_PKG;
/
