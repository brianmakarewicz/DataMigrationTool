-- PACKAGE BODY DMT_EGP_ITEM_RUNNER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_EGP_ITEM_RUNNER_PKG" AS
-- ============================================================
-- DMT_EGP_ITEM_RUNNER_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_EGP_ITEM_RUNNER_PKG';

    PROCEDURE RUN (
        p_run_id   IN NUMBER,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N'
    ) IS
        C_PROC        CONSTANT VARCHAR2(30) := 'RUN';
        l_reprocess   BOOLEAN := FALSE;
        l_fbdi_zip    BLOB;
        l_filename    VARCHAR2(200);
        l_fbdi_csv_id NUMBER;
        l_row_count   NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Items pipeline start. run_mode=' || p_run_mode
                                || ', scenario_id=' || NVL(TO_CHAR(p_scenario_id), '(none)')
                                || ', include_untagged=' || p_include_untagged,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        IF p_run_mode = 'FAILED' THEN
            l_reprocess := TRUE;
        END IF;

        -- Step 1: Pre-validate
        DMT_EGP_ITEM_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(
            p_run_id   => p_run_id,
            p_dependent_prefix => NULL
        );

        -- Step 2: Transform
        DMT_EGP_ITEM_TRANSFORM_PKG.TRANSFORM(
            p_run_id   => p_run_id,
            p_reprocess_errors => l_reprocess,
            p_scenario_id      => p_scenario_id,
            p_include_untagged => p_include_untagged,
            p_run_mode         => p_run_mode
        );

        -- Step 3: Post-validate
        DMT_EGP_ITEM_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(
            p_run_id => p_run_id
        );

        -- Step 4: Generate FBDI zip
        DMT_EGP_ITEM_FBDI_GEN_PKG.GENERATE_FBDI(
            p_run_id => p_run_id,
            x_fbdi_zip       => l_fbdi_zip,
            x_filename       => l_filename,
            x_fbdi_csv_id    => l_fbdi_csv_id
        );

        IF l_fbdi_zip IS NOT NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'FBDI zip generated: ' || l_filename
                                    || ', ' || DBMS_LOB.GETLENGTH(l_fbdi_zip)
                                    || ' bytes. Submitting to Fusion...',
                p_package        => C_PKG,
                p_procedure      => C_PROC);

            -- Step 5: Load to Fusion via FBDI and reconcile
            DMT_EGP_ITEM_RESULTS_PKG.LOAD_AND_RECONCILE(
                p_run_id => p_run_id,
                p_fbdi_zip       => l_fbdi_zip,
                p_filename       => l_filename
            );
        ELSE
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No rows to generate. Skipping FBDI submission.',
                p_package        => C_PKG,
                p_procedure      => C_PROC);
        END IF;

        COMMIT;

        SELECT COUNT(*) INTO l_row_count
        FROM   DMT_OWNER.DMT_EGP_ITEM_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Items pipeline complete. TFM rows: ' || l_row_count,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Items pipeline failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END RUN;

END DMT_EGP_ITEM_RUNNER_PKG;
/
