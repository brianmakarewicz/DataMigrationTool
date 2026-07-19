-- PACKAGE BODY DMT_PRJ_BUDGET_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PRJ_BUDGET_VALIDATOR_PKG" 
AS
-- ============================================================
-- DMT_PRJ_BUDGET_VALIDATOR_PKG body
-- Project Budgets pre- and post-transform validation.
-- Upstream dependency: PROJECT_NAME must be LOADED in projects STG.
--
-- Pre-validation rejections are recorded in the run-stamped error table
-- DMT_OWNER.DMT_STG_TFM_ERROR_TBL (design §7); the STG rows keep their
-- status only (no message) and are flagged FAILED afterwards by the
-- standard FLAG_STG_FAILED helper. No validator writes ERROR_TEXT on a
-- *_STG_TBL row. (Post-transform checks below tag the TFM tier, not STG.)
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_PRJ_BUDGET_VALIDATOR_PKG';

    -- ============================================================
    -- FLAG_STG_FAILED — STANDARD helper (design §7). Marks every STG row FAILED
    -- (status only, no message) that has a DMT_STG_TFM_ERROR_TBL row for this run.
    -- The pre-validation checks record WHY in the error table; this sets the STG
    -- status so FAILED-mode reruns select on it. Byte-identical across validator
    -- packages except the STG table name(s) and the SUB_OBJECT filter (tagged EDIT
    -- regions), like SWEEP_UNACCOUNTED. Does NOT commit — the caller owns the txn.
    -- ============================================================
    PROCEDURE FLAG_STG_FAILED (p_run_id IN NUMBER) IS
    BEGIN
        -- <<EDIT-TABLE — the object's STG table. Repeat this whole UPDATE block
        --   (EDIT-TABLE through the ';') once per STG table the object owns.>>
        UPDATE DMT_OWNER.DMT_PRJ_BUDGET_STG_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-SCOPE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — this table's SUB_OBJECT>>
                                   AND SUB_OBJECT = 'Project Budgets'
        -- <<END EDIT-SCOPE — nothing below this changes>>
                                  );
    END FLAG_STG_FAILED;

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Upstream dependency: PROJECT_NAME must match a LOADED project.
    -- For migrated projects: PROJECT_NAME must exist in
    --   DMT_PJF_PROJECTS_STG_TBL with STG_STATUS='LOADED'.
    -- STG holds raw (unprefixed) values, so the match is raw-to-raw
    -- (same pattern as DMT_EXPENDITURE_VALIDATOR_PKG); the TFM table
    -- holds PREFIXED names and must not be used here.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL
    )
    IS
        l_dep_prefix   VARCHAR2(30);
        l_failed       NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM start. dep_prefix=' ||
                                NVL(p_dependent_prefix, '(from CONVERSION_MASTER)'),
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

        -- Resolve dependent prefix
        IF p_dependent_prefix IS NOT NULL THEN
            l_dep_prefix := p_dependent_prefix;
        ELSE
            SELECT PREFIX
            INTO   l_dep_prefix
            FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
            WHERE  RUN_ID = p_run_id;
        END IF;

        -- Check PROJECT_NAME upstream dependency.
        -- Only enforced when projects have been migrated (at least one LOADED row exists).
        DECLARE
            l_any_loaded NUMBER;
        BEGIN
            -- LOADED is a TFM-only status (STG never carries it, design §5), so the
            -- "have projects migrated?" gate reads the projects TFM table.
            SELECT COUNT(*) INTO l_any_loaded
            FROM   DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
            WHERE  TFM_STATUS = 'LOADED' AND ROWNUM = 1;

            IF l_any_loaded > 0 AND DMT_UTIL_PKG.GET_CONFIG('VALIDATE_UPSTREAM_DEPS') = 'Y' THEN
                INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'ProjectBudgets', 'Project Budgets', e.STG_SEQUENCE_ID,
                       '[PRE_VALIDATION] Project ''' || e.PROJECT_NAME ||
                       ''' is not loaded — budget record skipped.'
                FROM   DMT_OWNER.DMT_PRJ_BUDGET_STG_TBL e
                WHERE  e.STG_STATUS IN ('NEW', 'RETRY')
                AND    e.PROJECT_NAME IS NOT NULL
                AND    NOT EXISTS (
                           SELECT 1
                           FROM   DMT_OWNER.DMT_PJF_PROJECTS_STG_TBL p
                           JOIN   DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL pt
                                  ON pt.STG_SEQUENCE_ID = p.STG_SEQUENCE_ID
                           WHERE  p.PROJECT_NAME = e.PROJECT_NAME
                           AND    pt.TFM_STATUS  = 'LOADED'
                       );
                l_failed := SQL%ROWCOUNT;

                -- Standard final step: flag the STG rows FAILED from the recorded
                -- error rows (status only, no message) so FAILED-mode reruns select
                -- on them (§7).
                FLAG_STG_FAILED(p_run_id);
            END IF;
        END;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM complete. Pre-validation failures: ' || l_failed,
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_PRE_TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_PRE_TRANSFORM');
            RAISE;
    END VALIDATE_PRE_TRANSFORM;


    -- --------------------------------------------------------
    -- VALIDATE_POST_TRANSFORM
    -- Check required fields on TFM rows: FINANCIAL_PLAN_TYPE,
    -- PROJECT_NAME, PLAN_VERSION_NAME must be NOT NULL.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
        l_failed NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM start.',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_POST_TRANSFORM');

        -- FINANCIAL_PLAN_TYPE is required
        UPDATE DMT_OWNER.DMT_PRJ_BUDGET_TFM_TBL
        SET    TFM_STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[POST_VALIDATION] FINANCIAL_PLAN_TYPE is required and cannot be blank.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'STAGED'
        AND    FINANCIAL_PLAN_TYPE IS NULL;
        l_failed := l_failed + SQL%ROWCOUNT;

        -- PROJECT_NAME is required
        UPDATE DMT_OWNER.DMT_PRJ_BUDGET_TFM_TBL
        SET    TFM_STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[POST_VALIDATION] PROJECT_NAME is required and cannot be blank.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS IN ('STAGED', 'FAILED')
        AND    PROJECT_NAME IS NULL;
        l_failed := l_failed + SQL%ROWCOUNT;

        -- PLAN_VERSION_NAME is required
        UPDATE DMT_OWNER.DMT_PRJ_BUDGET_TFM_TBL
        SET    TFM_STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[POST_VALIDATION] PLAN_VERSION_NAME is required and cannot be blank.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS IN ('STAGED', 'FAILED')
        AND    PLAN_VERSION_NAME IS NULL;
        l_failed := l_failed + SQL%ROWCOUNT;

        -- SRC_BUDGET_LINE_REFERENCE is required (used as BIP reconciliation match key)
        UPDATE DMT_OWNER.DMT_PRJ_BUDGET_TFM_TBL
        SET    TFM_STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[POST_VALIDATION] SRC_BUDGET_LINE_REFERENCE is required — used as the reconciliation match key.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS IN ('STAGED', 'FAILED')
        AND    SRC_BUDGET_LINE_REFERENCE IS NULL;
        l_failed := l_failed + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM complete. Post-validation failures: ' || l_failed,
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_POST_TRANSFORM');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_POST_TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_POST_TRANSFORM');
            RAISE;
    END VALIDATE_POST_TRANSFORM;

END DMT_PRJ_BUDGET_VALIDATOR_PKG;
/
