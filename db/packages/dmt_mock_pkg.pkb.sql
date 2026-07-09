-- PACKAGE BODY DMT_MOCK_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_MOCK_PKG"
AS
    C_PKG CONSTANT VARCHAR2(30) := 'DMT_MOCK_PKG';

    -- ============================================================
    -- mark_stage — write the marker row for one stage, then raise
    -- if the failure-injection config targets this object + stage.
    -- The raise carries the section-5 stage tag (when the tag table
    -- defines one for the stage) so the queue worker's ERROR_MESSAGE
    -- is tagged like a real pipeline error.
    -- ============================================================
    PROCEDURE mark_stage (
        p_run_id     IN NUMBER,
        p_cemli_code IN VARCHAR2,
        p_stage      IN VARCHAR2,
        p_error_tag  IN VARCHAR2
    ) IS
        l_fail_stage  VARCHAR2(100);
        l_fail_object VARCHAR2(100);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => 'DMT_MOCK ' || p_cemli_code || ' ' || p_stage || ' ran',
            p_log_type  => 'INFO',
            p_package   => C_PKG,
            p_procedure => p_stage);

        l_fail_stage  := NVL(DMT_UTIL_PKG.GET_CONFIG('MOCK_FAIL_STAGE'), 'NONE');
        l_fail_object := NVL(DMT_UTIL_PKG.GET_CONFIG('MOCK_FAIL_OBJECT'), 'MockObject');

        IF l_fail_stage = p_stage AND l_fail_object = p_cemli_code THEN
            RAISE_APPLICATION_ERROR(-20990,
                CASE WHEN p_error_tag IS NOT NULL THEN p_error_tag || ' ' END
                || 'DMT_MOCK injected failure at ' || p_stage
                || ' for ' || p_cemli_code || ' (MOCK_FAIL_STAGE=' || l_fail_stage || ')');
        END IF;
    END mark_stage;

    -- ============================================================
    -- run_mock — the shared data-phase stub: VALIDATE → TRANSFORM
    -- → GENERATE markers in order, then MOCK_ROW_COUNT rows written
    -- to DMT_MOCK_TFM_TBL as GENERATED (the Overview TFM row-tfm_status
    -- table: GENERATED = "Row written into an FBDI CSV / HDL DAT").
    -- Exceptions propagate to the queue worker deliberately: that is
    -- the contract EXECUTE_ONE guards (unhandled RAISE must land the
    -- work item in FAILED).
    -- Section-5 tag vocabulary only (E1): VALIDATE=[PRE_VALIDATION],
    -- TRANSFORM=[TRANSFORM_ERROR]; GENERATE has no section-5 tag —
    -- untagged infrastructure exception, no invented vocabulary.
    -- ============================================================
    PROCEDURE run_mock (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_scenario_name IN VARCHAR2,
        p_run_mode      IN VARCHAR2
    ) IS
        l_rows PLS_INTEGER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => 'DMT_MOCK ' || p_cemli_code || ' data phase starting'
                           || ' | Scenario: ' || NVL(p_scenario_name, '(none)')
                           || ' | Mode: '     || NVL(p_run_mode, 'NEW'),
            p_log_type  => 'INFO',
            p_package   => C_PKG,
            p_procedure => 'run_mock');

        mark_stage(p_run_id, p_cemli_code, 'VALIDATE',  '[PRE_VALIDATION]');
        mark_stage(p_run_id, p_cemli_code, 'TRANSFORM', '[TRANSFORM_ERROR]');
        mark_stage(p_run_id, p_cemli_code, 'GENERATE',  NULL);

        l_rows := NVL(TO_NUMBER(DMT_UTIL_PKG.GET_CONFIG('MOCK_ROW_COUNT')), 2);
        FOR i IN 1 .. l_rows LOOP
            INSERT INTO DMT_OWNER.DMT_MOCK_TFM_TBL
                (RUN_ID, CEMLI_CODE, RECORD_KEY, TFM_STATUS)
            VALUES
                (p_run_id, p_cemli_code, p_cemli_code || '-' || i, 'GENERATED');
        END LOOP;
        COMMIT;
    END run_mock;

    PROCEDURE RUN_MOCK_OBJECT (
        p_run_id           IN NUMBER,
        p_scenario_name    IN VARCHAR2 DEFAULT NULL,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_skip_bu_refresh  IN BOOLEAN  DEFAULT FALSE
    ) IS
    BEGIN
        run_mock(p_run_id, 'MockObject', p_scenario_name, p_run_mode);
    END RUN_MOCK_OBJECT;

    PROCEDURE RUN_MOCK_CHILD (
        p_run_id           IN NUMBER,
        p_scenario_name    IN VARCHAR2 DEFAULT NULL,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_skip_bu_refresh  IN BOOLEAN  DEFAULT FALSE
    ) IS
    BEGIN
        run_mock(p_run_id, 'MockChild', p_scenario_name, p_run_mode);
    END RUN_MOCK_CHILD;

    -- ============================================================
    -- RECONCILE_BATCH — settles this run's GENERATED mock rows per
    -- MOCK_RECON_OUTCOME (see spec header). Mirrors the section-5
    -- resolution flow: LOADED needs no error text; FAILED always
    -- carries a [FUSION_ERROR]-tagged reportable error (accounted);
    -- UNACCOUNTED leaves rows GENERATED so the accounting gate must
    -- FAIL the work item (section 5 "Object-status accounting").
    -- ============================================================
    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL
    ) IS
        l_outcome VARCHAR2(30);
    BEGIN
        mark_stage(p_run_id, p_cemli_code, 'RECONCILE', '[RECONCILE_ERROR]');

        l_outcome := NVL(DMT_UTIL_PKG.GET_CONFIG('MOCK_RECON_OUTCOME'), 'LOADED');

        IF l_outcome = 'LOADED' THEN
            UPDATE DMT_OWNER.DMT_MOCK_TFM_TBL
            SET    TFM_STATUS = 'LOADED'
            WHERE  RUN_ID = p_run_id
            AND    CEMLI_CODE = p_cemli_code
            AND    TFM_STATUS = 'GENERATED';
        ELSIF l_outcome = 'FAILED_ERROR' THEN
            UPDATE DMT_OWNER.DMT_MOCK_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[FUSION_ERROR] DMT_MOCK simulated interface rejection')
            WHERE  RUN_ID = p_run_id
            AND    CEMLI_CODE = p_cemli_code
            AND    TFM_STATUS = 'GENERATED';
        ELSE
            -- UNACCOUNTED: leave rows GENERATED — no positive success and no
            -- positive failure; the accounting gate must fail the item.
            NULL;
        END IF;
        COMMIT;
    END RECONCILE_BATCH;

END DMT_MOCK_PKG;
/
