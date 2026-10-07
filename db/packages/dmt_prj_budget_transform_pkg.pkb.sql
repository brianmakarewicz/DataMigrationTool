-- PACKAGE BODY DMT_PRJ_BUDGET_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PRJ_BUDGET_TRANSFORM_PKG" AS
-- ============================================================
-- NAME:    DMT_PRJ_BUDGET_TRANSFORM_PKG
-- PURPOSE: STG->TFM transform for ProjectBudgets (PjoPlanVersionsXface.csv)
-- REVISIONS:
--  1.1  2026-10-07  Run prefix on SRC_BUDGET_LINE_REFERENCE + PLAN_VERSION_NAME; fit-guard fails, never truncates
--  1.2  2026-10-07  Pre-TFM exclusion matched on run + sub-object, not LIKE on the tag text
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_PRJ_BUDGET_TRANSFORM_PKG';

    -- Prefix-fit limits for the two per-run keys this transform prefixes.
    -- SRC_BUDGET_LINE_REFERENCE: PJO_PLAN_VERSIONS_XFACE.SRC_BUDGET_LINE_REFERENCE
    --   and PJO_PLAN_VERSIONS_B.PM_BUDGET_REFERENCE are both VARCHAR2(100)
    --   (verified live in Fusion all_tab_columns, 2026-10-07).
    -- PLAN_VERSION_NAME: PJO_PLAN_VERSIONS_XFACE.PLAN_VERSION_NAME is 900 bytes in
    --   Fusion; the binding limit is our own TFM column, VARCHAR2(240).
    -- A value that cannot carry the prefix within its limit FAILS the row with a
    -- [TRANSFORM_ERROR]; it is never truncated (truncation would collide keys).
    C_BUDGET_REF_MAX   CONSTANT PLS_INTEGER := 100;
    C_VERSION_NAME_MAX CONSTANT PLS_INTEGER := 240;
    C_SUB_OBJECT       CONSTANT VARCHAR2(30) := 'Project Budgets';

    PROCEDURE TRANSFORM (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok         NUMBER := 0;
        l_fail       NUMBER := 0;
        l_prefix     VARCHAR2(30);
        l_step       VARCHAR2(200);
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id    => p_run_id,
                         p_message   => 'TRANSFORM start.',
                         p_package   => C_PKG,
                         p_procedure => 'TRANSFORM');

        l_step := 'reading the run prefix for run ' || p_run_id;
        SELECT PREFIX
        INTO   l_prefix
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;

        -- Prefix-fit guard: the run prefix goes onto SRC_BUDGET_LINE_REFERENCE
        -- (and therefore RECON_KEY / Fusion PM_BUDGET_REFERENCE) and onto
        -- PLAN_VERSION_NAME. These are the only per-run unique keys when a budget
        -- is loaded onto an EXISTING Fusion project (e.g. CFIT022), so they must
        -- carry the prefix for the run to be identifiable in Fusion. A value that
        -- does not fit with the prefix fails here with a clear error; it is never
        -- truncated.
        l_step := 'recording prefix-fit [TRANSFORM_ERROR] rows';
        INSERT INTO DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'ProjectBudgets', C_SUB_OBJECT, s.STG_SEQUENCE_ID,
               '[TRANSFORM_ERROR] '
               || CASE WHEN LENGTH(l_prefix || s.SRC_BUDGET_LINE_REFERENCE) > C_BUDGET_REF_MAX
                       THEN 'SRC_BUDGET_LINE_REFERENCE "' || s.SRC_BUDGET_LINE_REFERENCE
                            || '" cannot carry run prefix ' || l_prefix || ': '
                            || LENGTH(l_prefix || s.SRC_BUDGET_LINE_REFERENCE)
                            || ' chars exceeds the Fusion limit of ' || C_BUDGET_REF_MAX || '. '
                  END
               || CASE WHEN LENGTH(l_prefix || s.PLAN_VERSION_NAME) > C_VERSION_NAME_MAX
                       THEN 'PLAN_VERSION_NAME "' || s.PLAN_VERSION_NAME
                            || '" cannot carry run prefix ' || l_prefix || ': '
                            || LENGTH(l_prefix || s.PLAN_VERSION_NAME)
                            || ' chars exceeds the limit of ' || C_VERSION_NAME_MAX || '. '
                  END
               || '(Not truncated, to avoid a key collision.)'
        FROM   DMT_PRJ_BUDGET_STG_TBL s
        WHERE  DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
        AND    (p_scenario_id IS NULL
                OR s.SCENARIO_ID = p_scenario_id
                OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    (LENGTH(l_prefix || s.SRC_BUDGET_LINE_REFERENCE) > C_BUDGET_REF_MAX
                OR LENGTH(l_prefix || s.PLAN_VERSION_NAME) > C_VERSION_NAME_MAX)
        AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                        WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                        AND   e.SUB_OBJECT = C_SUB_OBJECT);
        l_fail := SQL%ROWCOUNT;

        l_step := 'flagging prefix-fit failures FAILED on STG';
        UPDATE DMT_PRJ_BUDGET_STG_TBL
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id AND SUB_OBJECT = C_SUB_OBJECT)
        AND    STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));

        l_step := 'inserting STAGED TFM rows';
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
            -- Run prefix on the plan version name and the source budget line
            -- reference (always-use-prefix rule). Length already guarded above,
            -- so PREFIXED never truncates here.
            DMT_UTIL_PKG.PREFIXED(p_prefix  => l_prefix,
                                  p_value   => s.PLAN_VERSION_NAME,
                                  p_max_len => C_VERSION_NAME_MAX),
            s.PLAN_VERSION_DESCRIPTION, s.PLAN_VERSION_STATUS,
            s.RESOURCE_NAME, s.PERIOD_NAME, s.PLANNING_CURRENCY,
            s.TOTAL_QUANTITY, s.TOTAL_TC_RAW_COST, s.TOTAL_TC_REVENUE,
            DMT_UTIL_PKG.PREFIXED(p_prefix  => l_prefix,
                                  p_value   => s.SRC_BUDGET_LINE_REFERENCE,
                                  p_max_len => C_BUDGET_REF_MAX),
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
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        -- Honor pre-TFM rejections in EVERY run mode (ALL-mode-bypass backlog item):
        -- any DMT_STG_TFM_ERROR_TBL row for this run + this object's SUB_OBJECT
        -- ([PRE_VALIDATION] from the validator, [TRANSFORM_ERROR] from the prefix-fit
        -- guard above) keeps the row out of TFM. Matched on run + sub-object, not on
        -- the tag text (no LIKE on known codes). Scope to this object's SUB_OBJECT
        -- since STG_SEQUENCE_ID restarts per STG table.
        AND NOT EXISTS (
            SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID          = p_run_id
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    e.SUB_OBJECT      = C_SUB_OBJECT
        );

        l_ok := SQL%ROWCOUNT;

        -- ============================================================
        -- Contract v1 RECON_KEY stamp (single-tier reader coupling).
        -- The shared reconciler matches each report row's RECORD_KEY to the TFM
        -- row's RECON_KEY. The ProjectBudgets recon data model
        -- (bip/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V2_DM.xdm) emits, on the BASE tier,
        --   RECORD_KEY = NVL(PJO_PLAN_VERSIONS_B.PM_BUDGET_REFERENCE,
        --                    <synthetic project::version::plan_version_id>)
        -- and, on the INTERFACE tier,
        --   RECORD_KEY = NVL(PJO_PLAN_VERSIONS_XFACE.SRC_BUDGET_LINE_REFERENCE,
        --                    <synthetic project_number::plan_version_name>).
        -- The native source budget line reference (SRC_BUDGET_LINE_REFERENCE)
        -- survives verbatim onto the base plan-version row as PM_BUDGET_REFERENCE
        -- (verified live: 97101_KTM_PRJBUDGET01 persisted unchanged in the
        -- known-good replay). The transform PREFIXES SRC_BUDGET_LINE_REFERENCE
        -- with the run prefix (2026-10-07, known-good fix), so the value this TFM
        -- row carries is byte-for-byte the DM's RECORD_KEY and is unique per run
        -- even when the budget lands on an existing Fusion project. RECON_KEY is therefore
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
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
          )
        AND (p_scenario_id IS NULL
             OR SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL))
        -- This TRANSFORMED-marking UPDATE is NOT guarded by an EXISTS(TFM row) check
        -- (unlike the other 8 objects), so it needs the same pre-TFM exclusion:
        -- otherwise a rejected row that never entered TFM would still be marked
        -- TRANSFORMED. (ALL-mode-bypass backlog item.)
        AND NOT EXISTS (
            SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID          = p_run_id
            AND    e.STG_SEQUENCE_ID = DMT_PRJ_BUDGET_STG_TBL.STG_SEQUENCE_ID
            AND    e.SUB_OBJECT      = C_SUB_OBJECT
        );

        DMT_UTIL_PKG.LOG(p_run_id    => p_run_id,
                         p_message   => 'TRANSFORM complete. Rows: ' || l_ok
                                        || ' | prefix-fit failures: ' || l_fail,
                         p_package   => C_PKG,
                         p_procedure => 'TRANSFORM');
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
                SELECT p_run_id, 'ProjectBudgets', 'Project Budget Lines', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_PRJ_BUDGET_STG_TBL s
                WHERE  ( DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y' )
                AND    (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_PRJ_BUDGET_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Project Budget Lines');
                UPDATE DMT_PRJ_BUDGET_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Project Budget Lines')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(p_run_id    => p_run_id,
                                   p_message   => 'TRANSFORM failed at step: ' || l_step,
                                   p_sqlerrm   => SQLERRM,
                                   p_package   => C_PKG,
                                   p_procedure => 'TRANSFORM');
            RAISE;
    END TRANSFORM;

END DMT_PRJ_BUDGET_TRANSFORM_PKG;
/
