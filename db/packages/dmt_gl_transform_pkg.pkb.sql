-- PACKAGE BODY DMT_GL_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GL_TRANSFORM_PKG" AS

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_GL_TRANSFORM_PKG';

    FUNCTION get_prefix (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_prefix VARCHAR2(30);
    BEGIN
        SELECT PREFIX INTO l_prefix
        FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;
        RETURN l_prefix;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'RUN_ID ' || p_run_id || ' not found in DMT_PIPELINE_RUN_TBL');
    END get_prefix;

    PROCEDURE TRANSFORM (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix   VARCHAR2(30);
        l_ok       NUMBER := 0;
        l_fail     NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM');

        l_prefix := get_prefix(p_run_id);

        INSERT INTO DMT_OWNER.DMT_GL_INTERFACE_TFM_TBL (
            STG_SEQUENCE_ID, RUN_ID,
            JOURNAL_STATUS, LEDGER_NAME, ACCOUNTING_DATE, CURRENCY_CODE,
            DATE_CREATED, CREATED_BY, ACTUAL_FLAG,
            USER_JE_CATEGORY_NAME, USER_JE_SOURCE_NAME,
            CURRENCY_CONVERSION_DATE, USER_CURRENCY_CONVERSION_TYPE,
            CURRENCY_CONVERSION_RATE,
            SEGMENT1, SEGMENT2, SEGMENT3, SEGMENT4, SEGMENT5,
            SEGMENT6, SEGMENT7, SEGMENT8, SEGMENT9, SEGMENT10,
            SEGMENT11, SEGMENT12, SEGMENT13, SEGMENT14, SEGMENT15,
            SEGMENT16, SEGMENT17, SEGMENT18, SEGMENT19, SEGMENT20,
            SEGMENT21, SEGMENT22, SEGMENT23, SEGMENT24, SEGMENT25,
            SEGMENT26, SEGMENT27, SEGMENT28, SEGMENT29, SEGMENT30,
            ENTERED_DR, ENTERED_CR, ACCOUNTED_DR, ACCOUNTED_CR,
            REFERENCE1, REFERENCE2, REFERENCE4, REFERENCE5,
            REFERENCE6, REFERENCE7, REFERENCE8, REFERENCE10,
            STAT_AMOUNT, GROUP_ID, PERIOD_NAME,
            ATTRIBUTE_CATEGORY,
            ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5,
            ATTRIBUTE6, ATTRIBUTE7, ATTRIBUTE8, ATTRIBUTE9, ATTRIBUTE10,
            ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
            ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
            RECON_KEY,
            TFM_STATUS
        )
        SELECT
            s.STG_SEQUENCE_ID, p_run_id,
            s.JOURNAL_STATUS, s.LEDGER_NAME, s.ACCOUNTING_DATE, s.CURRENCY_CODE,
            NVL(s.DATE_CREATED, SYSDATE), NVL(s.CREATED_BY, 'DMT_MIGRATION'), s.ACTUAL_FLAG,
            s.USER_JE_CATEGORY_NAME, s.USER_JE_SOURCE_NAME,
            s.CURRENCY_CONVERSION_DATE, s.USER_CURRENCY_CONVERSION_TYPE,
            s.CURRENCY_CONVERSION_RATE,
            s.SEGMENT1, s.SEGMENT2, s.SEGMENT3, s.SEGMENT4, s.SEGMENT5,
            s.SEGMENT6, s.SEGMENT7, s.SEGMENT8, s.SEGMENT9, s.SEGMENT10,
            s.SEGMENT11, s.SEGMENT12, s.SEGMENT13, s.SEGMENT14, s.SEGMENT15,
            s.SEGMENT16, s.SEGMENT17, s.SEGMENT18, s.SEGMENT19, s.SEGMENT20,
            s.SEGMENT21, s.SEGMENT22, s.SEGMENT23, s.SEGMENT24, s.SEGMENT25,
            s.SEGMENT26, s.SEGMENT27, s.SEGMENT28, s.SEGMENT29, s.SEGMENT30,
            s.ENTERED_DR, s.ENTERED_CR, s.ACCOUNTED_DR, s.ACCOUNTED_CR,
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.REFERENCE1, 100), s.REFERENCE2, s.REFERENCE4, s.REFERENCE5,
            s.REFERENCE6, s.REFERENCE7, s.REFERENCE8, s.REFERENCE10,
            s.STAT_AMOUNT, p_run_id, s.PERIOD_NAME,  -- GROUP_ID = run_id (matches ParameterList)
            s.ATTRIBUTE_CATEGORY,
            s.ATTRIBUTE1, s.ATTRIBUTE2, s.ATTRIBUTE3, s.ATTRIBUTE4, s.ATTRIBUTE5,
            s.ATTRIBUTE6, s.ATTRIBUTE7, s.ATTRIBUTE8, s.ATTRIBUTE9, s.ATTRIBUTE10,
            s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
            s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
            -- Per-line reconciliation key -> GL_INTERFACE.REFERENCE21 ->
            -- GL_JE_LINES.REFERENCE_1 (the generator writes it; the reconciler
            -- matches base lines on it). Preserve a source-provided REFERENCE21
            -- if the staging row has one; only when the source leaves it null do
            -- we generate a prefix-scoped, per-line id.
            NVL(s.REFERENCE21, l_prefix || '-' || s.STG_SEQUENCE_ID),
            'STAGED'
        FROM   DMT_OWNER.DMT_GL_INTERFACE_STG_TBL s
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        -- Deterministic identity assignment: order the INSERT..SELECT by the
        -- STG PK so the TFM PK (GENERATED identity) is assigned in staging order.
        -- The generator emits rows ORDER BY TFM_SEQUENCE_ID, so this keeps the
        -- generated file's row order reproducible (byte-stable golden compare).
          AND NOT EXISTS (
              SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
              WHERE  e.RUN_ID = p_run_id
              AND    e.SUB_OBJECT = 'GL Journals'
              AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID)
        ORDER BY s.STG_SEQUENCE_ID;

        l_ok := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_GL_INTERFACE_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STG_STATUS IN ('NEW', 'RETRY'))
          )
        AND (p_scenario_id IS NULL
             OR SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL))
          AND NOT EXISTS (
              SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
              WHERE  e.RUN_ID = p_run_id
              AND    e.SUB_OBJECT = 'GL Journals'
              AND    e.STG_SEQUENCE_ID = STG_SEQUENCE_ID);

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM complete. Rows: ' || l_ok,
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

END DMT_GL_TRANSFORM_PKG;
/
