-- PACKAGE BODY DMT_CE_BANK_RUNNER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CE_BANK_RUNNER_PKG" AS
-- ============================================================
-- DMT_CE_BANK_RUNNER_PKG Body
-- Orchestrates the full CE Bank/Branch/Account pipeline.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_CE_BANK_RUNNER_PKG';

    PROCEDURE RUN (
        p_run_id   IN NUMBER,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N'
    ) IS
        C_PROC          CONSTANT VARCHAR2(30) := 'RUN';
        l_reprocess     BOOLEAN := FALSE;
        l_bank_count    NUMBER;
        l_branch_count  NUMBER;
        l_acct_count    NUMBER;
        l_gen_count     NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'CE Bank pipeline start. run_mode=' || p_run_mode,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        IF p_run_mode = 'FAILED' THEN
            l_reprocess := TRUE;
        END IF;

        -- Step 1: Pre-validate (upstream dependency check — stub)
        DMT_CE_BANK_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(
            p_run_id   => p_run_id,
            p_dependent_prefix => NULL,
            p_scenario_id      => p_scenario_id,
            p_run_mode         => p_run_mode
        );

        -- Step 2: Transform banks (STG -> TFM)
        DMT_CE_BANK_TRANSFORM_PKG.TRANSFORM_BANKS(
            p_run_id   => p_run_id,
            p_reprocess_errors => l_reprocess,
            p_scenario_id      => p_scenario_id,
            p_include_untagged => p_include_untagged,
            p_run_mode         => p_run_mode
        );

        -- Step 3: Transform branches (STG -> TFM)
        DMT_CE_BANK_TRANSFORM_PKG.TRANSFORM_BRANCHES(
            p_run_id   => p_run_id,
            p_reprocess_errors => l_reprocess,
            p_scenario_id      => p_scenario_id,
            p_include_untagged => p_include_untagged,
            p_run_mode         => p_run_mode
        );

        -- Step 4: Transform accounts (STG -> TFM)
        DMT_CE_BANK_TRANSFORM_PKG.TRANSFORM_ACCOUNTS(
            p_run_id   => p_run_id,
            p_reprocess_errors => l_reprocess,
            p_scenario_id      => p_scenario_id,
            p_include_untagged => p_include_untagged,
            p_run_mode         => p_run_mode
        );

        -- Step 5: Post-validate (orphan branch + orphan account checks)
        DMT_CE_BANK_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(
            p_run_id => p_run_id
        );

        -- Step 6: Generate. This object loads to Fusion over the Cash Management
        -- REST resources (cashBanks / cashBankBranches / cashBankAccounts), not a
        -- flat file, so "generate" no longer builds an FBL zip (the old
        -- DMT_CE_BANK_FBL_GEN_PKG is retired, backlog #39). It simply promotes the
        -- STAGED TFM rows of all three tiers to GENERATED -- the state the REST
        -- load step (DMT_CE_BANK_RESULTS_PKG) consumes.
        UPDATE DMT_CE_BANK_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        UPDATE DMT_CE_BRANCH_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        UPDATE DMT_CE_BANK_ACCT_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        -- Step 7: Load to Fusion via REST and reconcile against the base tables.
        -- Gate on the presence of GENERATED TFM rows across the three tiers (the
        -- old gate was "an FBL zip was built", which no longer applies).
        SELECT COUNT(*) INTO l_gen_count
        FROM   (SELECT 1 FROM DMT_CE_BANK_TFM_TBL      WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                UNION ALL
                SELECT 1 FROM DMT_CE_BRANCH_TFM_TBL    WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED'
                UNION ALL
                SELECT 1 FROM DMT_CE_BANK_ACCT_TFM_TBL WHERE RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED');

        IF l_gen_count > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'Generated ' || l_gen_count
                                    || ' TFM rows for REST load (banks/branches/accounts).',
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            DMT_CE_BANK_RESULTS_PKG.LOAD_AND_RECONCILE(
                p_run_id => p_run_id
            );
        ELSE
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No rows to generate; skipping REST load.',
                p_package        => C_PKG,
                p_procedure      => C_PROC);
        END IF;

        COMMIT;

        -- Final counts
        SELECT COUNT(*) INTO l_bank_count
        FROM   DMT_CE_BANK_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        SELECT COUNT(*) INTO l_branch_count
        FROM   DMT_CE_BRANCH_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        SELECT COUNT(*) INTO l_acct_count
        FROM   DMT_CE_BANK_ACCT_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'CE Bank pipeline complete. Banks: ' || l_bank_count
                                || ', Branches: ' || l_branch_count
                                || ', Accounts: ' || l_acct_count,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'CE Bank pipeline failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END RUN;

    -- ============================================================
    -- RUN_STANDARD - queue-dispatch entry point (EXEC contract, LOCAL mode).
    -- The scheduler calls this with named notation
    -- (p_run_id, p_scenario_name, p_run_mode, p_skip_bu_refresh => TRUE).
    -- Resolves the scenario name to its id and delegates to RUN so STG selection
    -- is scoped to the run's scenario (STG accumulates across scenarios on the
    -- shared DB). p_skip_bu_refresh is accepted for contract conformance and
    -- ignored (CashBanks has no business-unit refresh).
    -- ============================================================
    PROCEDURE RUN_STANDARD (
        p_run_id          IN NUMBER,
        p_scenario_name   IN VARCHAR2 DEFAULT NULL,
        p_run_mode        IN VARCHAR2 DEFAULT 'NEW',
        p_skip_bu_refresh IN BOOLEAN  DEFAULT FALSE
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RUN_STANDARD';
        l_scenario_id NUMBER;
        l_err_code    NUMBER;
    BEGIN
        DMT_UTIL_PKG.GET_OR_CREATE_SCENARIO(
            p_scenario_name => p_scenario_name,
            x_scenario_id   => l_scenario_id,
            x_error_code    => l_err_code);

        IF l_err_code != DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20101,
                'RUN_STANDARD: could not resolve scenario "' ||
                NVL(p_scenario_name, '(null)') || '" (detail in DMT_LOG_TBL).');
        END IF;

        -- Fail closed: a supplied scenario name must resolve to an id. A NULL id
        -- would silently widen every STG selection to ALL scenarios.
        IF p_scenario_name IS NOT NULL AND l_scenario_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20101,
                'RUN_STANDARD: scenario "' || p_scenario_name ||
                '" resolved to no SCENARIO_ID; refusing to run unscoped.');
        END IF;

        RUN(
            p_run_id           => p_run_id,
            p_run_mode         => p_run_mode,
            p_scenario_id      => l_scenario_id,
            p_include_untagged => 'N');
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id  => p_run_id,
                p_message => 'RUN_STANDARD failed.',
                p_sqlerrm => SQLERRM,
                p_package => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END RUN_STANDARD;

END DMT_CE_BANK_RUNNER_PKG;
/
