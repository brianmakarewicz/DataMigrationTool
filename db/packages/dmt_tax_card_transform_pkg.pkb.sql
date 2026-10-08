-- PACKAGE BODY DMT_TAX_CARD_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_TAX_CARD_TRANSFORM_PKG" 
AS
-- ============================================================
-- DMT_TAX_CARD_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_TAX_CARD_TRANSFORM_PKG';

    FUNCTION get_prefix (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_prefix VARCHAR2(30);
    BEGIN
        SELECT PREFIX
        INTO   l_prefix
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;
        RETURN l_prefix;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'RUN_ID ' || p_run_id || ' not found in DMT_PIPELINE_RUN_TBL');
    END get_prefix;


    PROCEDURE TRANSFORM_TAXCARDS (
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
            p_message        => 'TRANSFORM_TAXCARDS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_TAXCARDS');

        l_prefix := get_prefix(p_run_id);

        -- CalculationCard
        INSERT INTO DMT_TAX_CARD_TFM_TBL (
            TFM_SEQUENCE_ID,
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            EFFECTIVE_START_DATE,
            EFFECTIVE_END_DATE,
            PERSON_NUMBER,
            LEGISLATIVE_DATA_GROUP_NAME,
            DIRECTIVE_CARD_NAME,
            TAX_REPORTING_UNIT,
            COMPONENT_GROUP_NAME,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            DMT_TAX_CARD_TFM_SEQ.NEXTVAL,
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            s.EFFECTIVE_START_DATE,
            s.EFFECTIVE_END_DATE,
            DMT_XREF_PKG.PERSON_NUMBER(s.PERSON_NUMBER),
            s.LEGISLATIVE_DATA_GROUP_NAME,
            s.DIRECTIVE_CARD_NAME,
            s.TAX_REPORTING_UNIT,
            s.COMPONENT_GROUP_NAME,
            'STAGED',
            SYSDATE
        FROM DMT_TAX_CARD_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_TAX_CARD_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
            /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_TAX_CARD_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := l_ok_count + SQL%ROWCOUNT;

        UPDATE DMT_TAX_CARD_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_TAX_CARD_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, STG_STATUS, p_run_id, 'DMT_TAX_CARD_STG_TBL', STG_SEQUENCE_ID) = 'Y'
            /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
          )
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));

        -- CardComponent
        INSERT INTO DMT_TAX_CARD_COMP_TFM_TBL (
            TFM_SEQUENCE_ID,
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            PERSON_NUMBER,
            COMPONENT_NAME,
            COMPONENT_VALUE,
            EFFECTIVE_START_DATE,
            EFFECTIVE_END_DATE,
            LEGISLATIVE_DATA_GROUP_NAME,
            DIRECTIVE_CARD_NAME,
            TAX_REPORTING_UNIT,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            DMT_TAX_CARD_COMP_TFM_SEQ.NEXTVAL,
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            DMT_XREF_PKG.PERSON_NUMBER(s.PERSON_NUMBER),
            s.COMPONENT_NAME,
            s.COMPONENT_VALUE,
            s.EFFECTIVE_START_DATE,
            s.EFFECTIVE_END_DATE,
            s.LEGISLATIVE_DATA_GROUP_NAME,
            s.DIRECTIVE_CARD_NAME,
            s.TAX_REPORTING_UNIT,
            'STAGED',
            SYSDATE
        FROM DMT_TAX_CARD_COMP_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_TAX_CARD_COMP_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
            /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_TAX_CARD_COMP_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := l_ok_count + SQL%ROWCOUNT;

        UPDATE DMT_TAX_CARD_COMP_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_TAX_CARD_COMP_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, STG_STATUS, p_run_id, 'DMT_TAX_CARD_COMP_STG_TBL', STG_SEQUENCE_ID) = 'Y'
            /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
          )
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_TAXCARDS complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_TAXCARDS');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- record-detail anti-join surfaces them as FAILED instead of leaving
            -- the object unaccounted. SQLERRM captured to a local first (not a
            -- valid SQL identifier inside INSERT..SELECT). Backlog #14.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                -- tier 1: Tax Cards
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'TaxCards', 'Tax Cards', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_TAX_CARD_STG_TBL s
                WHERE  (
                        DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_TAX_CARD_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
                        /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
                      )
                AND (p_scenario_id IS NULL
                     OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_TAX_CARD_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Tax Cards');
                UPDATE DMT_TAX_CARD_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Tax Cards')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
                -- tier 2: Tax Card Components
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'TaxCards', 'Tax Card Components', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_TAX_CARD_COMP_STG_TBL s
                WHERE  (
                        DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_TAX_CARD_COMP_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
                        /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
                      )
                AND (p_scenario_id IS NULL
                     OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_TAX_CARD_COMP_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Tax Card Components');
                UPDATE DMT_TAX_CARD_COMP_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Tax Card Components')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
            EXCEPTION WHEN OTHERS THEN NULL;  -- fail-path diagnostics must never throw
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_TAXCARDS failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_TAXCARDS');
            RAISE;
    END TRANSFORM_TAXCARDS;

END DMT_TAX_CARD_TRANSFORM_PKG;
/
