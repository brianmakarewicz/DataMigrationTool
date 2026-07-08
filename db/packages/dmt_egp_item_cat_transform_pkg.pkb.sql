-- PACKAGE BODY DMT_EGP_ITEM_CAT_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_EGP_ITEM_CAT_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_EGP_ITEM_CAT_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_EGP_ITEM_CAT_TRANSFORM_PKG';

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

    PROCEDURE TRANSFORM (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
        l_prefix     VARCHAR2(30);
    BEGIN
        l_prefix := get_prefix(p_run_id);
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM');

        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_EGP_ITEM_CAT_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        INSERT INTO DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    -- Business columns
                    TRANSACTION_TYPE,
                    BATCH_ID,
                    BATCH_NUMBER,
                    ORGANIZATION_CODE,
                    ITEM_NUMBER,
                    CATEGORY_SET_NAME,
                    CATEGORY_CODE,
                    CATEGORY_NAME,
                    OLD_CATEGORY_CODE,
                    OLD_CATEGORY_NAME,
                    SOURCE_SYSTEM_CODE,
                    SOURCE_SYSTEM_REFERENCE,
                    -- Pipeline columns
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,

                    s.TRANSACTION_TYPE,
                    p_run_id,  -- BATCH_ID = run_id (aligns with Items ESS ParameterList arg1)
                    s.BATCH_NUMBER,
                    s.ORGANIZATION_CODE,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.ITEM_NUMBER),
                    s.CATEGORY_SET_NAME,
                    s.CATEGORY_CODE,
                    s.CATEGORY_NAME,
                    s.OLD_CATEGORY_CODE,
                    s.OLD_CATEGORY_NAME,
                    s.SOURCE_SYSTEM_CODE,
                    s.SOURCE_SYSTEM_REFERENCE,

                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_EGP_ITEM_CAT_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        -- Scenario scoping: only transform rows for the active scenario (and, when requested,
        -- untagged rows). Without this the run sweeps the entire staging table regardless of
        -- scenario — mirrors the predicate used by the supplier/customer transforms.
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_EGP_ITEM_CAT_STG_TBL s
        SET    s.STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND s.STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND s.STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
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

END DMT_EGP_ITEM_CAT_TRANSFORM_PKG;
/
