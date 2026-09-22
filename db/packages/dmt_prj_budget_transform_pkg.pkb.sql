-- PACKAGE BODY DMT_PRJ_BUDGET_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PRJ_BUDGET_TRANSFORM_PKG" AS

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_PRJ_BUDGET_TRANSFORM_PKG';

    PROCEDURE TRANSFORM (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok         NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM start.', C_PKG, 'TRANSFORM');

        INSERT INTO DMT_PRJ_BUDGET_TFM_TBL (
            STG_SEQUENCE_ID, RUN_ID,
            AWARD_NUMBER, FINANCIAL_PLAN_TYPE, PROJECT_NUMBER, PROJECT_NAME,
            TASK_NAME, TASK_NUMBER,
            PLAN_VERSION_NAME, PLAN_VERSION_DESCRIPTION, PLAN_VERSION_STATUS,
            RESOURCE_NAME, PERIOD_NAME, PLANNING_CURRENCY,
            TOTAL_QUANTITY, TOTAL_TC_RAW_COST, TOTAL_TC_REVENUE,
            SRC_BUDGET_LINE_REFERENCE,
            FUNDING_SOURCE_NUMBER, FUNDING_SOURCE_NAME,
            PC_RAW_COST, PC_REVENUE, PFC_RAW_COST, PFC_REVENUE,
            TOTAL_TC_BRDND_COST, PC_BRDND_COST, PFC_BRDND_COST,
            LINE_TYPE, PLANNING_START_DATE, PLANNING_END_DATE,
            ATTRIBUTE_CATEGORY,
            ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5,
            ATTRIBUTE6, ATTRIBUTE7, ATTRIBUTE8, ATTRIBUTE9, ATTRIBUTE10,
            ATTRIBUTE11, ATTRIBUTE12, ATTRIBUTE13, ATTRIBUTE14, ATTRIBUTE15,
            ATTRIBUTE16, ATTRIBUTE17, ATTRIBUTE18, ATTRIBUTE19, ATTRIBUTE20,
            ATTRIBUTE21, ATTRIBUTE22, ATTRIBUTE23, ATTRIBUTE24, ATTRIBUTE25,
            ATTRIBUTE26, ATTRIBUTE27, ATTRIBUTE28, ATTRIBUTE29, ATTRIBUTE30,
            PLAN_VERSION_NUMBER, PROCESSING_MODE,
            TFM_STATUS
        )
        SELECT
            s.STG_SEQUENCE_ID, p_run_id,
            s.AWARD_NUMBER, s.FINANCIAL_PLAN_TYPE,
            DMT_XREF_PKG.PROJECT_NUMBER(s.PROJECT_NUMBER),
            DMT_XREF_PKG.PROJECT_NAME(s.PROJECT_NAME),
            s.TASK_NAME, DMT_XREF_PKG.TASK_NUMBER(s.TASK_NUMBER),
            s.PLAN_VERSION_NAME, s.PLAN_VERSION_DESCRIPTION, s.PLAN_VERSION_STATUS,
            s.RESOURCE_NAME, s.PERIOD_NAME, s.PLANNING_CURRENCY,
            s.TOTAL_QUANTITY, s.TOTAL_TC_RAW_COST, s.TOTAL_TC_REVENUE,
            s.SRC_BUDGET_LINE_REFERENCE,
            s.FUNDING_SOURCE_NUMBER, s.FUNDING_SOURCE_NAME,
            s.PC_RAW_COST, s.PC_REVENUE, s.PFC_RAW_COST, s.PFC_REVENUE,
            s.TOTAL_TC_BRDND_COST, s.PC_BRDND_COST, s.PFC_BRDND_COST,
            s.LINE_TYPE, s.PLANNING_START_DATE, s.PLANNING_END_DATE,
            s.ATTRIBUTE_CATEGORY,
            s.ATTRIBUTE1, s.ATTRIBUTE2, s.ATTRIBUTE3, s.ATTRIBUTE4, s.ATTRIBUTE5,
            s.ATTRIBUTE6, s.ATTRIBUTE7, s.ATTRIBUTE8, s.ATTRIBUTE9, s.ATTRIBUTE10,
            s.ATTRIBUTE11, s.ATTRIBUTE12, s.ATTRIBUTE13, s.ATTRIBUTE14, s.ATTRIBUTE15,
            s.ATTRIBUTE16, s.ATTRIBUTE17, s.ATTRIBUTE18, s.ATTRIBUTE19, s.ATTRIBUTE20,
            s.ATTRIBUTE21, s.ATTRIBUTE22, s.ATTRIBUTE23, s.ATTRIBUTE24, s.ATTRIBUTE25,
            s.ATTRIBUTE26, s.ATTRIBUTE27, s.ATTRIBUTE28, s.ATTRIBUTE29, s.ATTRIBUTE30,
            s.PLAN_VERSION_NUMBER, s.PROCESSING_MODE,
            'STAGED'
        FROM   DMT_PRJ_BUDGET_STG_TBL s
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND s.STG_STATUS IN ('NEW', 'RETRY'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        -- Honor pre-validation rejections in EVERY run mode (ALL-mode-bypass backlog
        -- item). FAILED mode selects STG_STATUS='FAILED', which is exactly the status a
        -- validator-rejected row carries, so without this a rejected budget (project not
        -- loaded) would be transformed. Scope to this object's SUB_OBJECT since
        -- STG_SEQUENCE_ID restarts per STG table.
        AND NOT EXISTS (
            SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID          = p_run_id
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    e.SUB_OBJECT      = 'Project Budgets'
            AND    e.ERROR_TEXT LIKE '[PRE_VALIDATION]%'
        );

        l_ok := SQL%ROWCOUNT;

        -- ============================================================
        -- Contract v1 RECON_KEY stamp (single-tier reader coupling).
        -- The shared reconciler matches each report row's RECORD_KEY to the TFM
        -- row's RECON_KEY. The ProjectBudgets recon data model
        -- (bip/ProjectBudgets/PRJ_BUDGET_DM.xdm) emits, on the BASE tier,
        --   RECORD_KEY = NVL(PJO_PLAN_VERSIONS_B.PM_BUDGET_REFERENCE,
        --                    <synthetic project::version::plan_version_id>)
        -- and, on the INTERFACE tier,
        --   RECORD_KEY = NVL(PJO_PLAN_VERSIONS_XFACE.SRC_BUDGET_LINE_REFERENCE,
        --                    <synthetic project_number::plan_version_name>).
        -- The native source budget line reference (SRC_BUDGET_LINE_REFERENCE)
        -- survives verbatim onto the base plan-version row as PM_BUDGET_REFERENCE
        -- (verified live: values like ENDOW001-01 persist unchanged). The
        -- transform prefixes PROJECT_NUMBER / PROJECT_NAME only and copies
        -- SRC_BUDGET_LINE_REFERENCE through unchanged, so the value this TFM row
        -- carries in SRC_BUDGET_LINE_REFERENCE is byte-for-byte the DM's
        -- RECORD_KEY whenever the source ref is present. RECON_KEY is therefore
        -- set equal to SRC_BUDGET_LINE_REFERENCE here. When the source ref is
        -- null the DM falls back to a Fusion-side synthetic key (built from the
        -- Fusion-assigned PLAN_VERSION_ID, which we cannot know pre-load), so
        -- such a row keeps a null RECON_KEY and is honestly left for the sweep
        -- rather than force-matched. Only newly-stamped rows (RECON_KEY IS NULL)
        -- for this run are touched, so a rerun never disturbs rows already
        -- carrying a key.
        -- ============================================================
        UPDATE DMT_PRJ_BUDGET_TFM_TBL
        SET    RECON_KEY = SRC_BUDGET_LINE_REFERENCE
        WHERE  RUN_ID = p_run_id
        AND    RECON_KEY IS NULL;

        UPDATE DMT_PRJ_BUDGET_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STG_STATUS IN ('NEW', 'RETRY'))
          )
        AND (p_scenario_id IS NULL
             OR SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL))
        -- This TRANSFORMED-marking UPDATE is NOT guarded by an EXISTS(TFM row) check
        -- (unlike the other 8 objects), so it needs the same pre-validation exclusion:
        -- otherwise a rejected FAILED row that never entered TFM would still be marked
        -- TRANSFORMED. (ALL-mode-bypass backlog item.)
        AND NOT EXISTS (
            SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID          = p_run_id
            AND    e.STG_SEQUENCE_ID = DMT_PRJ_BUDGET_STG_TBL.STG_SEQUENCE_ID
            AND    e.SUB_OBJECT      = 'Project Budgets'
            AND    e.ERROR_TEXT LIKE '[PRE_VALIDATION]%'
        );

        DMT_UTIL_PKG.LOG(p_run_id, 'TRANSFORM complete. Rows: ' || l_ok, C_PKG, 'TRANSFORM');
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'TRANSFORM failed.', SQLERRM, C_PKG, 'TRANSFORM');
            RAISE;
    END TRANSFORM;

END DMT_PRJ_BUDGET_TRANSFORM_PKG;
/
