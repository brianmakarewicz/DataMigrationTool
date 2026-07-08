-- PACKAGE BODY DMT_CE_BANK_RUNNER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CE_BANK_RUNNER_PKG" AS
-- ============================================================
-- DMT_CE_BANK_RUNNER_PKG Body
-- Orchestrates the full CE Bank/Branch/Account pipeline.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_CE_BANK_RUNNER_PKG';

    PROCEDURE RUN (
        p_run_id   IN NUMBER,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        C_PROC          CONSTANT VARCHAR2(30) := 'RUN';
        l_reprocess     BOOLEAN := FALSE;
        l_fbl_zip       BLOB;
        l_filename      VARCHAR2(200);
        l_fbdi_csv_id   NUMBER;
        l_bank_count    NUMBER;
        l_branch_count  NUMBER;
        l_acct_count    NUMBER;
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
            p_dependent_prefix => NULL
        );

        -- Step 2: Transform banks (STG -> TFM)
        DMT_CE_BANK_TRANSFORM_PKG.TRANSFORM_BANKS(
            p_run_id   => p_run_id,
            p_reprocess_errors => l_reprocess,
            p_run_mode         => p_run_mode
        );

        -- Step 3: Transform branches (STG -> TFM)
        DMT_CE_BANK_TRANSFORM_PKG.TRANSFORM_BRANCHES(
            p_run_id   => p_run_id,
            p_reprocess_errors => l_reprocess,
            p_run_mode         => p_run_mode
        );

        -- Step 4: Transform accounts (STG -> TFM)
        DMT_CE_BANK_TRANSFORM_PKG.TRANSFORM_ACCOUNTS(
            p_run_id   => p_run_id,
            p_reprocess_errors => l_reprocess,
            p_run_mode         => p_run_mode
        );

        -- Step 5: Post-validate (orphan branch + orphan account checks)
        DMT_CE_BANK_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(
            p_run_id => p_run_id
        );

        -- Step 6: Generate FBL zip
        DMT_CE_BANK_FBL_GEN_PKG.GENERATE_FBL(
            p_run_id => p_run_id,
            x_fbl_zip        => l_fbl_zip,
            x_filename       => l_filename,
            x_fbdi_csv_id    => l_fbdi_csv_id
        );

        IF l_fbl_zip IS NOT NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'FBL zip generated: ' || l_filename
                                    || ', ' || DBMS_LOB.GETLENGTH(l_fbl_zip) || ' bytes.',
                p_package        => C_PKG,
                p_procedure      => C_PROC);
        ELSE
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No rows to generate.',
                p_package        => C_PKG,
                p_procedure      => C_PROC);
        END IF;

        -- Step 7: Load to Fusion via REST and reconcile
        IF l_fbl_zip IS NOT NULL THEN
            DMT_CE_BANK_RESULTS_PKG.LOAD_AND_RECONCILE(
                p_run_id => p_run_id
            );
        END IF;

        COMMIT;

        -- Final counts
        SELECT COUNT(*) INTO l_bank_count
        FROM   DMT_OWNER.DMT_CE_BANK_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        SELECT COUNT(*) INTO l_branch_count
        FROM   DMT_OWNER.DMT_CE_BRANCH_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        SELECT COUNT(*) INTO l_acct_count
        FROM   DMT_OWNER.DMT_CE_BANK_ACCT_TFM_TBL
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

END DMT_CE_BANK_RUNNER_PKG;
/
