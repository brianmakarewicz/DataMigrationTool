-- PACKAGE BODY DMT_QUEUE_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_QUEUE_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(30) := 'DMT_QUEUE_PKG';

    -- ============================================================
    -- Helper: check if all dependencies are DONE for a queue row
    -- ============================================================
    FUNCTION dependencies_met (
        p_run_id     IN NUMBER,
        p_depends_on IN VARCHAR2,
        p_policy     IN VARCHAR2 DEFAULT 'HALT'
    ) RETURN BOOLEAN IS
        l_remaining VARCHAR2(4000);
        l_dep       VARCHAR2(60);
        l_pos       PLS_INTEGER;
        l_done      NUMBER;
    BEGIN
        IF p_depends_on IS NULL THEN RETURN TRUE; END IF;

        l_remaining := p_depends_on || ',';
        LOOP
            l_pos := INSTR(l_remaining, ',');
            EXIT WHEN NVL(l_pos, 0) = 0;
            l_dep := TRIM(SUBSTR(l_remaining, 1, l_pos - 1));
            l_remaining := SUBSTR(l_remaining, l_pos + 1);
            IF l_dep IS NULL THEN CONTINUE; END IF;

            -- HALT (default): a dependency is satisfied ONLY when it is DONE.
            -- A SKIPPED (or FAILED, or still-running) dependency must NOT let
            -- this row dispatch — otherwise a row whose parent was skipped runs
            -- without its master data. Such rows are instead cascade-skipped by
            -- handle_failures. (Absent dep = no rows = treated as met.)
            -- CONTINUE (section 2, decided 2026-07-07): dependencies need only
            -- be terminal (DONE or FAILED) — dependents launch anyway and
            -- per-row dependency validation sorts out individual rows.
            IF p_policy = 'CONTINUE' THEN
                SELECT COUNT(*) INTO l_done
                FROM DMT_WORK_QUEUE_TBL
                WHERE RUN_ID = p_run_id
                  AND CEMLI_CODE = l_dep
                  AND WORK_STATUS NOT IN ('DONE', 'FAILED');
            ELSE
                SELECT COUNT(*) INTO l_done
                FROM DMT_WORK_QUEUE_TBL
                WHERE RUN_ID = p_run_id
                  AND CEMLI_CODE = l_dep
                  AND WORK_STATUS <> 'DONE';
            END IF;

            IF l_done > 0 THEN RETURN FALSE; END IF;
        END LOOP;

        RETURN TRUE;
    END dependencies_met;

    -- ============================================================
    -- Helper: check if a child job is already running for a queue row
    -- ============================================================
    FUNCTION child_job_exists (p_job_name IN VARCHAR2) RETURN BOOLEAN IS
        l_cnt NUMBER;
    BEGIN
        SELECT COUNT(*) INTO l_cnt FROM USER_SCHEDULER_JOBS WHERE JOB_NAME = p_job_name;
        RETURN l_cnt > 0;
    END child_job_exists;

    -- ============================================================
    -- Helper: spawn a one-shot child job
    -- ============================================================
    PROCEDURE spawn_child (
        p_job_name   IN VARCHAR2,
        p_plsql      IN VARCHAR2
    ) IS
    BEGIN
        -- Drop leftover from a previous failed run (auto_drop=TRUE should
        -- have cleaned it, but be defensive)
        BEGIN
            DBMS_SCHEDULER.DROP_JOB(p_job_name, force => TRUE);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;

        DBMS_SCHEDULER.CREATE_JOB(
            job_name   => p_job_name,
            job_type   => 'PLSQL_BLOCK',
            job_action => p_plsql,
            enabled    => TRUE,
            auto_drop  => TRUE
        );
    END spawn_child;

    -- ============================================================
    -- Phase 0 helper: claim ONE not-yet-checked QUEUED run for preflight
    -- and spawn its async worker. The preflight itself (a live Fusion
    -- lookup refresh + credential probes) runs OFF the tick in a child
    -- job -- DMT_QUEUE_WORKER_PKG.PREFLIGHT_ONE -- exactly as the other
    -- Fusion-touching phases (dispatch_ready / dispatch_ess_polls /
    -- dispatch_reconcile) do, so a slow Fusion instance never stalls the
    -- heartbeat. The claim flips PREFLIGHT_STATUS NULL -> 'PREFLIGHTING'
    -- so the next tick does not re-pick the run; dispatch stays gated
    -- until the worker sets 'OK' (see dispatch_ready). On a spawn failure
    -- the claim is reverted so the next tick retries.
    -- ============================================================
    PROCEDURE spawn_preflight (p_run_id IN NUMBER) IS
        C_PROC CONSTANT VARCHAR2(30) := 'spawn_preflight';
        l_job  VARCHAR2(30) := 'DMT_PF_' || p_run_id;
    BEGIN
        IF child_job_exists(l_job) THEN
            RETURN;
        END IF;

        UPDATE DMT_PIPELINE_RUN_TBL
        SET    PREFLIGHT_STATUS = 'PREFLIGHTING'
        WHERE  RUN_ID = p_run_id
          AND  PREFLIGHT_STATUS IS NULL;
        COMMIT;

        spawn_child(l_job,
            'BEGIN DMT_QUEUE_WORKER_PKG.PREFLIGHT_ONE(' || p_run_id || '); END;');
    EXCEPTION
        WHEN OTHERS THEN
            -- Could not spawn: revert the claim so the next tick retries.
            UPDATE DMT_PIPELINE_RUN_TBL
            SET    PREFLIGHT_STATUS = NULL
            WHERE  RUN_ID = p_run_id
              AND  PREFLIGHT_STATUS = 'PREFLIGHTING';
            COMMIT;
            DMT_UTIL_PKG.LOG_ERROR(p_run_id    => p_run_id,
                                   p_message   => 'failed to spawn preflight job ' || l_job,
                                   p_sqlerrm   => SQLERRM,
                                   p_package   => C_PKG,
                                   p_procedure => C_PROC);
    END spawn_preflight;

    -- ============================================================
    -- RECOVER_ORPHAN_PREFLIGHT -- see the package spec (backlog #565).
    -- A QUEUED run that is PREFLIGHTING with no DMT_PF_<run> job has lost
    -- its preflight worker without a verdict: run_preflights only claims
    -- NULL and dispatch_ready only releases 'OK', so without this the run
    -- would wait forever and hold its objects' active-run lock. First
    -- time: release the claim so run_preflights (same tick) re-spawns it.
    -- Second time: fail the run with a clear message. The re-spawn count
    -- is the number of earlier WARN entries this procedure wrote for the
    -- run in the activity log (DMT_LOG_TBL).
    -- ============================================================
    PROCEDURE RECOVER_ORPHAN_PREFLIGHT (
        p_run_id     IN  NUMBER,
        x_error_code OUT NUMBER
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'RECOVER_ORPHAN_PREFLIGHT';
        l_job    VARCHAR2(30) := 'DMT_PF_' || p_run_id;
        l_step   VARCHAR2(200);
        l_cnt    NUMBER;
        l_prior  NUMBER;
    BEGIN
        x_error_code := DMT_UTIL_PKG.C_SUCCESS;

        l_step := 'checking whether run ' || p_run_id || ' is an orphaned preflight';
        SELECT COUNT(*) INTO l_cnt
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id
          AND  RUN_STATUS = 'QUEUED'
          AND  PREFLIGHT_STATUS = 'PREFLIGHTING';
        IF l_cnt = 0 OR child_job_exists(l_job) THEN
            RETURN;  -- not claimed, already resolved, or its job is still alive
        END IF;

        l_step := 'counting earlier preflight re-spawns for run ' || p_run_id;
        SELECT COUNT(*) INTO l_prior
        FROM   DMT_LOG_TBL
        WHERE  RUN_ID = p_run_id
          AND  PACKAGE_NAME = C_PKG
          AND  PROCEDURE_NAME = C_PROC
          AND  LOG_TYPE = DMT_UTIL_PKG.C_LOG_WARN;

        IF l_prior = 0 THEN
            l_step := 'releasing the preflight claim of run ' || p_run_id;
            UPDATE DMT_PIPELINE_RUN_TBL
            SET    PREFLIGHT_STATUS = NULL
            WHERE  RUN_ID = p_run_id
              AND  RUN_STATUS = 'QUEUED'
              AND  PREFLIGHT_STATUS = 'PREFLIGHTING';
            COMMIT;
            DMT_UTIL_PKG.LOG(p_run_id    => p_run_id,
                             p_message   => 'Preflight job ' || l_job || ' is gone but the run '
                                            || 'was still marked PREFLIGHTING: the job ended without '
                                            || 'recording a result (for example it could not start '
                                            || 'while a package was being redeployed). Released the '
                                            || 'claim so the preflight is re-spawned once.',
                             p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                             p_package   => C_PKG,
                             p_procedure => C_PROC);
        ELSE
            l_step := 'failing run ' || p_run_id || ' after a second orphaned preflight';
            DMT_QUEUE_WORKER_PKG.FAIL_RUN_PREFLIGHT(
                p_run_id  => p_run_id,
                p_message => 'Preflight job ' || l_job || ' ended twice without recording a '
                             || 'result (it was re-spawned once). Run halted; nothing was '
                             || 'submitted. See the activity log and the scheduler job log for '
                             || l_job || '.');
            DMT_UTIL_PKG.LOG(p_run_id    => p_run_id,
                             p_message   => 'Preflight job ' || l_job || ' ended a second time '
                                            || 'without recording a result. Run halted: its work '
                                            || 'items are FAILED and the heartbeat settles the run FAILED.',
                             p_log_type  => DMT_UTIL_PKG.C_LOG_ERROR,
                             p_package   => C_PKG,
                             p_procedure => C_PROC);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG_ERROR(p_run_id    => p_run_id,
                                   p_message   => l_step,
                                   p_sqlerrm   => SQLERRM,
                                   p_package   => C_PKG,
                                   p_procedure => C_PROC);
    END RECOVER_ORPHAN_PREFLIGHT;

    -- ============================================================
    -- Phase 0a: run RECOVER_ORPHAN_PREFLIGHT for every QUEUED run still
    -- claimed PREFLIGHTING (it returns at once for a run whose job lives).
    -- ============================================================
    PROCEDURE recover_orphan_preflights IS
        C_PROC CONSTANT VARCHAR2(30) := 'recover_orphan_preflights';
        l_code NUMBER;
    BEGIN
        FOR run_rec IN (
            SELECT RUN_ID
            FROM   DMT_PIPELINE_RUN_TBL
            WHERE  RUN_STATUS = 'QUEUED'
              AND  PREFLIGHT_STATUS = 'PREFLIGHTING'
        ) LOOP
            RECOVER_ORPHAN_PREFLIGHT(p_run_id => run_rec.RUN_ID, x_error_code => l_code);
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id    => NULL,
                                   p_message   => 'recover_orphan_preflights phase loop error',
                                   p_sqlerrm   => SQLERRM,
                                   p_package   => C_PKG,
                                   p_procedure => C_PROC);
    END recover_orphan_preflights;

    -- ============================================================
    -- Phase 0: for every QUEUED run not yet preflighted, claim it and
    -- spawn its preflight worker (above). Runs BEFORE dispatch so a run
    -- whose lookups will not refresh, or whose credentials will not
    -- authenticate, never reaches dispatch -- dispatch_ready only releases
    -- work items whose run reached PREFLIGHT_STATUS = 'OK'. The tick does
    -- no Fusion work itself; the worker does, asynchronously.
    -- ============================================================
    PROCEDURE run_preflights IS
        C_PROC CONSTANT VARCHAR2(30) := 'run_preflights';
    BEGIN
        FOR run_rec IN (
            SELECT r.RUN_ID
            FROM   DMT_PIPELINE_RUN_TBL r
            WHERE  r.RUN_STATUS = 'QUEUED'
              AND  r.PREFLIGHT_STATUS IS NULL
              AND  EXISTS (SELECT 1 FROM DMT_WORK_QUEUE_TBL q
                           WHERE q.RUN_ID = r.RUN_ID)
        ) LOOP
            spawn_preflight(p_run_id => run_rec.RUN_ID);
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id    => NULL,
                                   p_message   => 'run_preflights phase loop error',
                                   p_sqlerrm   => SQLERRM,
                                   p_package   => C_PKG,
                                   p_procedure => C_PROC);
    END run_preflights;

    -- ============================================================
    -- Phase 1: Promote PENDING -> READY where dependencies met
    -- ============================================================
    PROCEDURE promote_ready IS
    BEGIN
        FOR rec IN (
            SELECT q.QUEUE_ID, q.RUN_ID, q.DEPENDS_ON,
                   NVL(r.ON_FAILURE_POLICY, 'HALT') AS POLICY
            FROM DMT_WORK_QUEUE_TBL q
            JOIN DMT_PIPELINE_RUN_TBL r ON r.RUN_ID = q.RUN_ID
            WHERE q.WORK_STATUS = 'PENDING'
              AND r.RUN_STATUS <> 'CANCELLED'   -- backlog #635: never revive a cancelled run
        )
        LOOP
            IF dependencies_met(rec.RUN_ID, rec.DEPENDS_ON, rec.POLICY) THEN
                UPDATE DMT_WORK_QUEUE_TBL
                SET WORK_STATUS = 'READY'
                WHERE QUEUE_ID = rec.QUEUE_ID;
            END IF;
        END LOOP;
        COMMIT;
    END promote_ready;

    -- ============================================================
    -- (2026-07-08, C2a) split_multi_fbdi DELETED. It was unreachable
    -- dead code — create_run_and_queue stamps every split-configured
    -- object PARTITION_KEY = 'ALL' at submission, so no READY row
    -- without a partition key could exist for it to act on — and it
    -- carried banned dynamic SQL plus a partition model that
    -- contradicts the decided plan-computes-partitions design
    -- (section 2: partitions knowable from staging data are computed
    -- by the Plan step and created at Confirm Submit; only data-
    -- dependent splits — Assets per book — are created mid-run, by
    -- EXECUTE_ONE). Partition support proper is Stage C task 5.
    -- ============================================================

    -- ============================================================
    -- Phase 3: Spawn child jobs for ESS polling
    -- (AWAITING_LOAD / AWAITING_IMPORT / AWAITING_POSTRUN).
    -- Each poll makes a Fusion SOAP call — runs in its own child job
    -- to keep the heartbeat lightweight. AWAITING_POSTRUN is the
    -- second-stage job (Assets PostMassAdditions) — must be polled too.
    -- ============================================================
    PROCEDURE dispatch_ess_polls IS
        l_job_name VARCHAR2(30);
    BEGIN
        FOR rec IN (
            SELECT QUEUE_ID, RUN_ID, CEMLI_CODE
            FROM DMT_WORK_QUEUE_TBL q
            WHERE WORK_STATUS IN ('AWAITING_LOAD', 'AWAITING_IMPORT', 'AWAITING_POSTRUN')
              -- backlog #635: a cancelled run is never polled again, even if a
              -- stopped job wrote a status after CANCEL_RUN marked its items.
              AND NOT EXISTS (SELECT 1 FROM DMT_PIPELINE_RUN_TBL r
                              WHERE r.RUN_ID = q.RUN_ID AND r.RUN_STATUS = 'CANCELLED')
              -- (Stage D live, 2026-07-08) NEXT_POLL_AFTER is a plain
              -- TIMESTAMP; comparing it to SYSTIMESTAMP (TIMESTAMP WITH
              -- TIME ZONE) re-interprets the stored value in the SESSION
              -- time zone. Scheduler-job sessions here run America/New_York
              -- while the stored value is UTC wall time, so every poll was
              -- silently deferred ~4 hours on the first live POLL_ONE run.
              -- Both writer (worker) and reader now use
              -- SYS_EXTRACT_UTC(SYSTIMESTAMP) -- naive UTC on both sides,
              -- independent of session/OS time zone.
              AND (NEXT_POLL_AFTER IS NULL
                   OR NEXT_POLL_AFTER <= SYS_EXTRACT_UTC(SYSTIMESTAMP))
        )
        LOOP
            l_job_name := 'DMT_PL_' || rec.QUEUE_ID;

            IF child_job_exists(l_job_name) THEN
                CONTINUE;
            END IF;

            BEGIN
                spawn_child(l_job_name,
                    'BEGIN DMT_UTIL_PKG.SET_LOG_CONTEXT(' || rec.RUN_ID || ',' || rec.QUEUE_ID || '); DMT_QUEUE_WORKER_PKG.POLL_ONE(' || rec.QUEUE_ID || '); END;');
            EXCEPTION
                WHEN OTHERS THEN
                    DMT_UTIL_PKG.LOG_ERROR(rec.RUN_ID,
                        'Failed to spawn poll job for ' || rec.CEMLI_CODE,
                        SQLERRM, C_PKG, 'dispatch_ess_polls');
            END;
        END LOOP;
    END dispatch_ess_polls;

    -- ============================================================
    -- Phase 4: Spawn child jobs for READY rows.
    -- Marks them PROCESSING (the status covering the whole data phase:
    -- pre-validate -> transform -> post-validate -> generate -> submit)
    -- so next tick doesn't re-pick them.
    -- (2026-07-08: the split-config predicate is gone with
    -- split_multi_fbdi — every READY row is dispatchable: split
    -- objects arrive with PARTITION_KEY = 'ALL' from submission,
    -- Assets children with their book key from EXECUTE_ONE.
    -- The QUEUED → IN_PROGRESS run write that used to sit here moved
    -- into rollup_run_statuses: one writer per status altitude —
    -- RUN_STATUS is written only by the heartbeat rollup.)
    -- ============================================================
    PROCEDURE dispatch_ready IS
        l_job_name VARCHAR2(30);
    BEGIN
        FOR rec IN (
            -- Preflight gate (Phase 0): a run's items are only dispatched once
            -- its preflight has passed (PREFLIGHT_STATUS = 'OK'). A run still
            -- NULL/'PREFLIGHTING' waits; a 'FAILED' run has its items already
            -- FAILED (not READY). This makes the gate explicit rather than
            -- relying on run_preflights running earlier in the same tick.
            SELECT q.QUEUE_ID, q.RUN_ID, q.CEMLI_CODE, q.PARTITION_KEY
            FROM DMT_WORK_QUEUE_TBL q
            JOIN DMT_PIPELINE_RUN_TBL r ON r.RUN_ID = q.RUN_ID
            WHERE q.WORK_STATUS = 'READY'
              AND r.PREFLIGHT_STATUS = 'OK'
              AND r.RUN_STATUS <> 'CANCELLED'   -- backlog #635
            ORDER BY q.SORT_ORDER
        )
        LOOP
            l_job_name := 'DMT_WQ_' || rec.QUEUE_ID;

            -- Don't spawn if child already running
            IF child_job_exists(l_job_name) THEN
                CONTINUE;
            END IF;

            -- Claim the row so next tick doesn't re-pick it
            UPDATE DMT_WORK_QUEUE_TBL
            SET WORK_STATUS = 'PROCESSING', STARTED_AT = SYSTIMESTAMP
            WHERE QUEUE_ID = rec.QUEUE_ID;
            COMMIT;

            -- Spawn child job
            BEGIN
                spawn_child(l_job_name,
                    'BEGIN DMT_UTIL_PKG.SET_LOG_CONTEXT(' || rec.RUN_ID || ',' || rec.QUEUE_ID || '); DMT_QUEUE_WORKER_PKG.EXECUTE_ONE(' || rec.QUEUE_ID || '); END;');

                DMT_UTIL_PKG.LOG(rec.RUN_ID,
                    'Spawned child job ' || l_job_name || ' for ' || rec.CEMLI_CODE,
                    'INFO', C_PKG, 'dispatch_ready');
            EXCEPTION
                WHEN OTHERS THEN
                    DECLARE l_err VARCHAR2(4000) := SQLERRM; BEGIN
                    UPDATE DMT_WORK_QUEUE_TBL
                    SET WORK_STATUS = 'FAILED',
                        ERROR_MESSAGE = 'Failed to spawn child job: ' || SUBSTR(l_err, 1, 3500),
                        COMPLETED_AT = SYSTIMESTAMP
                    WHERE QUEUE_ID = rec.QUEUE_ID;
                    COMMIT;
                    END;
            END;
        END LOOP;
    END dispatch_ready;

    -- ============================================================
    -- Phase 5: Spawn child jobs for RECONCILING rows
    -- ============================================================
    PROCEDURE dispatch_reconcile IS
        l_job_name VARCHAR2(30);
    BEGIN
        FOR rec IN (
            SELECT QUEUE_ID, RUN_ID, CEMLI_CODE
            FROM DMT_WORK_QUEUE_TBL q
            WHERE WORK_STATUS = 'RECONCILING'
              AND NOT EXISTS (SELECT 1 FROM DMT_PIPELINE_RUN_TBL r   -- backlog #635
                              WHERE r.RUN_ID = q.RUN_ID AND r.RUN_STATUS = 'CANCELLED')
              -- Honour NEXT_POLL_AFTER exactly as dispatch_ess_polls does. Most
              -- RECONCILING rows have NEXT_POLL_AFTER NULL (reconcile immediately).
              -- The HDL base-lag deferral in RECONCILE_ONE sets it ~90s ahead so
              -- the re-spawned reconcile waits for the base rows to appear instead
              -- of busy-looping. A plain UTC TIMESTAMP comparison, same as polls.
              AND (NEXT_POLL_AFTER IS NULL
                   OR NEXT_POLL_AFTER <= SYS_EXTRACT_UTC(SYSTIMESTAMP))
        )
        LOOP
            l_job_name := 'DMT_RC_' || rec.QUEUE_ID;

            IF child_job_exists(l_job_name) THEN
                CONTINUE;
            END IF;

            BEGIN
                spawn_child(l_job_name,
                    'BEGIN DMT_UTIL_PKG.SET_LOG_CONTEXT(' || rec.RUN_ID || ',' || rec.QUEUE_ID || '); DMT_QUEUE_WORKER_PKG.RECONCILE_ONE(' || rec.QUEUE_ID || '); END;');

                DMT_UTIL_PKG.LOG(rec.RUN_ID,
                    'Spawned reconcile job ' || l_job_name || ' for ' || rec.CEMLI_CODE,
                    'INFO', C_PKG, 'dispatch_reconcile');
            EXCEPTION
                WHEN OTHERS THEN
                    DECLARE l_err VARCHAR2(4000) := SQLERRM; BEGIN
                    UPDATE DMT_WORK_QUEUE_TBL
                    SET WORK_STATUS = 'FAILED',
                        ERROR_MESSAGE = 'Failed to spawn reconcile job: ' || SUBSTR(l_err, 1, 3500),
                        COMPLETED_AT = SYSTIMESTAMP
                    WHERE QUEUE_ID = rec.QUEUE_ID;
                    COMMIT;
                    END;
            END;
        END LOOP;
    END dispatch_reconcile;

    -- ============================================================
    -- Phase 6: Handle failures per ON_FAILURE_POLICY
    -- ============================================================
    PROCEDURE handle_failures IS
        l_changed PLS_INTEGER;
    BEGIN
        FOR run_rec IN (
            -- QUEUED included: the run row flips to IN_PROGRESS only in the
            -- end-of-tick rollup (single RUN_STATUS writer), so a first-tick
            -- failure can arrive while the run row still says QUEUED.
            SELECT DISTINCT r.RUN_ID, NVL(r.ON_FAILURE_POLICY, 'HALT') AS policy
            FROM DMT_PIPELINE_RUN_TBL r
            WHERE r.RUN_STATUS IN ('QUEUED', 'IN_PROGRESS')
              AND EXISTS (SELECT 1 FROM DMT_WORK_QUEUE_TBL q
                          WHERE q.RUN_ID = r.RUN_ID
                            AND q.WORK_STATUS IN ('FAILED', 'SKIPPED'))
        )
        LOOP
            IF run_rec.policy = 'HALT' THEN
                -- Cascade SKIP transitively: any PENDING row whose DEPENDS_ON names a CEMLI
                -- that is FAILED *or* SKIPPED is itself skipped. Cascading from SKIPPED (not
                -- just FAILED) plus the repeat-until-stable loop resolves multi-level chains
                -- (A fails → B skipped → C skipped). Exact comma-token matching avoids the
                -- old LIKE '%x%' substring false-matches (e.g. 'Suppliers' vs 'SupplierSites').
                LOOP
                    UPDATE DMT_WORK_QUEUE_TBL q
                    SET WORK_STATUS = 'SKIPPED',
                        ERROR_MESSAGE = 'Skipped: upstream ' ||
                            (SELECT u.CEMLI_CODE FROM DMT_WORK_QUEUE_TBL u
                             WHERE u.RUN_ID = q.RUN_ID
                               AND u.WORK_STATUS IN ('FAILED', 'SKIPPED')
                               AND INSTR(',' || REPLACE(q.DEPENDS_ON, ' ') || ',',
                                         ',' || u.CEMLI_CODE || ',') > 0
                               AND ROWNUM = 1) || ' failed/skipped (HALT policy)',
                        COMPLETED_AT = SYSTIMESTAMP
                    WHERE q.RUN_ID = run_rec.RUN_ID
                      AND q.WORK_STATUS = 'PENDING'
                      AND q.DEPENDS_ON IS NOT NULL
                      AND EXISTS (
                          SELECT 1 FROM DMT_WORK_QUEUE_TBL u
                          WHERE u.RUN_ID = q.RUN_ID
                            AND u.WORK_STATUS IN ('FAILED', 'SKIPPED')
                            AND INSTR(',' || REPLACE(q.DEPENDS_ON, ' ') || ',',
                                      ',' || u.CEMLI_CODE || ',') > 0
                      );
                    l_changed := SQL%ROWCOUNT;
                    EXIT WHEN l_changed = 0;
                END LOOP;
            END IF;
        END LOOP;
        COMMIT;
    END handle_failures;

    -- ============================================================
    -- Phase 7: rollup_run_statuses — THE single RUN_STATUS writer
    -- (proposed rule "One writer per status altitude", 2026-07-08:
    -- "RUN_STATUS is written only by the heartbeat rollup").
    --
    -- The mapping is exactly the run-status definitions in the
    -- Overview's status table — each status's stated meaning is its
    -- rollup condition (section 2 "Rolls the run status up from its
    -- work items"). Precedence (stated 2026-07-07): a run is
    -- IN_PROGRESS while any work item is unfinished — failures do
    -- not settle the run status early — and the terminal statuses
    -- apply only once every item is terminal.
    --
    -- QUEUED runs are included (A9b): a run whose items all went
    -- terminal before the run row ever flipped IN_PROGRESS still
    -- reaches its terminal status here. Runs with NO work items are
    -- deliberately skipped — those are the standalone/legacy loader
    -- run rows (DMT_PIPELINE_INIT_PKG / RUN_STANDALONE), which are
    -- outside the queue lifecycle.
    -- ============================================================
    PROCEDURE rollup_run_statuses IS
        l_total       NUMBER;
        l_terminal    NUMBER;
        l_failed      NUMBER;
        l_started     NUMBER;
        l_row_total   NUMBER;
        l_row_failed  NUMBER;
        l_t           NUMBER;
        l_ld          NUMBER;
        l_fl          NUMBER;
        l_un          NUMBER;
        l_ab          NUMBER;  -- unused here; ACCOUNT_ROWS OUT (base-lag count)
        l_new_status  VARCHAR2(30);
    BEGIN
        FOR run_rec IN (
            SELECT r.RUN_ID, r.RUN_STATUS
            FROM DMT_PIPELINE_RUN_TBL r
            WHERE r.RUN_STATUS IN ('QUEUED', 'IN_PROGRESS')
              AND EXISTS (SELECT 1 FROM DMT_WORK_QUEUE_TBL q
                          WHERE q.RUN_ID = r.RUN_ID)
        )
        LOOP
            SELECT COUNT(*),
                   SUM(CASE WHEN WORK_STATUS IN ('DONE','FAILED','SKIPPED','CANCELLED') THEN 1 ELSE 0 END),
                   SUM(CASE WHEN WORK_STATUS = 'FAILED' THEN 1 ELSE 0 END),
                   SUM(CASE WHEN WORK_STATUS NOT IN ('PENDING','READY') THEN 1 ELSE 0 END)
            INTO l_total, l_terminal, l_failed, l_started
            FROM DMT_WORK_QUEUE_TBL
            WHERE RUN_ID = run_rec.RUN_ID;

            IF l_terminal < l_total THEN
                -- Overview run-status table, IN_PROGRESS row: "At least one
                -- work item is not yet finished (waiting, processing, or
                -- polling)." Failures never settle the run early.
                IF run_rec.RUN_STATUS = 'QUEUED' AND l_started > 0 THEN
                    UPDATE DMT_PIPELINE_RUN_TBL
                    SET RUN_STATUS = 'IN_PROGRESS', STARTED_DATE = SYSTIMESTAMP
                    WHERE RUN_ID = run_rec.RUN_ID;
                END IF;
                CONTINUE;
            END IF;

            -- Backlog #515 catch-all: a split parent is re-checked when its last
            -- child settles through the accounting gate, but a child that ended
            -- FAILED another way (an exception) never reaches the gate. Re-check
            -- every split parent here, once all items are terminal, and recount
            -- the failures in case a parent was just set FAILED.
            FOR par IN (
                SELECT p.QUEUE_ID
                FROM   DMT_WORK_QUEUE_TBL p
                WHERE  p.RUN_ID = run_rec.RUN_ID
                AND    p.WORK_STATUS = 'DONE'
                AND    EXISTS (SELECT 1 FROM DMT_WORK_QUEUE_TBL c
                               WHERE  c.PARENT_QUEUE_ID = p.QUEUE_ID)
            ) LOOP
                DMT_QUEUE_WORKER_PKG.SETTLE_SPLIT_PARENT(p_parent_queue_id => par.QUEUE_ID);
            END LOOP;
            SELECT SUM(CASE WHEN WORK_STATUS = 'FAILED' THEN 1 ELSE 0 END)
            INTO   l_failed
            FROM   DMT_WORK_QUEUE_TBL
            WHERE  RUN_ID = run_rec.RUN_ID;

            -- Every item is terminal — settle per the Overview table.
            IF l_failed > 0 THEN
                -- Overview run-status table, FAILED row: "The run itself
                -- could not finish — an unaccounted-for record or
                -- infrastructure failure. Work items SKIPPED because of that
                -- failure don't change the status further." A FAILED work
                -- item IS that condition (work-item FAILED row: at least one
                -- row unaccounted, or an unrecoverable infrastructure error).
                l_new_status := 'FAILED';
            ELSE
                -- All items DONE (or SKIPPED with no failure). Distinguish
                -- COMPLETED / COMPLETED_ERRORS / NO_ROWS_PROCESSED from ROW
                -- outcomes (A12: the old rollup read only work statuses and
                -- could never produce NO_ROWS_PROCESSED). Row counts come
                -- from the same catalog-driven accounting the gate uses.
                l_row_total  := 0;
                l_row_failed := 0;
                FOR obj IN (
                    SELECT DISTINCT CEMLI_CODE
                    FROM DMT_WORK_QUEUE_TBL
                    WHERE RUN_ID = run_rec.RUN_ID
                )
                LOOP
                    DMT_QUEUE_WORKER_PKG.ACCOUNT_ROWS(
                        run_rec.RUN_ID, obj.CEMLI_CODE, l_t, l_ld, l_fl, l_un,
                        x_awaiting_base => l_ab);
                    l_row_total  := l_row_total  + l_t;
                    l_row_failed := l_row_failed + l_fl + l_un;
                END LOOP;

                IF l_row_total = 0 THEN
                    -- Overview run-status table, NO_ROWS_PROCESSED row: "Run
                    -- finished and every work item selected zero rows —
                    -- nothing in the whole run matched the scenario/mode."
                    l_new_status := 'NO_ROWS_PROCESSED';
                ELSIF l_row_failed > 0 THEN
                    -- Overview run-status table, COMPLETED_ERRORS row: "All
                    -- work items finished; some rows ended FAILED (with
                    -- reportable errors)."
                    l_new_status := 'COMPLETED_ERRORS';
                ELSE
                    -- Overview run-status table, COMPLETED row: "All work
                    -- items finished; every record accounted for with no
                    -- failures."
                    l_new_status := 'COMPLETED';
                END IF;
            END IF;

            UPDATE DMT_PIPELINE_RUN_TBL
            SET RUN_STATUS = l_new_status,
                STARTED_DATE = NVL(STARTED_DATE, SYSTIMESTAMP),
                COMPLETED_DATE = SYSTIMESTAMP
            WHERE RUN_ID = run_rec.RUN_ID;
        END LOOP;
        COMMIT;
    END rollup_run_statuses;

    -- EXECUTE_ONE and RECONCILE_ONE are in DMT_QUEUE_WORKER_PKG
    -- (separate package avoids library cache lock self-deadlock
    -- when heartbeat spawns child jobs via DBMS_SCHEDULER.CREATE_JOB).
    -- Note (engine re-review, 2026-07-08): the separation now carries a
    -- one-way compile dependency — rollup_run_statuses above calls
    -- DMT_QUEUE_WORKER_PKG.ACCOUNT_ROWS. That direction is safe: the
    -- worker package never references this one, so the original
    -- library-cache deadlock (this package spawning a child job that
    -- executes a package depending back on it) is not recreated.

    -- ============================================================
    -- HEARTBEAT_TICK — main entry point, called every 60s
    -- Lightweight: status checks + child job spawns only.
    -- No Fusion calls, no long-running work.
    -- ============================================================
    PROCEDURE HEARTBEAT_TICK IS
    BEGIN
        recover_orphan_preflights;
        run_preflights;
        promote_ready;
        dispatch_ess_polls;
        dispatch_ready;
        dispatch_reconcile;
        handle_failures;
        rollup_run_statuses;

        -- Periodic scheduler-log cleanup. A13 comment fix (2026-07-08): the
        -- old comment claimed "every ~100 ticks"; MOD(minute, 100) = 0 is
        -- true only when the wall-clock minute is 00, i.e. once per hour
        -- (for the ticks that land in that minute).
        IF MOD(TO_NUMBER(TO_CHAR(SYSTIMESTAMP, 'MI')), 100) = 0 THEN
            BEGIN
                DBMS_SCHEDULER.PURGE_LOG(log_history => 7);
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(NULL,
                'HEARTBEAT_TICK unhandled exception',
                SQLERRM, C_PKG, 'HEARTBEAT_TICK');
    END HEARTBEAT_TICK;

    -- ============================================================
    -- PROCESS_QUEUE — legacy alias
    -- ============================================================
    PROCEDURE PROCESS_QUEUE IS
    BEGIN
        HEARTBEAT_TICK;
    END PROCESS_QUEUE;

    -- ============================================================
    -- ENSURE_POLLER_RUNNING — enable the permanent heartbeat job
    -- ============================================================
    PROCEDURE ENSURE_POLLER_RUNNING IS
        l_exists NUMBER;
        l_state  VARCHAR2(30);
    BEGIN
        SELECT COUNT(*) INTO l_exists
        FROM USER_SCHEDULER_JOBS
        WHERE JOB_NAME = C_POLLER_JOB;

        IF l_exists = 0 THEN
            -- First-time creation (deploy script should handle this,
            -- but create if missing as safety net)
            DBMS_SCHEDULER.CREATE_JOB(
                job_name        => C_POLLER_JOB,
                job_type        => 'PLSQL_BLOCK',
                job_action      => 'BEGIN DMT_QUEUE_PKG.HEARTBEAT_TICK; END;',
                repeat_interval => 'FREQ=SECONDLY;INTERVAL=' || C_POLL_INTERVAL,
                auto_drop       => FALSE,
                enabled         => TRUE
            );
            DMT_UTIL_PKG.LOG(NULL,
                'Created and enabled heartbeat job: ' || C_POLLER_JOB,
                'INFO', C_PKG, 'ENSURE_POLLER_RUNNING');
        ELSE
            -- Job exists — just enable it
            SELECT state INTO l_state FROM USER_SCHEDULER_JOBS WHERE JOB_NAME = C_POLLER_JOB;
            IF l_state != 'SCHEDULED' THEN
                DBMS_SCHEDULER.ENABLE(C_POLLER_JOB);
                DMT_UTIL_PKG.LOG(NULL,
                    'Enabled heartbeat job: ' || C_POLLER_JOB,
                    'INFO', C_PKG, 'ENSURE_POLLER_RUNNING');
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(NULL,
                'Failed to enable poller job',
                SQLERRM, C_PKG, 'ENSURE_POLLER_RUNNING');
    END ENSURE_POLLER_RUNNING;

    -- ============================================================
    -- STOP_POLLER_IF_IDLE — disable (not drop) if no active work
    -- ============================================================
    PROCEDURE STOP_POLLER_IF_IDLE IS
        l_active NUMBER;
    BEGIN
        SELECT COUNT(*) INTO l_active
        FROM DMT_WORK_QUEUE_TBL
        WHERE WORK_STATUS NOT IN ('DONE', 'FAILED', 'SKIPPED', 'CANCELLED');

        IF l_active = 0 THEN
            BEGIN
                DBMS_SCHEDULER.DISABLE(C_POLLER_JOB);
                DMT_UTIL_PKG.LOG(NULL,
                    'Disabled heartbeat job: no active work remaining',
                    'INFO', C_PKG, 'STOP_POLLER_IF_IDLE');
            EXCEPTION
                WHEN OTHERS THEN NULL;
            END;
        END IF;
    END STOP_POLLER_IF_IDLE;

    -- ============================================================
    -- RERUN_RUN — re-run reconcile for a whole run (backlog #95).
    -- See the package spec for the full contract. One driver, registry-
    -- dispatched: it never calls a per-object reconciler directly and it
    -- contains NO dynamic SQL and names NO TFM table. Per object in the run
    -- it (1) dispatches the object's OWN static RESET_UNACCOUNTED proc
    -- through the existing sanctioned invoke_registered site (the
    -- DMT_QUEUE_WORKER_PKG.INVOKE_RESET wrapper) — that proc, in the object's
    -- results package, flips this run's UNACCOUNTED rows back to GENERATED
    -- with a STATIC UPDATE over its literally-named TFM table(s); (2) flips
    -- the object's terminal work items back to RECONCILING; then lets the
    -- existing poller (dispatch_reconcile -> RECONCILE_ONE -> the object's
    -- registered RECON_PROC) drive them to a real terminal verdict.
    -- ============================================================
    PROCEDURE RERUN_RUN (p_run_id IN NUMBER) IS
        l_run_exists  NUMBER;
        l_total_reset NUMBER := 0;
        l_this_flip   NUMBER;
        l_flipped     NUMBER := 0;
        -- ACCOUNT_ROWS is the existing sanctioned catalog-driven accounting
        -- read (design section 5); RERUN_RUN uses it ONLY to learn, per object,
        -- whether any rows are currently unaccounted (so it re-dispatches just
        -- the objects that have work to redo). It never writes and never names
        -- a TFM table here.
        l_total       NUMBER;
        l_loaded      NUMBER;
        l_failed      NUMBER;
        l_unaccounted NUMBER;
        l_awaiting    NUMBER;
        l_reset_proc  DMT_PIPELINE_DEF_TBL.RESET_PROC%TYPE;
        l_reset_cemli DMT_PIPELINE_DEF_TBL.RECON_HAS_CEMLI_ARG%TYPE;
    BEGIN
        SELECT COUNT(*) INTO l_run_exists
        FROM   DMT_PIPELINE_RUN_TBL WHERE RUN_ID = p_run_id;
        IF l_run_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20120,
                'RERUN_RUN: no such run RUN_ID=' || p_run_id);
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            'RERUN_RUN requested: resetting UNACCOUNTED rows and re-dispatching '
            || 'reconcile for the run.',
            'INFO', C_PKG, 'RERUN_RUN');

        -- One pass per object in the run. For each object: if it currently has
        -- any unaccounted rows (an UNACCOUNTED terminal row would count here),
        -- dispatch the object's OWN static RESET_UNACCOUNTED proc through the
        -- existing invoke_registered site to flip those rows back to GENERATED,
        -- then flip the object's terminal work items to RECONCILING so the poller
        -- re-dispatches them through the registered RECON_PROC. Objects with no
        -- registered RESET_PROC (config stubs, mocks) are skipped — there is
        -- nothing to reset for them. This driver holds no dynamic SQL and names
        -- no TFM table: the reset is entirely inside the object's static proc.
        FOR obj IN (
            SELECT DISTINCT CEMLI_CODE
            FROM   DMT_WORK_QUEUE_TBL
            WHERE  RUN_ID = p_run_id
        ) LOOP
            -- Registry lookup: the object's static reset proc (PKG.PROC name).
            -- NULL = the object registers no reset (nothing to do).
            BEGIN
                SELECT RESET_PROC, RECON_HAS_CEMLI_ARG
                INTO   l_reset_proc, l_reset_cemli
                FROM   DMT_PIPELINE_DEF_TBL
                WHERE  CEMLI_CODE = obj.CEMLI_CODE;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN l_reset_proc := NULL;
            END;

            IF l_reset_proc IS NOT NULL THEN
                -- Does this object currently have any unaccounted rows worth
                -- re-running? (A stored UNACCOUNTED row is not LOADED and not
                -- FAILED-with-a-real-error, so it is counted here.) Uses the
                -- existing sanctioned catalog-driven read; no new site.
                DMT_QUEUE_WORKER_PKG.ACCOUNT_ROWS(
                    p_run_id        => p_run_id,
                    p_cemli_code    => obj.CEMLI_CODE,
                    x_total         => l_total,
                    x_loaded        => l_loaded,
                    x_failed        => l_failed,
                    x_unaccounted   => l_unaccounted,
                    x_awaiting_base => l_awaiting);

                IF NVL(l_unaccounted, 0) > 0 THEN
                    -- Reset this object's UNACCOUNTED rows -> GENERATED via its
                    -- OWN static proc, dispatched through the sanctioned site.
                    DMT_QUEUE_WORKER_PKG.INVOKE_RESET(
                        p_reset_proc    => l_reset_proc,
                        p_run_id        => p_run_id,
                        p_cemli_code    => obj.CEMLI_CODE,
                        p_has_cemli_arg => l_reset_cemli);
                    l_total_reset := l_total_reset + NVL(l_unaccounted, 0);

                    -- Flip this object's terminal work items back to RECONCILING.
                    -- Clear NEXT_POLL_AFTER (immediate re-dispatch), COMPLETED_AT
                    -- and ERROR_MESSAGE (no longer terminal). Only objects that
                    -- reconcile through the queue are re-opened: those with a
                    -- registered RECON_PROC, or HDL base-proof objects (no
                    -- RECON_PROC but they DO flow through RECONCILE_ONE, which
                    -- re-runs their base-table proof). An object with neither is
                    -- left terminal — the poller has nothing to dispatch for it
                    -- and RECONCILE_ONE would raise.
                    UPDATE DMT_WORK_QUEUE_TBL q
                    SET    q.WORK_STATUS     = 'RECONCILING',
                           q.NEXT_POLL_AFTER = NULL,
                           q.COMPLETED_AT    = NULL,
                           q.ERROR_MESSAGE   = NULL
                    WHERE  q.RUN_ID = p_run_id
                    AND    q.CEMLI_CODE = obj.CEMLI_CODE
                    AND    q.WORK_STATUS IN ('DONE', 'FAILED')
                    -- A spawn-per-partition PARENT (the item that split into child
                    -- items) owns no records and has no job ids; its children carry
                    -- the loads. Re-opening it would reconcile nothing and then run
                    -- a run-wide sweep over its children's freshly reset rows (its
                    -- PARTITION_KEY is NULL, so its sweep is not item-scoped).
                    -- Only the children are re-opened, each with its own ids
                    -- (backlog #313).
                    AND    NOT EXISTS (SELECT 1 FROM DMT_WORK_QUEUE_TBL c
                                       WHERE  c.PARENT_QUEUE_ID = q.QUEUE_ID)
                    AND    ( EXISTS (SELECT 1 FROM DMT_PIPELINE_DEF_TBL d
                                     WHERE d.CEMLI_CODE = q.CEMLI_CODE
                                       AND d.RECON_PROC IS NOT NULL)
                             OR EXISTS (SELECT 1 FROM DMT_BIP_REPORT_TBL b
                                        WHERE b.CEMLI_CODE      = q.CEMLI_CODE
                                          AND b.CONTRACT_VERSION = 1
                                          AND b.INTERFACE_TABLE  = 'N/A (HDL)') );
                    l_this_flip := SQL%ROWCOUNT;
                    l_flipped   := l_flipped + l_this_flip;
                END IF;
            END IF;
        END LOOP;

        -- Step 3: reopen the run so the heartbeat rollup re-settles it once the
        -- re-dispatched objects finish. The rollup only considers QUEUED /
        -- IN_PROGRESS runs, so a terminal run must be re-opened or its status
        -- would stay stale even after the work items re-reconcile. Only reopen
        -- when we actually flipped work items back to RECONCILING.
        IF l_flipped > 0 THEN
            UPDATE DMT_PIPELINE_RUN_TBL
            SET    RUN_STATUS     = 'IN_PROGRESS',
                   COMPLETED_DATE = NULL
            WHERE  RUN_ID = p_run_id
            AND    RUN_STATUS IN ('COMPLETED', 'COMPLETED_ERRORS',
                                  'FAILED', 'NO_ROWS_PROCESSED');
        END IF;

        COMMIT;

        DMT_UTIL_PKG.LOG(p_run_id,
            'RERUN_RUN done: reset ' || l_total_reset || ' UNACCOUNTED row(s) to '
            || 'GENERATED, re-dispatched ' || l_flipped || ' work item(s) to '
            || 'RECONCILING.',
            'INFO', C_PKG, 'RERUN_RUN');

        -- Wake the poller so dispatch_reconcile picks up the RECONCILING rows.
        IF l_flipped > 0 THEN
            ENSURE_POLLER_RUNNING;
        END IF;
    END RERUN_RUN;

    -- ============================================================
    -- stop_run_job -- private helper of CANCEL_RUN: stop (if running) and
    -- drop one scheduler job. DROP_JOB with force => TRUE first stops a
    -- running instance; the stopped session's uncommitted work rolls back.
    -- A job that is already gone is not an error.
    -- ============================================================
    PROCEDURE stop_run_job (
        p_run_id     IN  NUMBER,
        p_job_name   IN  VARCHAR2,
        x_error_code OUT NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'stop_run_job';
    BEGIN
        x_error_code := DMT_UTIL_PKG.C_SUCCESS;
        IF child_job_exists(p_job_name) THEN
            DBMS_SCHEDULER.DROP_JOB(job_name => p_job_name, force => TRUE);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            -- ORA-27475: the job finished and auto-dropped between the check and
            -- the drop -- it is gone, which is the goal.
            IF SQLCODE = -27475 THEN
                x_error_code := DMT_UTIL_PKG.C_SUCCESS;
            ELSE
                x_error_code := DMT_UTIL_PKG.C_ERROR;
                DMT_UTIL_PKG.LOG_ERROR(p_run_id    => p_run_id,
                                       p_message   => 'CANCEL_RUN could not stop scheduler job ' || p_job_name,
                                       p_sqlerrm   => SQLERRM,
                                       p_package   => C_PKG,
                                       p_procedure => C_PROC);
            END IF;
    END stop_run_job;

    -- ============================================================
    -- CANCEL_RUN -- see the package spec (owner-approved 2026-10-08,
    -- backlog #635). The one writer of RUN_STATUS = 'CANCELLED' and
    -- WORK_STATUS = 'CANCELLED'. Touches only DMT_PIPELINE_RUN_TBL,
    -- DMT_WORK_QUEUE_TBL, the run's scheduler jobs and the activity log --
    -- never an STG or TFM table.
    -- ============================================================
    PROCEDURE CANCEL_RUN (
        p_run_id       IN  NUMBER,
        p_reason       IN  VARCHAR2,
        p_cancelled_by IN  VARCHAR2 DEFAULT NULL,
        x_error_code   OUT NUMBER
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'CANCEL_RUN';
        TYPE t_names IS TABLE OF VARCHAR2(128);
        TYPE t_ids   IS TABLE OF NUMBER;
        l_step        VARCHAR2(200);
        l_status      DMT_PIPELINE_RUN_TBL.RUN_STATUS%TYPE;
        l_by          VARCHAR2(100);
        l_msg         VARCHAR2(4000);
        l_ids         t_ids;
        l_jobs        t_names;
        l_late        NUMBER := 0;
        l_job_code    NUMBER;
        l_stopped     VARCHAR2(4000);
        l_not_stopped NUMBER := 0;
    BEGIN
        x_error_code := DMT_UTIL_PKG.C_SUCCESS;

        l_step := 'validating the cancel reason';
        IF TRIM(p_reason) IS NULL THEN
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG(p_run_id    => p_run_id,
                             p_message   => 'CANCEL_RUN refused for run ' || p_run_id
                                            || ': a cancel reason is required.',
                             p_log_type  => DMT_UTIL_PKG.C_LOG_ERROR,
                             p_package   => C_PKG,
                             p_procedure => C_PROC);
            RETURN;
        END IF;

        l_step := 'locking run ' || p_run_id;
        SELECT RUN_STATUS INTO l_status
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id
        FOR UPDATE;

        IF l_status = 'CANCELLED' THEN
            ROLLBACK;
            DMT_UTIL_PKG.LOG(p_run_id    => p_run_id,
                             p_message   => 'CANCEL_RUN: run ' || p_run_id
                                            || ' is already CANCELLED; nothing to do.',
                             p_log_type  => DMT_UTIL_PKG.C_LOG_INFO,
                             p_package   => C_PKG,
                             p_procedure => C_PROC);
            RETURN;
        END IF;

        IF l_status NOT IN ('QUEUED', 'IN_PROGRESS') THEN
            ROLLBACK;
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG(p_run_id    => p_run_id,
                             p_message   => 'CANCEL_RUN refused for run ' || p_run_id
                                            || ': it already finished with status ' || l_status
                                            || '. Only a QUEUED or IN_PROGRESS run can be cancelled.',
                             p_log_type  => DMT_UTIL_PKG.C_LOG_ERROR,
                             p_package   => C_PKG,
                             p_procedure => C_PROC);
            RETURN;
        END IF;

        l_by  := SUBSTR(NVL(p_cancelled_by, SYS_CONTEXT('USERENV', 'SESSION_USER')), 1, 100);
        l_msg := SUBSTR('Cancelled by ' || l_by || ' at '
                        || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS TZH:TZM')
                        || ': ' || TRIM(p_reason), 1, 4000);

        -- Pass 1: cancel every not-yet-terminal work item and the run row in
        -- one transaction, BEFORE touching the scheduler (DBMS_SCHEDULER calls
        -- commit implicitly). From this commit on the heartbeat dispatches
        -- nothing for the run.
        l_step := 'cancelling the open work items of run ' || p_run_id;
        UPDATE DMT_WORK_QUEUE_TBL
        SET    WORK_STATUS   = 'CANCELLED',
               ERROR_MESSAGE = l_msg,
               COMPLETED_AT  = SYSTIMESTAMP
        WHERE  RUN_ID = p_run_id
          AND  WORK_STATUS NOT IN ('DONE', 'FAILED', 'SKIPPED', 'CANCELLED')
        RETURNING QUEUE_ID BULK COLLECT INTO l_ids;

        l_step := 'marking run ' || p_run_id || ' CANCELLED';
        UPDATE DMT_PIPELINE_RUN_TBL
        SET    RUN_STATUS     = 'CANCELLED',
               COMPLETED_DATE = SYSTIMESTAMP,
               ERROR_MESSAGE  = SUBSTR(l_msg || CASE WHEN ERROR_MESSAGE IS NOT NULL
                                                     THEN ' | earlier error: ' || ERROR_MESSAGE
                                                END, 1, 4000)
        WHERE  RUN_ID = p_run_id;
        COMMIT;

        -- Stop and drop every scheduler job that belongs to the run: its
        -- preflight job and the data-phase / poll / reconcile job of each of
        -- its work items (any status -- a job can outlive its item's status).
        l_step := 'listing the scheduler jobs of run ' || p_run_id;
        SELECT j.JOB_NAME
        BULK COLLECT INTO l_jobs
        FROM   USER_SCHEDULER_JOBS j
        WHERE  j.JOB_NAME = 'DMT_PF_' || p_run_id
           OR  j.JOB_NAME IN (SELECT 'DMT_WQ_' || q.QUEUE_ID FROM DMT_WORK_QUEUE_TBL q
                              WHERE q.RUN_ID = p_run_id
                              UNION ALL
                              SELECT 'DMT_PL_' || q.QUEUE_ID FROM DMT_WORK_QUEUE_TBL q
                              WHERE q.RUN_ID = p_run_id
                              UNION ALL
                              SELECT 'DMT_RC_' || q.QUEUE_ID FROM DMT_WORK_QUEUE_TBL q
                              WHERE q.RUN_ID = p_run_id);

        l_step := 'stopping the scheduler jobs of run ' || p_run_id;
        FOR i IN 1 .. l_jobs.COUNT LOOP
            stop_run_job(p_run_id => p_run_id, p_job_name => l_jobs(i), x_error_code => l_job_code);
            IF l_job_code = DMT_UTIL_PKG.C_SUCCESS THEN
                l_stopped := SUBSTR(l_stopped || CASE WHEN l_stopped IS NOT NULL THEN ', ' END
                                    || l_jobs(i), 1, 3000);
            ELSE
                l_not_stopped := l_not_stopped + 1;
            END IF;
        END LOOP;

        -- Pass 2: a job stopped above may have written its item's status
        -- (its own error handler, or a commit just before the stop), and a
        -- running data phase may have created split children. Put every such
        -- item back to CANCELLED. Items that were already DONE / FAILED /
        -- SKIPPED before the cancel are not in l_ids and keep their verdict.
        l_step := 're-cancelling items a stopped job touched in run ' || p_run_id;
        IF l_ids.COUNT > 0 THEN
            FORALL i IN 1 .. l_ids.COUNT
                UPDATE DMT_WORK_QUEUE_TBL
                SET    WORK_STATUS   = 'CANCELLED',
                       ERROR_MESSAGE = l_msg,
                       COMPLETED_AT  = SYSTIMESTAMP
                WHERE  QUEUE_ID = l_ids(i)
                  AND  WORK_STATUS <> 'CANCELLED';
            l_late := SQL%ROWCOUNT;
        END IF;

        UPDATE DMT_WORK_QUEUE_TBL
        SET    WORK_STATUS   = 'CANCELLED',
               ERROR_MESSAGE = l_msg,
               COMPLETED_AT  = SYSTIMESTAMP
        WHERE  RUN_ID = p_run_id
          AND  WORK_STATUS NOT IN ('DONE', 'FAILED', 'SKIPPED', 'CANCELLED');
        l_late := l_late + SQL%ROWCOUNT;
        COMMIT;

        IF l_not_stopped > 0 THEN
            x_error_code := DMT_UTIL_PKG.C_ERROR;
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id    => p_run_id,
                         p_message   => 'Run ' || p_run_id || ' CANCELLED by ' || l_by || ': '
                                        || SUBSTR(TRIM(p_reason), 1, 1000)
                                        || '. Work items cancelled: ' || l_ids.COUNT
                                        || CASE WHEN l_late > 0
                                                THEN ' (' || l_late || ' re-cancelled after a stopped job wrote to them)'
                                           END
                                        || '. Scheduler jobs stopped: ' || NVL(l_stopped, 'none')
                                        || CASE WHEN l_not_stopped > 0
                                                THEN '. Jobs that could NOT be stopped: ' || l_not_stopped
                                                     || ' (see the error entries above)'
                                           END
                                        || '. STG and TFM rows were not touched.',
                         p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                         p_package   => C_PKG,
                         p_procedure => C_PROC);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG(p_run_id    => p_run_id,
                             p_message   => 'CANCEL_RUN refused: no run with RUN_ID ' || p_run_id || '.',
                             p_log_type  => DMT_UTIL_PKG.C_LOG_ERROR,
                             p_package   => C_PKG,
                             p_procedure => C_PROC);
        WHEN OTHERS THEN
            ROLLBACK;
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG_ERROR(p_run_id    => p_run_id,
                                   p_message   => l_step,
                                   p_sqlerrm   => SQLERRM,
                                   p_package   => C_PKG,
                                   p_procedure => C_PROC);
    END CANCEL_RUN;

END DMT_QUEUE_PKG;
/
