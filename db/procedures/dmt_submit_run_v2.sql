-- PROCEDURE DMT_SUBMIT_RUN_V2

  CREATE OR REPLACE EDITIONABLE PROCEDURE "DMT_SUBMIT_RUN_V2" (
    p_pipeline_codes IN VARCHAR2,
    p_scenario_name  IN VARCHAR2 DEFAULT NULL,
    p_run_mode       IN VARCHAR2 DEFAULT 'NEW',
    p_on_failure     IN VARCHAR2 DEFAULT 'HALT',
    p_submitted_by   IN VARCHAR2 DEFAULT NULL,
    p_dependent_prefix IN VARCHAR2 DEFAULT NULL,
    p_validate_upstream IN VARCHAR2 DEFAULT 'N',
    x_run_id         OUT NUMBER
) IS
BEGIN
    -- ============================================================
    -- Thin compatibility wrapper (engine re-review, 2026-07-08).
    -- This procedure is the submission entry point the archived
    -- APEX export (apex/DMTApplication.sql) calls, so its external signature
    -- must not change. Its old body duplicated run/queue creation
    -- and bypassed every submission guard the scheduler now
    -- enforces: the USE_PREFIX config-row serialization lock, the
    -- one-active-run-per-object check, the USE_PREFIX cutover
    -- switch (it always generated a prefix), the ALL-mode-requires-
    -- a-scenario rule, and DEPENDS_ON token validation.
    --
    -- It now delegates to DMT_SCHEDULER_PKG.SUBMIT_PIPELINE, which
    -- accepts the exact same p_pipeline_codes format (pipeline CSV,
    -- including 'STANDALONE:ObjectName' entries) and routes through
    -- create_run_and_queue — the single guarded submission path.
    -- All parameters map one-to-one; nothing is dropped.
    -- Note the prefix is now decided by the scheduler (one per run
    -- from DMT_RUN_PREFIX_SEQ, or NULL when the administrator set
    -- USE_PREFIX = 'N' for cutover) — this wrapper no longer draws
    -- its own prefix.
    --
    -- Backlog #142: p_dependent_prefix and p_validate_upstream are the
    -- two page-84 run parameters (Dependent-Run picker, Validate-
    -- Upstream toggle). Both have defaults so the archived external
    -- signature stays backward-compatible; they pass straight through
    -- to SUBMIT_PIPELINE, which persists them on the run row.
    -- ============================================================
    DMT_SCHEDULER_PKG.SUBMIT_PIPELINE(
        p_pipeline_codes => p_pipeline_codes,
        p_scenario_name  => p_scenario_name,
        p_run_mode       => p_run_mode,
        p_on_failure     => p_on_failure,
        p_submitted_by   => p_submitted_by,
        p_dependent_prefix => p_dependent_prefix,
        p_validate_upstream => p_validate_upstream,
        x_run_id         => x_run_id
    );
END;
/
