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
            'BEGIN DMT_OWNER.DMT_QUEUE_WORKER_PKG.PREFLIGHT_ONE(' || p_run_id || '); END;');
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
            FROM DMT_WORK_QUEUE_TBL
            WHERE WORK_STATUS IN ('AWAITING_LOAD', 'AWAITING_IMPORT', 'AWAITING_POSTRUN')
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
                    'BEGIN DMT_OWNER.DMT_UTIL_PKG.SET_LOG_CONTEXT(' || rec.RUN_ID || ',' || rec.QUEUE_ID || '); DMT_OWNER.DMT_QUEUE_WORKER_PKG.POLL_ONE(' || rec.QUEUE_ID || '); END;');
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
                    'BEGIN DMT_OWNER.DMT_UTIL_PKG.SET_LOG_CONTEXT(' || rec.RUN_ID || ',' || rec.QUEUE_ID || '); DMT_OWNER.DMT_QUEUE_WORKER_PKG.EXECUTE_ONE(' || rec.QUEUE_ID || '); END;');

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
            FROM DMT_WORK_QUEUE_TBL
            WHERE WORK_STATUS = 'RECONCILING'
        )
        LOOP
            l_job_name := 'DMT_RC_' || rec.QUEUE_ID;

            IF child_job_exists(l_job_name) THEN
                CONTINUE;
            END IF;

            BEGIN
                spawn_child(l_job_name,
                    'BEGIN DMT_OWNER.DMT_UTIL_PKG.SET_LOG_CONTEXT(' || rec.RUN_ID || ',' || rec.QUEUE_ID || '); DMT_OWNER.DMT_QUEUE_WORKER_PKG.RECONCILE_ONE(' || rec.QUEUE_ID || '); END;');

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
                   SUM(CASE WHEN WORK_STATUS IN ('DONE','FAILED','SKIPPED') THEN 1 ELSE 0 END),
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
                        run_rec.RUN_ID, obj.CEMLI_CODE, l_t, l_ld, l_fl, l_un);
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
                job_action      => 'BEGIN DMT_OWNER.DMT_QUEUE_PKG.HEARTBEAT_TICK; END;',
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
        WHERE WORK_STATUS NOT IN ('DONE', 'FAILED', 'SKIPPED');

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

END DMT_QUEUE_PKG;
/
