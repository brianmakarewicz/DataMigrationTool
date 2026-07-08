-- PACKAGE BODY DMT_MOCK_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_MOCK_PKG"
AS
    C_PKG CONSTANT VARCHAR2(30) := 'DMT_MOCK_PKG';

    -- ============================================================
    -- mark_stage — write the marker row for one stage, then raise
    -- if the failure-injection config targets this object + stage.
    -- The raise carries the section-5 stage tag so the queue
    -- worker's ERROR_MESSAGE is tagged like a real pipeline error.
    -- ============================================================
    PROCEDURE mark_stage (
        p_run_id     IN NUMBER,
        p_cemli_code IN VARCHAR2,
        p_stage      IN VARCHAR2,
        p_error_tag  IN VARCHAR2
    ) IS
        l_step        VARCHAR2(200);
        l_fail_stage  VARCHAR2(100);
        l_fail_object VARCHAR2(100);
    BEGIN
        l_step := 'writing ' || p_stage || ' marker for ' || p_cemli_code;
        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => 'DMT_MOCK ' || p_cemli_code || ' ' || p_stage || ' ran',
            p_log_type  => 'INFO',
            p_package   => C_PKG,
            p_procedure => p_stage);

        l_step := 'reading failure-injection config for ' || p_stage;
        l_fail_stage  := NVL(DMT_UTIL_PKG.GET_CONFIG('MOCK_FAIL_STAGE'), 'NONE');
        l_fail_object := NVL(DMT_UTIL_PKG.GET_CONFIG('MOCK_FAIL_OBJECT'), 'MockObject');

        IF l_fail_stage = p_stage AND l_fail_object = p_cemli_code THEN
            RAISE_APPLICATION_ERROR(-20990,
                p_error_tag || ' DMT_MOCK injected failure at ' || p_stage
                || ' for ' || p_cemli_code || ' (MOCK_FAIL_STAGE=' || l_fail_stage || ')');
        END IF;
    END mark_stage;

    -- ============================================================
    -- run_mock — the shared data-phase stub: VALIDATE → TRANSFORM
    -- → GENERATE markers in order. Exceptions propagate to the
    -- queue worker deliberately: that is the contract EXECUTE_ONE
    -- guards (unhandled RAISE must land the work item in FAILED).
    -- ============================================================
    PROCEDURE run_mock (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_scenario_name IN VARCHAR2,
        p_run_mode      IN VARCHAR2
    ) IS
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
        mark_stage(p_run_id, p_cemli_code, 'GENERATE',  '[GENERATE_ERROR]');
    END run_mock;

    PROCEDURE RUN_MOCK_OBJECT (
        p_run_id           IN NUMBER,
        p_scenario_name    IN VARCHAR2 DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_skip_bu_refresh  IN BOOLEAN  DEFAULT FALSE
    ) IS
    BEGIN
        run_mock(p_run_id, 'MockObject', p_scenario_name, p_run_mode);
    END RUN_MOCK_OBJECT;

    PROCEDURE RUN_MOCK_CHILD (
        p_run_id           IN NUMBER,
        p_scenario_name    IN VARCHAR2 DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW',
        p_skip_bu_refresh  IN BOOLEAN  DEFAULT FALSE
    ) IS
    BEGIN
        run_mock(p_run_id, 'MockChild', p_scenario_name, p_run_mode);
    END RUN_MOCK_CHILD;

    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL
    ) IS
    BEGIN
        mark_stage(p_run_id, p_cemli_code, 'RECONCILE', '[RECON_ERROR]');
    END RECONCILE_BATCH;

END DMT_MOCK_PKG;
/
