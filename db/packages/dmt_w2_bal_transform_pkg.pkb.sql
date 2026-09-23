-- PACKAGE BODY DMT_W2_BAL_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_W2_BAL_TRANSFORM_PKG" 
AS
-- ============================================================
-- DMT_W2_BAL_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_W2_BAL_TRANSFORM_PKG';

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


    PROCEDURE TRANSFORM_W2BALANCES (
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
            p_message        => 'TRANSFORM_W2BALANCES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_W2BALANCES');

        l_prefix := get_prefix(p_run_id);

        -- BalanceInitialization
        INSERT INTO DMT_W2_BAL_TFM_TBL (
            TFM_SEQUENCE_ID,
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            PERSON_NUMBER,
            LEGAL_EMPLOYER_NAME,
            PAYROLL_RELATIONSHIP_NUMBER,
            PAYROLL_NAME,
            CONSOLIDATION_GROUP_NAME,
            EFFECTIVE_DATE,
            LEGISLATIVE_DATA_GROUP_NAME,
            RECON_KEY,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            DMT_W2_BAL_TFM_SEQ.NEXTVAL,
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            DMT_XREF_PKG.PERSON_NUMBER(s.PERSON_NUMBER),
            s.LEGAL_EMPLOYER_NAME,
            s.PAYROLL_RELATIONSHIP_NUMBER,
            s.PAYROLL_NAME,
            s.CONSOLIDATION_GROUP_NAME,
            s.EFFECTIVE_DATE,
            s.LEGISLATIVE_DATA_GROUP_NAME,
            -- RECON_KEY (Contract v1, design section 5): the balance batch's user
            -- key BatchName = <run prefix> || '_W2BAL' (see DMT_W2_BAL_HDL_GEN_PKG:
            -- one run = one InitializeBalanceBatchHeader whose BatchName is this
            -- value). After load the batch lands in PAY_BAL_BATCH_HEADERS with
            -- BATCH_NAME = this BatchName and BATCH_ID as the base id. All header
            -- rows of a run share the one BatchName (one batch per run). One key
            -- definition per object.
            l_prefix || '_W2BAL',
            'STAGED',
            SYSDATE
        FROM DMT_W2_BAL_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_W2_BAL_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := l_ok_count + SQL%ROWCOUNT;

        UPDATE DMT_W2_BAL_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_W2_BAL_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        -- BalInitializationDetails
        INSERT INTO DMT_W2_BAL_DTL_TFM_TBL (
            TFM_SEQUENCE_ID,
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            PERSON_NUMBER,
            BALANCE_NAME,
            DIMENSION_NAME,
            CONTEXT_NAME,
            CONTEXT_VALUE,
            VALUE,
            CURRENCY_CODE,
            LEGISLATIVE_DATA_GROUP_NAME,
            LEGAL_EMPLOYER_NAME,
            PAYROLL_RELATIONSHIP_NUMBER,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            DMT_W2_BAL_DTL_TFM_SEQ.NEXTVAL,
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            DMT_XREF_PKG.PERSON_NUMBER(s.PERSON_NUMBER),
            s.BALANCE_NAME,
            s.DIMENSION_NAME,
            s.CONTEXT_NAME,
            s.CONTEXT_VALUE,
            s.VALUE,
            s.CURRENCY_CODE,
            s.LEGISLATIVE_DATA_GROUP_NAME,
            s.LEGAL_EMPLOYER_NAME,
            s.PAYROLL_RELATIONSHIP_NUMBER,
            'STAGED',
            SYSDATE
        FROM DMT_W2_BAL_DTL_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_W2_BAL_DTL_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := l_ok_count + SQL%ROWCOUNT;

        UPDATE DMT_W2_BAL_DTL_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_W2_BAL_DTL_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_W2BALANCES complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_W2BALANCES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_W2BALANCES failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_W2BALANCES');
            RAISE;
    END TRANSFORM_W2BALANCES;

END DMT_W2_BAL_TRANSFORM_PKG;
/
