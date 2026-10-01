-- PACKAGE BODY DMT_POZ_SUP_SITE_ASSN_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_SITE_ASSN_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_POZ_SUP_SITE_ASSN_TRANSFORM_PKG Body
-- One supplier-family object. Procedure relocated verbatim from
-- the former shared DMT_POZ_SUP_TRANSFORM_PKG (backlog #43).
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_POZ_SUP_SITE_ASSN_TRANSFORM_PKG';

    -- --------------------------------------------------------
    -- Private: read run prefix from DMT_PIPELINE_RUN_TBL
    -- --------------------------------------------------------
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


    PROCEDURE TRANSFORM_SITE_ASSIGNMENTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
        l_prefix     VARCHAR2(30);

    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_SITE_ASSIGNMENTS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_SITE_ASSIGNMENTS');
        l_prefix := get_prefix(p_run_id);


        -- Accumulate, never overwrite (section 5): ERROR_TEXT is append-only.
        -- The former reprocess-time ERROR_TEXT reset (which was also unscoped —
        -- it hit every FAILED row in the table regardless of scenario) is
        -- removed; the FAILED reselection below stays scenario-scoped via the
        -- shared p_scenario_id predicate.

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_POZ_SUP_SITE_ASSN_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    FBDI_CSV_ID,
                    IMPORT_ACTION,
                    VENDOR_NAME,
                    VENDOR_SITE_CODE,
                    PROCUREMENT_BUSINESS_UNIT_NAME,
                    BUSINESS_UNIT_NAME,
                    BILL_TO_BU_NAME,
                    SHIP_TO_LOCATION_CODE,
                    BILL_TO_LOCATION_CODE,
                    ALLOW_AWT_FLAG,
                    AWT_GROUP_NAME,
                    ACCTS_PAY_CONCAT_SEGMENTS,
                    PREPAY_CONCAT_SEGMENTS,
                    FUTURE_DATED_CONCAT_SEGMENTS,
                    DISTRIBUTION_SET_NAME,
                    INACTIVE_DATE,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    NULL,
                    s.IMPORT_ACTION,
                    -- Both keys here are cross-object references (a site assignment has
                    -- no business key of its own; it links a supplier+site to a BU).
                    -- Resolve each via xref so this object runs standalone.
                    DMT_XREF_PKG.SUPPLIER_NAME(s.VENDOR_NAME),
                    DMT_XREF_PKG.SUPPLIER_SITE(s.VENDOR_SITE_CODE),
                    s.PROCUREMENT_BUSINESS_UNIT_NAME,
                    s.BUSINESS_UNIT_NAME,
                    NVL(s.BILL_TO_BU_NAME, s.BUSINESS_UNIT_NAME),
                    s.SHIP_TO_LOCATION_CODE,
                    s.BILL_TO_LOCATION_CODE,
                    s.ALLOW_AWT_FLAG,
                    s.AWT_GROUP_NAME,
                    s.ACCTS_PAY_CONCAT_SEGMENTS,
                    s.PREPAY_CONCAT_SEGMENTS,
                    s.FUTURE_DATED_CONCAT_SEGMENTS,
                    s.DISTRIBUTION_SET_NAME,
                    s.INACTIVE_DATE,
                    'STAGED',
                    SYSDATE
        FROM DMT_POZ_SUP_SITE_ASSN_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_POZ_SUP_SITE_ASSN_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        -- Deterministic identity assignment: order the INSERT..SELECT by the
        -- STG PK so the TFM PK (GENERATED identity) is assigned in staging order.
        -- The generator emits rows ORDER BY TFM_SEQUENCE_ID, so this keeps the
        -- generated file's row order reproducible (byte-stable golden compare).
        ORDER BY s.STG_SEQUENCE_ID;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_POZ_SUP_SITE_ASSN_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_POZ_SUP_SITE_ASSN_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_SITE_ASSIGNMENTS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_SITE_ASSIGNMENTS');

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
                SELECT p_run_id, 'SupplierSiteAssignments', 'Site Assignments', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_POZ_SUP_SITE_ASSN_STG_TBL s
                WHERE  ( DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
                         OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED')) )
                AND    (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_POZ_SUP_SITE_ASSN_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Site Assignments');
                UPDATE DMT_POZ_SUP_SITE_ASSN_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Site Assignments')
                AND    STG_STATUS IN ('NEW','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;  -- fail-path diagnostics must never throw
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_SITE_ASSIGNMENTS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_SITE_ASSIGNMENTS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_SITE_ASSIGNMENTS;

END DMT_POZ_SUP_SITE_ASSN_TRANSFORM_PKG;
/
