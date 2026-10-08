-- PACKAGE BODY DMT_PROJECT_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PROJECT_VALIDATOR_PKG" 
AS
-- ============================================================
-- DMT_PROJECT_VALIDATOR_PKG body
-- Projects pre- and post-transform validation.
-- Projects are top-level master data with no upstream dependencies.
-- Both procedures are stubs — validation can be added later
-- without changing the orchestration.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_PROJECT_VALIDATOR_PKG';

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Stub: projects have no upstream dependencies.
    -- Future: could check for duplicate PROJECT_NUMBER, etc.
    -- --------------------------------------------------------
    -- ============================================================
    -- FLAG_STG_FAILED — STANDARD helper (design §7). Marks every STG row FAILED
    -- (status only, no message) that has a DMT_STG_TFM_ERROR_TBL row for this run.
    -- The pre-validation checks above record WHY in the error table; this sets the
    -- STG status so FAILED-mode reruns select on it. Byte-identical across validator
    -- packages except the STG table name(s) and the SUB_OBJECT filter (tagged EDIT
    -- regions), like SWEEP_UNACCOUNTED. Does NOT commit — the caller owns the txn.
    -- ============================================================
    PROCEDURE FLAG_STG_FAILED (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL) IS
    BEGIN
        -- <<EDIT-TABLE — the object's STG table. Repeat this whole UPDATE block
        --   (EDIT-TABLE through the ';') once per STG table the object owns.>>
        UPDATE DMT_PJF_PROJECTS_STG_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-SCOPE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — this table's SUB_OBJECT>>
                                   AND SUB_OBJECT = 'Projects'
        -- <<END EDIT-SCOPE — nothing below this changes>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_PJF_TASKS_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Project Tasks'
        -- <<END EDIT-SCOPE>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_PJF_TEAM_MEMBERS_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Team Members'
        -- <<END EDIT-SCOPE>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_PJC_TXN_CONTROLS_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Txn Controls'
        -- <<END EDIT-SCOPE>>
                                  );
    END FLAG_STG_FAILED;

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id       IN NUMBER   DEFAULT NULL,
        p_run_mode        IN VARCHAR2 DEFAULT 'NEW'
    )
    IS
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM start. No upstream dependencies for Projects.',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

        -- Orphan-task check. A task whose PROJECT_NUMBER has no project header
        -- in the same source (scenario) is an orphan: Fusion never produces a
        -- per-row verdict for it because there is no parent project to import it
        -- under, so it would otherwise land UNACCOUNTED. Reject it HERE, before
        -- transform, as an honest OUR-side pre-validation failure — never at
        -- reconcile time as a fabricated Fusion outcome. Record the reason in the
        -- error table; the [PRE_VALIDATION] exclusion added to TRANSFORM_TASKS then
        -- keeps the orphan out of TFM in EVERY run mode. The accounting gate counts
        -- only TFM rows, so the excluded orphan is not unaccounted; the funnel view
        -- surfaces it as PREVALIDATION_FAILED.
        --
        -- The check is scoped by SCENARIO_ID and selects rows with the shared
        -- run-mode predicate (STG_ROW_SELECTED), never a literal 'NEW': ALL-mode
        -- runs reuse the same write-once STG rows (already TRANSFORMED from a
        -- prior run), so a NEW filter would never fire in regression, while ALL
        -- selects the whole scenario. The parent-existence subquery correlates on SCENARIO_ID so a
        -- task is judged against projects in its own batch only (mirrors the
        -- Customers batch-parent check).
        --
        -- Config flag PROJECT_ALLOW_EXTERNAL_PARENT (default N) relaxes the batch
        -- scoping for incremental migrations. When Y, a task is ALSO spared when its
        -- parent project was already loaded to Fusion by an earlier DMT run — proven
        -- by a prior LOADED Projects TFM row for that PROJECT_NUMBER, the same
        -- DMT-side evidence DMT_XREF_PKG uses to resolve cross-object references.
        -- A true orphan (parent neither in the batch nor previously loaded) is still
        -- rejected under either setting. When N, behavior is unchanged: batch-only.
        DECLARE
            l_orphans            NUMBER;
            -- 'Y' when the flag is on; any other value keeps the strict batch-only
            -- check. A VARCHAR2 (not a PL/SQL BOOLEAN) so it can be a SQL bind below.
            l_allow_ext_parent   VARCHAR2(1) :=
                NVL(DMT_UTIL_PKG.GET_CONFIG('PROJECT_ALLOW_EXTERNAL_PARENT'), 'N');
        BEGIN
            INSERT INTO DMT_STG_TFM_ERROR_TBL
                   (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
            SELECT p_run_id, 'Projects', 'Project Tasks', t.STG_SEQUENCE_ID,
                   '[PRE_VALIDATION] Parent project ''' || t.PROJECT_NUMBER ||
                   ''' is not present in this source — orphan task skipped.'
            FROM   DMT_PJF_TASKS_STG_TBL t
            WHERE  t.PROJECT_NUMBER IS NOT NULL
            AND    DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, t.STG_STATUS, p_run_id, 'DMT_PJF_TASKS_STG_TBL', t.STG_SEQUENCE_ID) = 'Y'
            AND    (p_scenario_id IS NULL OR t.SCENARIO_ID = p_scenario_id)
            AND    NOT EXISTS (
                       SELECT 1 FROM DMT_PJF_PROJECTS_STG_TBL p
                       WHERE  p.PROJECT_NUMBER = t.PROJECT_NUMBER
                       AND    (p.SCENARIO_ID = t.SCENARIO_ID
                               OR (p.SCENARIO_ID IS NULL AND t.SCENARIO_ID IS NULL))
                   )
            -- Flag ON ('Y'): also spare the task if its parent project already exists
            -- in Fusion from an earlier run (a prior LOADED Projects TFM row). Flag
            -- OFF: the l_allow_ext_parent = 'Y' guard is false, the OR short-circuits
            -- to FALSE, and the strict batch-only check stands unchanged.
            AND    NOT (l_allow_ext_parent = 'Y' AND EXISTS (
                       SELECT 1
                       FROM   DMT_PJF_PROJECTS_STG_TBL ps
                       JOIN   DMT_PJF_PROJECTS_TFM_TBL pt
                              ON pt.STG_SEQUENCE_ID = ps.STG_SEQUENCE_ID
                       WHERE  ps.PROJECT_NUMBER = t.PROJECT_NUMBER
                       AND    pt.TFM_STATUS = 'LOADED'
                   ))
            -- Idempotent: do not double-write this run's error if pre-validation
            -- is invoked more than once for the same run.
            AND    NOT EXISTS (
                       SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                       WHERE  e.RUN_ID = p_run_id
                       AND    e.STG_SEQUENCE_ID = t.STG_SEQUENCE_ID
                       AND    e.SUB_OBJECT = 'Project Tasks'
                   );
            l_orphans := SQL%ROWCOUNT;

            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message => 'VALIDATE_PRE_TRANSFORM: ' || l_orphans ||
                             ' orphan task(s) rejected (parent project absent).',
                p_package => C_PKG,
                p_procedure => 'VALIDATE_PRE_TRANSFORM');
        END;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM complete.',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');


        -- Standard final step: flag the STG rows FAILED from the recorded error
        -- rows (status only, no message) so FAILED-mode reruns select on them (§7).
        FLAG_STG_FAILED(p_run_id, p_scenario_id);
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
    -- Stub: no post-transform rules implemented yet.
    -- Future: check required fields, date ranges, etc.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
    BEGIN
        -- No post-transform validations implemented yet.
        -- Future: check PROJECT_START_DATE <= PROJECT_FINISH_DATE,
        -- required fields like ORGANIZATION_NAME, etc.
        NULL;
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

END DMT_PROJECT_VALIDATOR_PKG;
/
