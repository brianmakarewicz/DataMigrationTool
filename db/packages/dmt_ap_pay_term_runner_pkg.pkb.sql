-- PACKAGE BODY DMT_AP_PAY_TERM_RUNNER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AP_PAY_TERM_RUNNER_PKG" AS
-- ============================================================
-- DMT_AP_PAY_TERM_RUNNER_PKG Body
-- Orchestrates the full Payment Terms pipeline for one run.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_AP_PAY_TERM_RUNNER_PKG';

    PROCEDURE RUN (
        p_run_id   IN NUMBER,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        C_PROC          CONSTANT VARCHAR2(30) := 'RUN';
        l_reprocess     BOOLEAN := FALSE;
        l_fbl_zip       BLOB;
        l_filename      VARCHAR2(200);
        l_fbdi_csv_id   NUMBER;
        l_hdr_count     NUMBER;
        l_line_count    NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'AP Payment Terms pipeline start. run_mode=' || p_run_mode,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        IF p_run_mode = 'FAILED' THEN
            l_reprocess := TRUE;
        END IF;

        -- Step 1: Pre-validate (upstream dependency check — stub)
        DMT_AP_PAY_TERM_VALIDATOR_PKG.VALIDATE_PRE_TRANSFORM(
            p_run_id   => p_run_id,
            p_dependent_prefix => NULL
        );

        -- Step 2: Transform headers (STG -> TFM)
        DMT_AP_PAY_TERM_TRANSFORM_PKG.TRANSFORM_HEADERS(
            p_run_id   => p_run_id,
            p_reprocess_errors => l_reprocess,
            p_run_mode         => p_run_mode
        );

        -- Step 3: Transform lines (STG -> TFM)
        DMT_AP_PAY_TERM_TRANSFORM_PKG.TRANSFORM_LINES(
            p_run_id   => p_run_id,
            p_reprocess_errors => l_reprocess,
            p_run_mode         => p_run_mode
        );

        -- Step 4: Post-validate (orphan line check)
        DMT_AP_PAY_TERM_VALIDATOR_PKG.VALIDATE_POST_TRANSFORM(
            p_run_id => p_run_id
        );

        -- Step 5: Generate FBL zip
        DMT_AP_PAY_TERM_FBL_GEN_PKG.GENERATE_FBL(
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

        -- Step 6: Load to Fusion via REST and reconcile
        IF l_fbl_zip IS NOT NULL THEN
            DMT_AP_PAY_TERM_RESULTS_PKG.LOAD_AND_RECONCILE(
                p_run_id => p_run_id
            );
        END IF;

        COMMIT;

        -- Final counts
        SELECT COUNT(*) INTO l_hdr_count
        FROM   DMT_OWNER.DMT_AP_PAY_TERM_HDR_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        SELECT COUNT(*) INTO l_line_count
        FROM   DMT_OWNER.DMT_AP_PAY_TERM_LINE_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'AP Payment Terms pipeline complete. Headers: ' || l_hdr_count
                                || ', Lines: ' || l_line_count,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'AP Payment Terms pipeline failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END RUN;

END DMT_AP_PAY_TERM_RUNNER_PKG;
/
