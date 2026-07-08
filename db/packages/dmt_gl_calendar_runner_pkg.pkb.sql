-- PACKAGE BODY DMT_GL_CALENDAR_RUNNER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GL_CALENDAR_RUNNER_PKG" AS
-- ============================================================
-- DMT_GL_CALENDAR_RUNNER_PKG Body
-- Orchestrates the full GL Calendar pipeline for one integration run.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_GL_CALENDAR_RUNNER_PKG';

    PROCEDURE RUN (
        p_run_id   IN NUMBER,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N'
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'RUN';
        l_reprocess  BOOLEAN := FALSE;
        l_fbl_zip    BLOB;
        l_filename   VARCHAR2(200);
        l_fbdi_csv_id NUMBER;
        l_row_count  NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'GL Calendar pipeline start. run_mode=' || p_run_mode
                                || ', scenario_id=' || NVL(TO_CHAR(p_scenario_id), '(none)')
                                || ', include_untagged=' || p_include_untagged,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        IF p_run_mode = 'FAILED' THEN
            l_reprocess := TRUE;
        END IF;

        -- Step 1: Pre-validate (upstream dependency check)
        DMT_GL_CALENDAR_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(
            p_run_id   => p_run_id,
            p_dependent_prefix => NULL
        );

        -- Step 2: Transform (STG -> TFM)
        DMT_GL_CALENDAR_TRANSFORM_PKG.TRANSFORM(
            p_run_id   => p_run_id,
            p_reprocess_errors => l_reprocess,
            p_scenario_id      => p_scenario_id,
            p_include_untagged => p_include_untagged,
            p_run_mode         => p_run_mode
        );

        -- Step 3: Post-validate
        DMT_GL_CALENDAR_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(
            p_run_id => p_run_id
        );

        -- Step 4: Generate FBL zip
        DMT_GL_CALENDAR_FBL_GEN_PKG.GENERATE_FBL(
            p_run_id => p_run_id,
            x_fbl_zip        => l_fbl_zip,
            x_filename       => l_filename,
            x_fbdi_csv_id    => l_fbdi_csv_id
        );

        IF l_fbl_zip IS NOT NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'FBL zip generated: ' || l_filename
                                    || ', ' || DBMS_LOB.GETLENGTH(l_fbl_zip)
                                    || ' bytes.',
                p_package        => C_PKG,
                p_procedure      => C_PROC);
        ELSE
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No rows to generate.',
                p_package        => C_PKG,
                p_procedure      => C_PROC);
        END IF;

        COMMIT;

        -- Step 5: Log manual setup requirement
        DMT_GL_CALENDAR_RESULTS_PKG.RECONCILE_BATCH(
            p_run_id => p_run_id
        );

        -- Final counts
        SELECT COUNT(*) INTO l_row_count
        FROM   DMT_OWNER.DMT_GL_CALENDAR_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'GL Calendar pipeline complete. TFM rows: ' || l_row_count
                                || '. No automated load available; manual setup required via '
                                || 'Setup and Maintenance > Manage Accounting Calendars.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'GL Calendar pipeline failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END RUN;

END DMT_GL_CALENDAR_RUNNER_PKG;
/
