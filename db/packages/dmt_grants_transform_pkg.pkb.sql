-- PACKAGE BODY DMT_GRANTS_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GRANTS_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_GRANTS_TRANSFORM_PKG Body
-- Grants transformation: STG -> TFM with prefix application.
-- Prefix on AWARD_NUMBER for all 15 types.
-- Prefix on PROJECT_NUMBER where it exists.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_GRANTS_TRANSFORM_PKG';

    FUNCTION get_prefix (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_prefix VARCHAR2(30);
    BEGIN
        SELECT PREFIX INTO l_prefix
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;
        RETURN l_prefix;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'RUN_ID ' || p_run_id || ' not found in DMT_PIPELINE_RUN_TBL');
    END get_prefix;

    -- ============================================================
    -- TRANSFORM_HEADERS
    -- ============================================================
    PROCEDURE TRANSFORM_HEADERS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix     VARCHAR2(30);
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;

    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM_HEADERS start.', C_PKG, 'TRANSFORM_HEADERS');
        l_prefix := get_prefix(p_run_id);


        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_GMS_AWD_HEADERS_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_GMS_AWD_HEADERS_TFM_TBL (
                    STG_SEQUENCE_ID, RUN_ID,
                    AWARD_NAME, AWARD_NUMBER, SOURCE_TEMPLATE_NUMBER,
                    BUSINESS_UNIT, LEGAL_ENTITY, CONTRACT_TYPE,
                    PRIMARY_SPONSOR, PRINCIPAL_INVESTIGATOR_EMAIL, PI_NAME, PI_NUMBER,
                    AWARD_START_DATE, AWARD_END_DATE, AWARD_DESCRIPTION,
                    ORGANIZATION, INSTITUTION, SPONSOR_AWARD_NUMBER,
                    AWARD_PURPOSE, AWARD_TYPE, EXPANDED_AUTHORITY_FLAG,
                    COST_SHARE, DEFAULT_BURDEN_SCHEDULE, FIXED_DATE,
                    PRE_AWARD_DATE, PRE_AWARD_SPENDING_ALLOWED, PRE_AWARD_GSF,
                    CLOSE_DATE,
                    COI_INST_POLICY_COMPLIANT, COI_REVIEW_COMPLETED, COI_APPROVAL_DATE,
                    FT_PRIMARY_SPONSOR, FT_REF_AWARD_NAME, FT_FROM_DATE, FT_TO_DATE,
                    FT_AMOUNT, FT_IS_FEDERAL,
                    IS_INTELL_PROP_REPORTED, INTELL_PROP_DESC,
                    PREV_AWARD_BU, PREV_AWARD_NAME, PREV_AWARD_RENEWAL_INPRG, PREV_AWARD_ABR,
                    COST_SHARE_REQ_BY_SPONSOR, COST_SHARE_APPROVED_BY, COST_SHARE_APPROVAL_DATE,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5,
                    ATTRIBUTE6, ATTRIBUTE7, ATTRIBUTE8, ATTRIBUTE9, ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    ATTRIBUTE_NUMBER1, ATTRIBUTE_NUMBER2, ATTRIBUTE_NUMBER3, ATTRIBUTE_NUMBER4, ATTRIBUTE_NUMBER5,
                    ATTRIBUTE_NUMBER6, ATTRIBUTE_NUMBER7, ATTRIBUTE_NUMBER8, ATTRIBUTE_NUMBER9, ATTRIBUTE_NUMBER10,
                    ATTRIBUTE_DATE1, ATTRIBUTE_DATE2, ATTRIBUTE_DATE3, ATTRIBUTE_DATE4, ATTRIBUTE_DATE5,
                    ATTRIBUTE_DATE6, ATTRIBUTE_DATE7, ATTRIBUTE_DATE8, ATTRIBUTE_DATE9, ATTRIBUTE_DATE10,
                    ATTRIBUTE_TIMESTAMP1, ATTRIBUTE_TIMESTAMP2, ATTRIBUTE_TIMESTAMP3, ATTRIBUTE_TIMESTAMP4, ATTRIBUTE_TIMESTAMP5,
                    ATTRIBUTE_TIMESTAMP6, ATTRIBUTE_TIMESTAMP7, ATTRIBUTE_TIMESTAMP8, ATTRIBUTE_TIMESTAMP9, ATTRIBUTE_TIMESTAMP10,
                    CONTRACT_STATUS, CONTRACT_LINE_NAME, LOC_FLAG, DOC_NUMBER,
                    FED_INVOICE_FORMAT, BILL_PLAN_NAME, REVENUE_PLAN_NAME,
                    INVOICE_METHOD, REVENUE_METHOD, BILLING_CYCLE, PAYMENT_TERM,
                    LABOR_FORMAT, NON_LABOR_FORMAT, EVENT_FORMAT, CURRENCY_CODE,
                    PRIMARY_SPONSOR_NUMBER, FT_PRIMARY_SPONSOR_NUMBER,
                    NET_INVOICE_FLAG, INV_HDR_GROUPING_OPTIONS,
                    BILL_TO_SITE_LOCATION, BILL_TO_CONTACT_NAME, BILL_TO_CONTACT_EMAIL,
                    SHIP_TO_SITE_LOCATION, BILL_SET_NUMBER, GENERATED_INVOICE_STATUS,
                    INV_TRX_TYPE_NAME, BILL_TO_ACCT_NUMBER, SHIP_TO_ACCT_NUMBER, PREPAY_TRX_TYPE_NAME
        )
        SELECT
                    s.STG_SEQUENCE_ID, p_run_id,
                    s.AWARD_NAME, DMT_UTIL_PKG.PREFIXED(l_prefix, s.AWARD_NUMBER, 120), s.SOURCE_TEMPLATE_NUMBER,
                    s.BUSINESS_UNIT, s.LEGAL_ENTITY, s.CONTRACT_TYPE,
                    s.PRIMARY_SPONSOR, s.PRINCIPAL_INVESTIGATOR_EMAIL, s.PI_NAME, s.PI_NUMBER,
                    s.AWARD_START_DATE, s.AWARD_END_DATE, s.AWARD_DESCRIPTION,
                    s.ORGANIZATION, s.INSTITUTION, s.SPONSOR_AWARD_NUMBER,
                    s.AWARD_PURPOSE, s.AWARD_TYPE, s.EXPANDED_AUTHORITY_FLAG,
                    s.COST_SHARE, s.DEFAULT_BURDEN_SCHEDULE, s.FIXED_DATE,
                    s.PRE_AWARD_DATE, s.PRE_AWARD_SPENDING_ALLOWED, s.PRE_AWARD_GSF,
                    s.CLOSE_DATE,
                    s.COI_INST_POLICY_COMPLIANT, s.COI_REVIEW_COMPLETED, s.COI_APPROVAL_DATE,
                    s.FT_PRIMARY_SPONSOR, s.FT_REF_AWARD_NAME, s.FT_FROM_DATE, s.FT_TO_DATE,
                    s.FT_AMOUNT, s.FT_IS_FEDERAL,
                    s.IS_INTELL_PROP_REPORTED, s.INTELL_PROP_DESC,
                    s.PREV_AWARD_BU, s.PREV_AWARD_NAME, s.PREV_AWARD_RENEWAL_INPRG, s.PREV_AWARD_ABR,
                    s.COST_SHARE_REQ_BY_SPONSOR, s.COST_SHARE_APPROVED_BY, s.COST_SHARE_APPROVAL_DATE,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1, s.ATTRIBUTE2, s.ATTRIBUTE3, s.ATTRIBUTE4, s.ATTRIBUTE5,
                    s.ATTRIBUTE6, s.ATTRIBUTE7, s.ATTRIBUTE8, s.ATTRIBUTE9, s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    s.ATTRIBUTE_NUMBER1, s.ATTRIBUTE_NUMBER2, s.ATTRIBUTE_NUMBER3, s.ATTRIBUTE_NUMBER4, s.ATTRIBUTE_NUMBER5,
                    s.ATTRIBUTE_NUMBER6, s.ATTRIBUTE_NUMBER7, s.ATTRIBUTE_NUMBER8, s.ATTRIBUTE_NUMBER9, s.ATTRIBUTE_NUMBER10,
                    s.ATTRIBUTE_DATE1, s.ATTRIBUTE_DATE2, s.ATTRIBUTE_DATE3, s.ATTRIBUTE_DATE4, s.ATTRIBUTE_DATE5,
                    s.ATTRIBUTE_DATE6, s.ATTRIBUTE_DATE7, s.ATTRIBUTE_DATE8, s.ATTRIBUTE_DATE9, s.ATTRIBUTE_DATE10,
                    s.ATTRIBUTE_TIMESTAMP1, s.ATTRIBUTE_TIMESTAMP2, s.ATTRIBUTE_TIMESTAMP3, s.ATTRIBUTE_TIMESTAMP4, s.ATTRIBUTE_TIMESTAMP5,
                    s.ATTRIBUTE_TIMESTAMP6, s.ATTRIBUTE_TIMESTAMP7, s.ATTRIBUTE_TIMESTAMP8, s.ATTRIBUTE_TIMESTAMP9, s.ATTRIBUTE_TIMESTAMP10,
                    s.CONTRACT_STATUS, s.CONTRACT_LINE_NAME, s.LOC_FLAG, s.DOC_NUMBER,
                    s.FED_INVOICE_FORMAT, s.BILL_PLAN_NAME, s.REVENUE_PLAN_NAME,
                    s.INVOICE_METHOD, s.REVENUE_METHOD, s.BILLING_CYCLE, s.PAYMENT_TERM,
                    s.LABOR_FORMAT, s.NON_LABOR_FORMAT, s.EVENT_FORMAT, s.CURRENCY_CODE,
                    s.PRIMARY_SPONSOR_NUMBER, s.FT_PRIMARY_SPONSOR_NUMBER,
                    s.NET_INVOICE_FLAG, s.INV_HDR_GROUPING_OPTIONS,
                    s.BILL_TO_SITE_LOCATION, s.BILL_TO_CONTACT_NAME, s.BILL_TO_CONTACT_EMAIL,
                    s.SHIP_TO_SITE_LOCATION, s.BILL_SET_NUMBER, s.GENERATED_INVOICE_STATUS,
                    s.INV_TRX_TYPE_NAME, s.BILL_TO_ACCT_NUMBER, s.SHIP_TO_ACCT_NUMBER, s.PREPAY_TRX_TYPE_NAME
        FROM DMT_GMS_AWD_HEADERS_STG_TBL s
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
            SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Contract v1 coupling (multi-tier template, Grants award-header tier).
        -- Stamp the award-header RECON_KEY so it equals the header RECORD_KEY the
        -- nine-column Grants recon data model (DMT_GRANT_RECON_DM.xdm) emits. That
        -- data model's BASE tier keys each award on
        --   NVL(SPONSOR_AWARD_NUMBER, 'AWARD_ID:' || ID)
        -- (the sponsor award number that survives to GMS_AWARD_HEADERS_B, falling
        -- back to the Fusion award id when the sponsor number is null). The Fusion
        -- award id does not exist until the row lands in the base table, so the
        -- fallback branch cannot be reproduced at transform time; we stamp the
        -- SPONSOR_AWARD_NUMBER that this TFM row carries (raw, unprefixed -- it is
        -- copied straight from the source and survives unchanged onto the base row).
        -- An award with no sponsor number therefore keys on the Fusion-side
        -- 'AWARD_ID:' fallback only, which the TFM cannot predict, so such a row
        -- stays GENERATED (honest unaccounted) rather than being fabricated LOADED.
        -- The shared reconciler (DMT_GRANTS_RESULTS_PKG.APPLY_CONTRACT_V1_GRANTS)
        -- joins report rows to this table on RECON_KEY = report RECORD_KEY, so this
        -- stamp must match that expression. Only NULL keys are set (never
        -- overwrite); post-INSERT, run-scoped.
        UPDATE DMT_GMS_AWD_HEADERS_TFM_TBL
        SET    RECON_KEY = SPONSOR_AWARD_NUMBER,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    RECON_KEY IS NULL
        AND    SPONSOR_AWARD_NUMBER IS NOT NULL;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_GMS_AWD_HEADERS_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_HEADERS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_HEADERS');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- funnel's TRANSFORM_FAILED lane fills (design section 5 / section 7).
            -- SQLERRM captured into a local first: it is not a valid SQL identifier
            -- inside the INSERT..SELECT below, only in PL/SQL scope.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Grants', 'Award Headers', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_GMS_AWD_HEADERS_STG_TBL s
                WHERE  (
                        (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW','RETRY'))
                        OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
                        OR (p_run_mode = 'ALL')
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Award Headers');
                UPDATE DMT_GMS_AWD_HEADERS_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Award Headers')
                AND    STG_STATUS IN ('NEW','RETRY','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_HEADERS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_HEADERS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_HEADERS;


    -- ============================================================
    -- Generic child transform helper macro
    -- For each child: prefix AWARD_NUMBER, prefix PROJECT_NUMBER if present
    -- ============================================================

    -- ============================================================
    -- TRANSFORM_FUNDING
    -- ============================================================
    PROCEDURE TRANSFORM_FUNDING (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix VARCHAR2(30);
        l_ok_count NUMBER := 0; l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM_FUNDING start.', C_PKG, 'TRANSFORM_FUNDING');
        l_prefix := get_prefix(p_run_id);

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_GMS_AWD_FUNDING_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_GMS_AWD_FUNDING_TFM_TBL (
                    STG_SEQUENCE_ID, RUN_ID,
                    AWARD_NUMBER, BUDGET_PERIOD_NAME, FUNDING_SOURCE_NAME,
                    ISSUE_TYPE, ISSUE_NUMBER, ISSUE_DATE, ISSUE_DESCRIPTION,
                    DIRECT_FUNDING_AMOUNT, INDIRECT_FUNDING_AMOUNT, FUNDING_SOURCE_NUMBER
        )
        SELECT
                    s.STG_SEQUENCE_ID, p_run_id,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.AWARD_NUMBER, 120), s.BUDGET_PERIOD_NAME, s.FUNDING_SOURCE_NAME,
                    s.ISSUE_TYPE, s.ISSUE_NUMBER, s.ISSUE_DATE, s.ISSUE_DESCRIPTION,
                    s.DIRECT_FUNDING_AMOUNT, s.INDIRECT_FUNDING_AMOUNT, s.FUNDING_SOURCE_NUMBER
        FROM DMT_GMS_AWD_FUNDING_STG_TBL s
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
            SELECT 1 FROM DMT_GMS_AWD_FUNDING_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_GMS_AWD_FUNDING_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_GMS_AWD_FUNDING_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_FUNDING complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_FUNDING');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- funnel's TRANSFORM_FAILED lane fills (design section 5 / section 7).
            -- SQLERRM captured into a local first: it is not a valid SQL identifier
            -- inside the INSERT..SELECT below, only in PL/SQL scope.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Grants', 'Award Funding', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_GMS_AWD_FUNDING_STG_TBL s
                WHERE  (
                        (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW','RETRY'))
                        OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
                        OR (p_run_mode = 'ALL')
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_GMS_AWD_FUNDING_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Award Funding');
                UPDATE DMT_GMS_AWD_FUNDING_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Award Funding')
                AND    STG_STATUS IN ('NEW','RETRY','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_FUNDING failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_FUNDING',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_FUNDING;

    -- ============================================================
    -- TRANSFORM_PROJECTS
    -- ============================================================
    PROCEDURE TRANSFORM_PROJECTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix     VARCHAR2(30);
        l_ok_count NUMBER := 0; l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM_PROJECTS start.', C_PKG, 'TRANSFORM_PROJECTS');
        l_prefix     := get_prefix(p_run_id);

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_GMS_AWD_PROJECTS_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_GMS_AWD_PROJECTS_TFM_TBL (
                    STG_SEQUENCE_ID, RUN_ID,
                    AWARD_NUMBER, FUNDING_SOURCE_NAME, PROJECT_NUMBER,
                    AWARD_PRJ_BRD_SCHEDULE, FIXED_DATE, ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5,
                    ATTRIBUTE6, ATTRIBUTE7, ATTRIBUTE8, ATTRIBUTE9, ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    ATTRIBUTE_NUMBER1, ATTRIBUTE_NUMBER2, ATTRIBUTE_NUMBER3, ATTRIBUTE_NUMBER4, ATTRIBUTE_NUMBER5,
                    ATTRIBUTE_NUMBER6, ATTRIBUTE_NUMBER7, ATTRIBUTE_NUMBER8, ATTRIBUTE_NUMBER9, ATTRIBUTE_NUMBER10,
                    ATTRIBUTE_DATE1, ATTRIBUTE_DATE2, ATTRIBUTE_DATE3, ATTRIBUTE_DATE4, ATTRIBUTE_DATE5,
                    ATTRIBUTE_DATE6, ATTRIBUTE_DATE7, ATTRIBUTE_DATE8, ATTRIBUTE_DATE9, ATTRIBUTE_DATE10,
                    ATTRIBUTE_TIMESTAMP1, ATTRIBUTE_TIMESTAMP2, ATTRIBUTE_TIMESTAMP3, ATTRIBUTE_TIMESTAMP4, ATTRIBUTE_TIMESTAMP5,
                    ATTRIBUTE_TIMESTAMP6, ATTRIBUTE_TIMESTAMP7, ATTRIBUTE_TIMESTAMP8, ATTRIBUTE_TIMESTAMP9, ATTRIBUTE_TIMESTAMP10
        )
        SELECT
                    s.STG_SEQUENCE_ID, p_run_id,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.AWARD_NUMBER, 120), s.FUNDING_SOURCE_NAME, DMT_XREF_PKG.PROJECT_NUMBER(s.PROJECT_NUMBER),
                    s.AWARD_PRJ_BRD_SCHEDULE, s.FIXED_DATE, s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1, s.ATTRIBUTE2, s.ATTRIBUTE3, s.ATTRIBUTE4, s.ATTRIBUTE5,
                    s.ATTRIBUTE6, s.ATTRIBUTE7, s.ATTRIBUTE8, s.ATTRIBUTE9, s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    s.ATTRIBUTE_NUMBER1, s.ATTRIBUTE_NUMBER2, s.ATTRIBUTE_NUMBER3, s.ATTRIBUTE_NUMBER4, s.ATTRIBUTE_NUMBER5,
                    s.ATTRIBUTE_NUMBER6, s.ATTRIBUTE_NUMBER7, s.ATTRIBUTE_NUMBER8, s.ATTRIBUTE_NUMBER9, s.ATTRIBUTE_NUMBER10,
                    s.ATTRIBUTE_DATE1, s.ATTRIBUTE_DATE2, s.ATTRIBUTE_DATE3, s.ATTRIBUTE_DATE4, s.ATTRIBUTE_DATE5,
                    s.ATTRIBUTE_DATE6, s.ATTRIBUTE_DATE7, s.ATTRIBUTE_DATE8, s.ATTRIBUTE_DATE9, s.ATTRIBUTE_DATE10,
                    s.ATTRIBUTE_TIMESTAMP1, s.ATTRIBUTE_TIMESTAMP2, s.ATTRIBUTE_TIMESTAMP3, s.ATTRIBUTE_TIMESTAMP4, s.ATTRIBUTE_TIMESTAMP5,
                    s.ATTRIBUTE_TIMESTAMP6, s.ATTRIBUTE_TIMESTAMP7, s.ATTRIBUTE_TIMESTAMP8, s.ATTRIBUTE_TIMESTAMP9, s.ATTRIBUTE_TIMESTAMP10
        FROM DMT_GMS_AWD_PROJECTS_STG_TBL s
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
            SELECT 1 FROM DMT_GMS_AWD_PROJECTS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        -- Honor pre-validation rejections in EVERY run mode (ALL-mode-bypass backlog
        -- item). The Grants validator only rejects award-project rows (its sole
        -- [PRE_VALIDATION] check: upstream project did not load), tagged 'Award Projects'.
        -- ALL/FAILED modes do not filter on STG_STATUS, so without this that rejected row
        -- would still be transformed. Scope to 'Award Projects' — the only Grants STG
        -- table the validator tags; the other Grants transform procs read tables the
        -- validator never tags, so an exclusion there would be a dead no-op.
        AND NOT EXISTS (
            SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID          = p_run_id
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    e.SUB_OBJECT      = 'Award Projects'
            AND    e.ERROR_TEXT LIKE '[PRE_VALIDATION]%'
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_GMS_AWD_PROJECTS_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_GMS_AWD_PROJECTS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PROJECTS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PROJECTS');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- funnel's TRANSFORM_FAILED lane fills (design section 5 / section 7).
            -- SQLERRM captured into a local first: it is not a valid SQL identifier
            -- inside the INSERT..SELECT below, only in PL/SQL scope.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Grants', 'Award Projects', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_GMS_AWD_PROJECTS_STG_TBL s
                WHERE  (
                        (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW','RETRY'))
                        OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
                        OR (p_run_mode = 'ALL')
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_GMS_AWD_PROJECTS_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Award Projects');
                UPDATE DMT_GMS_AWD_PROJECTS_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Award Projects')
                AND    STG_STATUS IN ('NEW','RETRY','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_PROJECTS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_PROJECTS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_PROJECTS;

    -- ============================================================
    -- TRANSFORM_PERSONNEL
    -- ============================================================
    PROCEDURE TRANSFORM_PERSONNEL (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix     VARCHAR2(30);
        l_ok_count NUMBER := 0; l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM_PERSONNEL start.', C_PKG, 'TRANSFORM_PERSONNEL');
        l_prefix     := get_prefix(p_run_id);

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_GMS_AWD_PERSONNEL_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_GMS_AWD_PERSONNEL_TFM_TBL (
                    STG_SEQUENCE_ID, RUN_ID,
                    AWARD_NUMBER, PROJECT_NUMBER, INTERNAL, PERSON_EMAIL, PERSON_NAME, PERSON_NUMBER,
                    ROLE, START_DATE, END_DATE, CREDIT_PERCENTAGE, ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5,
                    ATTRIBUTE6, ATTRIBUTE7, ATTRIBUTE8, ATTRIBUTE9, ATTRIBUTE10,
                    ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
                    ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
                    ATTRIBUTE_NUMBER1, ATTRIBUTE_NUMBER2, ATTRIBUTE_NUMBER3, ATTRIBUTE_NUMBER4, ATTRIBUTE_NUMBER5,
                    ATTRIBUTE_NUMBER6, ATTRIBUTE_NUMBER7, ATTRIBUTE_NUMBER8, ATTRIBUTE_NUMBER9, ATTRIBUTE_NUMBER10,
                    ATTRIBUTE_DATE1, ATTRIBUTE_DATE2, ATTRIBUTE_DATE3, ATTRIBUTE_DATE4, ATTRIBUTE_DATE5,
                    ATTRIBUTE_DATE6, ATTRIBUTE_DATE7, ATTRIBUTE_DATE8, ATTRIBUTE_DATE9, ATTRIBUTE_DATE10,
                    ATTRIBUTE_TIMESTAMP1, ATTRIBUTE_TIMESTAMP2, ATTRIBUTE_TIMESTAMP3, ATTRIBUTE_TIMESTAMP4, ATTRIBUTE_TIMESTAMP5,
                    ATTRIBUTE_TIMESTAMP6, ATTRIBUTE_TIMESTAMP7, ATTRIBUTE_TIMESTAMP8, ATTRIBUTE_TIMESTAMP9, ATTRIBUTE_TIMESTAMP10
        )
        SELECT
                    s.STG_SEQUENCE_ID, p_run_id,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.AWARD_NUMBER, 120), DMT_XREF_PKG.PROJECT_NUMBER(s.PROJECT_NUMBER), s.INTERNAL, s.PERSON_EMAIL, s.PERSON_NAME, s.PERSON_NUMBER,
                    s.ROLE, s.START_DATE, s.END_DATE, s.CREDIT_PERCENTAGE, s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1, s.ATTRIBUTE2, s.ATTRIBUTE3, s.ATTRIBUTE4, s.ATTRIBUTE5,
                    s.ATTRIBUTE6, s.ATTRIBUTE7, s.ATTRIBUTE8, s.ATTRIBUTE9, s.ATTRIBUTE10,
                    s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
                    s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
                    s.ATTRIBUTE_NUMBER1, s.ATTRIBUTE_NUMBER2, s.ATTRIBUTE_NUMBER3, s.ATTRIBUTE_NUMBER4, s.ATTRIBUTE_NUMBER5,
                    s.ATTRIBUTE_NUMBER6, s.ATTRIBUTE_NUMBER7, s.ATTRIBUTE_NUMBER8, s.ATTRIBUTE_NUMBER9, s.ATTRIBUTE_NUMBER10,
                    s.ATTRIBUTE_DATE1, s.ATTRIBUTE_DATE2, s.ATTRIBUTE_DATE3, s.ATTRIBUTE_DATE4, s.ATTRIBUTE_DATE5,
                    s.ATTRIBUTE_DATE6, s.ATTRIBUTE_DATE7, s.ATTRIBUTE_DATE8, s.ATTRIBUTE_DATE9, s.ATTRIBUTE_DATE10,
                    s.ATTRIBUTE_TIMESTAMP1, s.ATTRIBUTE_TIMESTAMP2, s.ATTRIBUTE_TIMESTAMP3, s.ATTRIBUTE_TIMESTAMP4, s.ATTRIBUTE_TIMESTAMP5,
                    s.ATTRIBUTE_TIMESTAMP6, s.ATTRIBUTE_TIMESTAMP7, s.ATTRIBUTE_TIMESTAMP8, s.ATTRIBUTE_TIMESTAMP9, s.ATTRIBUTE_TIMESTAMP10
        FROM DMT_GMS_AWD_PERSONNEL_STG_TBL s
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
            SELECT 1 FROM DMT_GMS_AWD_PERSONNEL_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_GMS_AWD_PERSONNEL_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_GMS_AWD_PERSONNEL_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PERSONNEL complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PERSONNEL');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- funnel's TRANSFORM_FAILED lane fills (design section 5 / section 7).
            -- SQLERRM captured into a local first: it is not a valid SQL identifier
            -- inside the INSERT..SELECT below, only in PL/SQL scope.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Grants', 'Award Personnel', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_GMS_AWD_PERSONNEL_STG_TBL s
                WHERE  (
                        (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW','RETRY'))
                        OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
                        OR (p_run_mode = 'ALL')
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_GMS_AWD_PERSONNEL_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Award Personnel');
                UPDATE DMT_GMS_AWD_PERSONNEL_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Award Personnel')
                AND    STG_STATUS IN ('NEW','RETRY','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_PERSONNEL failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_PERSONNEL',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_PERSONNEL;

    -- ============================================================
    -- TRANSFORM_FUND_SOURCES
    -- ============================================================
    PROCEDURE TRANSFORM_FUND_SOURCES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix VARCHAR2(30);
        l_ok_count NUMBER := 0; l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM_FUND_SOURCES start.', C_PKG, 'TRANSFORM_FUND_SOURCES');
        l_prefix := get_prefix(p_run_id);

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_GMS_AWD_FUND_SRC_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_GMS_AWD_FUND_SRC_TFM_TBL (
                    STG_SEQUENCE_ID, RUN_ID,
                    AWARD_NUMBER, FUNDING_SOURCE_NAME, FUNDING_SOURCE_NUMBER,
                    COST_SHARE_REQ_BY_SPONSOR, COST_SHARE_APPROVED_BY_EMAIL,
                    COST_SHARE_APPROVED_BY_NAME, COST_SHARE_APPROVED_BY_NUMBER, COST_SHARE_APPROVAL_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID, p_run_id,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.AWARD_NUMBER, 120), s.FUNDING_SOURCE_NAME, s.FUNDING_SOURCE_NUMBER,
                    s.COST_SHARE_REQ_BY_SPONSOR, s.COST_SHARE_APPROVED_BY_EMAIL,
                    s.COST_SHARE_APPROVED_BY_NAME, s.COST_SHARE_APPROVED_BY_NUMBER, s.COST_SHARE_APPROVAL_DATE
        FROM DMT_GMS_AWD_FUND_SRC_STG_TBL s
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
            SELECT 1 FROM DMT_GMS_AWD_FUND_SRC_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_GMS_AWD_FUND_SRC_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_GMS_AWD_FUND_SRC_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_FUND_SOURCES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_FUND_SOURCES');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- funnel's TRANSFORM_FAILED lane fills (design section 5 / section 7).
            -- SQLERRM captured into a local first: it is not a valid SQL identifier
            -- inside the INSERT..SELECT below, only in PL/SQL scope.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Grants', 'Award Funding Sources', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_GMS_AWD_FUND_SRC_STG_TBL s
                WHERE  (
                        (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW','RETRY'))
                        OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
                        OR (p_run_mode = 'ALL')
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_GMS_AWD_FUND_SRC_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Award Funding Sources');
                UPDATE DMT_GMS_AWD_FUND_SRC_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Award Funding Sources')
                AND    STG_STATUS IN ('NEW','RETRY','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_FUND_SOURCES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_FUND_SOURCES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_FUND_SOURCES;

    -- ============================================================
    -- TRANSFORM_PRJ_FUND_SRCS
    -- ============================================================
    PROCEDURE TRANSFORM_PRJ_FUND_SRCS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix     VARCHAR2(30);
        l_ok_count NUMBER := 0; l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM_PRJ_FUND_SRCS start.', C_PKG, 'TRANSFORM_PRJ_FUND_SRCS');
        l_prefix     := get_prefix(p_run_id);

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL (
                    STG_SEQUENCE_ID, RUN_ID,
                    AWARD_NUMBER, PROJECT_NUMBER, FUNDING_SOURCE_NAME, FUNDING_SOURCE_NUMBER, ENABLE_BURDENING_FLAG
        )
        SELECT
                    s.STG_SEQUENCE_ID, p_run_id,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.AWARD_NUMBER, 120), DMT_XREF_PKG.PROJECT_NUMBER(s.PROJECT_NUMBER), s.FUNDING_SOURCE_NAME, s.FUNDING_SOURCE_NUMBER, s.ENABLE_BURDENING_FLAG
        FROM DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL s
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
            SELECT 1 FROM DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PRJ_FUND_SRCS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PRJ_FUND_SRCS');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- funnel's TRANSFORM_FAILED lane fills (design section 5 / section 7).
            -- SQLERRM captured into a local first: it is not a valid SQL identifier
            -- inside the INSERT..SELECT below, only in PL/SQL scope.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Grants', 'Project Funding Sources', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL s
                WHERE  (
                        (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW','RETRY'))
                        OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
                        OR (p_run_mode = 'ALL')
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Project Funding Sources');
                UPDATE DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Project Funding Sources')
                AND    STG_STATUS IN ('NEW','RETRY','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_PRJ_FUND_SRCS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_PRJ_FUND_SRCS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_PRJ_FUND_SRCS;

    -- ============================================================
    -- TRANSFORM_KEYWORDS
    -- ============================================================
    PROCEDURE TRANSFORM_KEYWORDS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix     VARCHAR2(30);
        l_ok_count NUMBER := 0; l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM_KEYWORDS start.', C_PKG, 'TRANSFORM_KEYWORDS');
        l_prefix     := get_prefix(p_run_id);

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_GMS_AWD_KEYWORDS_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_GMS_AWD_KEYWORDS_TFM_TBL (
                    STG_SEQUENCE_ID, RUN_ID, AWARD_NUMBER, PROJECT_NUMBER, KEYWORD_NAME
        )
        SELECT
                    s.STG_SEQUENCE_ID, p_run_id, DMT_UTIL_PKG.PREFIXED(l_prefix, s.AWARD_NUMBER, 120), DMT_XREF_PKG.PROJECT_NUMBER(s.PROJECT_NUMBER), s.KEYWORD_NAME
        FROM DMT_GMS_AWD_KEYWORDS_STG_TBL s
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
            SELECT 1 FROM DMT_GMS_AWD_KEYWORDS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_GMS_AWD_KEYWORDS_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_GMS_AWD_KEYWORDS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_KEYWORDS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_KEYWORDS');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- funnel's TRANSFORM_FAILED lane fills (design section 5 / section 7).
            -- SQLERRM captured into a local first: it is not a valid SQL identifier
            -- inside the INSERT..SELECT below, only in PL/SQL scope.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Grants', 'Award Keywords', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_GMS_AWD_KEYWORDS_STG_TBL s
                WHERE  (
                        (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW','RETRY'))
                        OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
                        OR (p_run_mode = 'ALL')
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_GMS_AWD_KEYWORDS_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Award Keywords');
                UPDATE DMT_GMS_AWD_KEYWORDS_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Award Keywords')
                AND    STG_STATUS IN ('NEW','RETRY','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_KEYWORDS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_KEYWORDS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_KEYWORDS;

    -- ============================================================
    -- TRANSFORM_BUDGET_PERIODS
    -- ============================================================
    PROCEDURE TRANSFORM_BUDGET_PERIODS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix VARCHAR2(30);
        l_ok_count NUMBER := 0; l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM_BUDGET_PERIODS start.', C_PKG, 'TRANSFORM_BUDGET_PERIODS');
        l_prefix := get_prefix(p_run_id);

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_GMS_AWD_BDGT_PRDS_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_GMS_AWD_BDGT_PRDS_TFM_TBL (
                    STG_SEQUENCE_ID, RUN_ID, AWARD_NUMBER, BUDGET_PERIOD, START_DATE, END_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID, p_run_id, DMT_UTIL_PKG.PREFIXED(l_prefix, s.AWARD_NUMBER, 120), s.BUDGET_PERIOD, s.START_DATE, s.END_DATE
        FROM DMT_GMS_AWD_BDGT_PRDS_STG_TBL s
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
            SELECT 1 FROM DMT_GMS_AWD_BDGT_PRDS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_GMS_AWD_BDGT_PRDS_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_GMS_AWD_BDGT_PRDS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_BUDGET_PERIODS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_BUDGET_PERIODS');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- funnel's TRANSFORM_FAILED lane fills (design section 5 / section 7).
            -- SQLERRM captured into a local first: it is not a valid SQL identifier
            -- inside the INSERT..SELECT below, only in PL/SQL scope.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Grants', 'Budget Periods', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_GMS_AWD_BDGT_PRDS_STG_TBL s
                WHERE  (
                        (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW','RETRY'))
                        OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
                        OR (p_run_mode = 'ALL')
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_GMS_AWD_BDGT_PRDS_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Budget Periods');
                UPDATE DMT_GMS_AWD_BDGT_PRDS_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Budget Periods')
                AND    STG_STATUS IN ('NEW','RETRY','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_BUDGET_PERIODS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_BUDGET_PERIODS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_BUDGET_PERIODS;

    -- ============================================================
    -- TRANSFORM_CERTS
    -- ============================================================
    PROCEDURE TRANSFORM_CERTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix     VARCHAR2(30);
        l_ok_count NUMBER := 0; l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM_CERTS start.', C_PKG, 'TRANSFORM_CERTS');
        l_prefix     := get_prefix(p_run_id);

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_GMS_AWD_CERTS_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_GMS_AWD_CERTS_TFM_TBL (
                    STG_SEQUENCE_ID, RUN_ID,
                    AWARD_NUMBER, PROJECT_NUMBER, CERTIFICATION_NAME, CERTIFICATION_DATE,
                    CERTIFIED_BY, CERT_STATUS, APPROVAL_DATE, EXPIRATION_DATE,
                    EXPEDITED_REVIEW, FULL_REVIEW, ASSURANCE_NUMBER, EXEMPTION_NUMBER, COMMENTS
        )
        SELECT
                    s.STG_SEQUENCE_ID, p_run_id,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.AWARD_NUMBER, 120), DMT_XREF_PKG.PROJECT_NUMBER(s.PROJECT_NUMBER), s.CERTIFICATION_NAME, s.CERTIFICATION_DATE,
                    s.CERTIFIED_BY, s.CERT_STATUS, s.APPROVAL_DATE, s.EXPIRATION_DATE,
                    s.EXPEDITED_REVIEW, s.FULL_REVIEW, s.ASSURANCE_NUMBER, s.EXEMPTION_NUMBER, s.COMMENTS
        FROM DMT_GMS_AWD_CERTS_STG_TBL s
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
            SELECT 1 FROM DMT_GMS_AWD_CERTS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_GMS_AWD_CERTS_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_GMS_AWD_CERTS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_CERTS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_CERTS');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- funnel's TRANSFORM_FAILED lane fills (design section 5 / section 7).
            -- SQLERRM captured into a local first: it is not a valid SQL identifier
            -- inside the INSERT..SELECT below, only in PL/SQL scope.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Grants', 'Award Certifications', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_GMS_AWD_CERTS_STG_TBL s
                WHERE  (
                        (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW','RETRY'))
                        OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
                        OR (p_run_mode = 'ALL')
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_GMS_AWD_CERTS_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Award Certifications');
                UPDATE DMT_GMS_AWD_CERTS_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Award Certifications')
                AND    STG_STATUS IN ('NEW','RETRY','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_CERTS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_CERTS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_CERTS;

    -- ============================================================
    -- TRANSFORM_CFDAS
    -- ============================================================
    PROCEDURE TRANSFORM_CFDAS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix VARCHAR2(30);
        l_ok_count NUMBER := 0; l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM_CFDAS start.', C_PKG, 'TRANSFORM_CFDAS');
        l_prefix := get_prefix(p_run_id);

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_GMS_AWD_CFDAS_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_GMS_AWD_CFDAS_TFM_TBL (
                    STG_SEQUENCE_ID, RUN_ID, AWARD_NUMBER, CFDA
        )
        SELECT
                    s.STG_SEQUENCE_ID, p_run_id, DMT_UTIL_PKG.PREFIXED(l_prefix, s.AWARD_NUMBER, 120), s.CFDA
        FROM DMT_GMS_AWD_CFDAS_STG_TBL s
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
            SELECT 1 FROM DMT_GMS_AWD_CFDAS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_GMS_AWD_CFDAS_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_GMS_AWD_CFDAS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_CFDAS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_CFDAS');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- funnel's TRANSFORM_FAILED lane fills (design section 5 / section 7).
            -- SQLERRM captured into a local first: it is not a valid SQL identifier
            -- inside the INSERT..SELECT below, only in PL/SQL scope.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Grants', 'Award CFDAs', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_GMS_AWD_CFDAS_STG_TBL s
                WHERE  (
                        (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW','RETRY'))
                        OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
                        OR (p_run_mode = 'ALL')
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_GMS_AWD_CFDAS_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Award CFDAs');
                UPDATE DMT_GMS_AWD_CFDAS_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Award CFDAs')
                AND    STG_STATUS IN ('NEW','RETRY','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_CFDAS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_CFDAS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_CFDAS;

    -- ============================================================
    -- TRANSFORM_FUND_ALLOCS
    -- ============================================================
    PROCEDURE TRANSFORM_FUND_ALLOCS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix     VARCHAR2(30);
        l_ok_count NUMBER := 0; l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM_FUND_ALLOCS start.', C_PKG, 'TRANSFORM_FUND_ALLOCS');
        l_prefix     := get_prefix(p_run_id);

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_GMS_AWD_FUND_ALLOC_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_GMS_AWD_FUND_ALLOC_TFM_TBL (
                    STG_SEQUENCE_ID, RUN_ID, AWARD_NUMBER, PROJECT_NUMBER, ISSUE_NUMBER, FUNDING_AMOUNT
        )
        SELECT
                    s.STG_SEQUENCE_ID, p_run_id, DMT_UTIL_PKG.PREFIXED(l_prefix, s.AWARD_NUMBER, 120), DMT_XREF_PKG.PROJECT_NUMBER(s.PROJECT_NUMBER), s.ISSUE_NUMBER, s.FUNDING_AMOUNT
        FROM DMT_GMS_AWD_FUND_ALLOC_STG_TBL s
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
            SELECT 1 FROM DMT_GMS_AWD_FUND_ALLOC_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_GMS_AWD_FUND_ALLOC_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_GMS_AWD_FUND_ALLOC_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_FUND_ALLOCS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_FUND_ALLOCS');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- funnel's TRANSFORM_FAILED lane fills (design section 5 / section 7).
            -- SQLERRM captured into a local first: it is not a valid SQL identifier
            -- inside the INSERT..SELECT below, only in PL/SQL scope.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Grants', 'Funding Allocations', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_GMS_AWD_FUND_ALLOC_STG_TBL s
                WHERE  (
                        (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW','RETRY'))
                        OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
                        OR (p_run_mode = 'ALL')
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_GMS_AWD_FUND_ALLOC_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Funding Allocations');
                UPDATE DMT_GMS_AWD_FUND_ALLOC_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Funding Allocations')
                AND    STG_STATUS IN ('NEW','RETRY','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_FUND_ALLOCS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_FUND_ALLOCS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_FUND_ALLOCS;

    -- ============================================================
    -- TRANSFORM_ORG_CREDITS
    -- ============================================================
    PROCEDURE TRANSFORM_ORG_CREDITS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix     VARCHAR2(30);
        l_ok_count NUMBER := 0; l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM_ORG_CREDITS start.', C_PKG, 'TRANSFORM_ORG_CREDITS');
        l_prefix     := get_prefix(p_run_id);

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_GMS_AWD_ORG_CREDITS_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_GMS_AWD_ORG_CREDITS_TFM_TBL (
                    STG_SEQUENCE_ID, RUN_ID, AWARD_NUMBER, PROJECT_NUMBER, ORGANIZATION, CREDIT_PERCENTAGE
        )
        SELECT
                    s.STG_SEQUENCE_ID, p_run_id, DMT_UTIL_PKG.PREFIXED(l_prefix, s.AWARD_NUMBER, 120), DMT_XREF_PKG.PROJECT_NUMBER(s.PROJECT_NUMBER), s.ORGANIZATION, s.CREDIT_PERCENTAGE
        FROM DMT_GMS_AWD_ORG_CREDITS_STG_TBL s
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
            SELECT 1 FROM DMT_GMS_AWD_ORG_CREDITS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_GMS_AWD_ORG_CREDITS_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_GMS_AWD_ORG_CREDITS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_ORG_CREDITS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_ORG_CREDITS');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- funnel's TRANSFORM_FAILED lane fills (design section 5 / section 7).
            -- SQLERRM captured into a local first: it is not a valid SQL identifier
            -- inside the INSERT..SELECT below, only in PL/SQL scope.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Grants', 'Org Credits', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_GMS_AWD_ORG_CREDITS_STG_TBL s
                WHERE  (
                        (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW','RETRY'))
                        OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
                        OR (p_run_mode = 'ALL')
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_GMS_AWD_ORG_CREDITS_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Org Credits');
                UPDATE DMT_GMS_AWD_ORG_CREDITS_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Org Credits')
                AND    STG_STATUS IN ('NEW','RETRY','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_ORG_CREDITS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_ORG_CREDITS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_ORG_CREDITS;

    -- ============================================================
    -- TRANSFORM_PRJ_TASK_BURDEN
    -- ============================================================
    PROCEDURE TRANSFORM_PRJ_TASK_BURDEN (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix     VARCHAR2(30);
        l_ok_count NUMBER := 0; l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM_PRJ_TASK_BURDEN start.', C_PKG, 'TRANSFORM_PRJ_TASK_BURDEN');
        l_prefix     := get_prefix(p_run_id);

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL (
                    STG_SEQUENCE_ID, RUN_ID, AWARD_NUMBER, PROJECT_NUMBER, TASK_NUMBER, BURDEN_SCHEDULE, FIXED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID, p_run_id, DMT_UTIL_PKG.PREFIXED(l_prefix, s.AWARD_NUMBER, 120), DMT_XREF_PKG.PROJECT_NUMBER(s.PROJECT_NUMBER), DMT_XREF_PKG.TASK_NUMBER(s.TASK_NUMBER), s.BURDEN_SCHEDULE, s.FIXED_DATE
        FROM DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL s
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
            SELECT 1 FROM DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PRJ_TASK_BURDEN complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PRJ_TASK_BURDEN');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- funnel's TRANSFORM_FAILED lane fills (design section 5 / section 7).
            -- SQLERRM captured into a local first: it is not a valid SQL identifier
            -- inside the INSERT..SELECT below, only in PL/SQL scope.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Grants', 'Project Task Burden', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL s
                WHERE  (
                        (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW','RETRY'))
                        OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
                        OR (p_run_mode = 'ALL')
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Project Task Burden');
                UPDATE DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Project Task Burden')
                AND    STG_STATUS IN ('NEW','RETRY','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_PRJ_TASK_BURDEN failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_PRJ_TASK_BURDEN',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_PRJ_TASK_BURDEN;

    -- ============================================================
    -- TRANSFORM_REFERENCES
    -- ============================================================
    PROCEDURE TRANSFORM_REFERENCES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix     VARCHAR2(30);
        l_ok_count NUMBER := 0; l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM_REFERENCES start.', C_PKG, 'TRANSFORM_REFERENCES');
        l_prefix     := get_prefix(p_run_id);

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_GMS_AWD_REFERENCES_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_GMS_AWD_REFERENCES_TFM_TBL (
                    STG_SEQUENCE_ID, RUN_ID, AWARD_NUMBER, PROJECT_NUMBER, REFERENCE_TYPE, VALUE, COMMENTS
        )
        SELECT
                    s.STG_SEQUENCE_ID, p_run_id, DMT_UTIL_PKG.PREFIXED(l_prefix, s.AWARD_NUMBER, 120), DMT_XREF_PKG.PROJECT_NUMBER(s.PROJECT_NUMBER), s.REFERENCE_TYPE, s.VALUE, s.COMMENTS
        FROM DMT_GMS_AWD_REFERENCES_STG_TBL s
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
            SELECT 1 FROM DMT_GMS_AWD_REFERENCES_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_GMS_AWD_REFERENCES_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_GMS_AWD_REFERENCES_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_REFERENCES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_REFERENCES');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- funnel's TRANSFORM_FAILED lane fills (design section 5 / section 7).
            -- SQLERRM captured into a local first: it is not a valid SQL identifier
            -- inside the INSERT..SELECT below, only in PL/SQL scope.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Grants', 'Award References', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_GMS_AWD_REFERENCES_STG_TBL s
                WHERE  (
                        (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW','RETRY'))
                        OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
                        OR (p_run_mode = 'ALL')
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_GMS_AWD_REFERENCES_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Award References');
                UPDATE DMT_GMS_AWD_REFERENCES_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Award References')
                AND    STG_STATUS IN ('NEW','RETRY','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_REFERENCES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_REFERENCES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_REFERENCES;

    -- ============================================================
    -- TRANSFORM_TERMS
    -- ============================================================
    PROCEDURE TRANSFORM_TERMS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix VARCHAR2(30);
        l_ok_count NUMBER := 0; l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM_TERMS start.', C_PKG, 'TRANSFORM_TERMS');
        l_prefix := get_prefix(p_run_id);

        -- On reprocess: clear staging errors for rows being retried
        IF p_reprocess_errors THEN
            UPDATE DMT_GMS_AWD_TERMS_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        -- Set-based INSERT: STG -> TFM (one statement, all qualifying rows)
        INSERT INTO DMT_GMS_AWD_TERMS_TFM_TBL (
                    STG_SEQUENCE_ID, RUN_ID,
                    AWARD_NUMBER, TERM_CATEGORY_NAME, TERM_NAME, TERM_DESCRIPTION, TERM_OPERAND, TERM_VALUE
        )
        SELECT
                    s.STG_SEQUENCE_ID, p_run_id,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.AWARD_NUMBER, 120), s.TERM_CATEGORY_NAME, s.TERM_NAME, s.TERM_DESCRIPTION, s.TERM_OPERAND, s.TERM_VALUE
        FROM DMT_GMS_AWD_TERMS_STG_TBL s
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
            SELECT 1 FROM DMT_GMS_AWD_TERMS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        ;

        l_ok_count := SQL%ROWCOUNT;

        -- Set-based UPDATE: mark transformed STG rows
        UPDATE DMT_GMS_AWD_TERMS_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_GMS_AWD_TERMS_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_TERMS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_TERMS');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- funnel's TRANSFORM_FAILED lane fills (design section 5 / section 7).
            -- SQLERRM captured into a local first: it is not a valid SQL identifier
            -- inside the INSERT..SELECT below, only in PL/SQL scope.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Grants', 'Award Terms', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_GMS_AWD_TERMS_STG_TBL s
                WHERE  (
                        (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW','RETRY'))
                        OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
                        OR (p_run_mode = 'ALL')
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_GMS_AWD_TERMS_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Award Terms');
                UPDATE DMT_GMS_AWD_TERMS_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Award Terms')
                AND    STG_STATUS IN ('NEW','RETRY','TRANSFORMED');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_TERMS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_TERMS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_TERMS;

END DMT_GRANTS_TRANSFORM_PKG;
/
