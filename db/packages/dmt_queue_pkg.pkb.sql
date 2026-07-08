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
    -- Phase 2: Split multi-FBDI objects
    -- READY rows with no PARTITION_KEY that have a split config
    -- ============================================================
    PROCEDURE split_multi_fbdi IS
        l_sql        VARCHAR2(4000);
        l_cur        SYS_REFCURSOR;
        l_key        VARCHAR2(500);
        l_label      VARCHAR2(500);
        l_child_cnt  PLS_INTEGER;

        TYPE t_part_rec IS RECORD (pkey VARCHAR2(500), plabel VARCHAR2(500));
        TYPE t_part_tab IS TABLE OF t_part_rec;
        l_parts t_part_tab := t_part_tab();
    BEGIN
        FOR rec IN (
            SELECT q.QUEUE_ID, q.RUN_ID, q.CEMLI_CODE, q.PIPELINE, q.SORT_ORDER, q.DEPENDS_ON,
                   c.TFM_TABLE, c.PARTITION_COLUMNS, c.LABEL_EXPRESSION,
                   NVL(c.STATUS_COLUMN, 'STATUS') AS STATUS_COLUMN
            FROM DMT_WORK_QUEUE_TBL q
            JOIN DMT_CEMLI_SPLIT_CFG c ON c.CEMLI_CODE = q.CEMLI_CODE
            WHERE q.WORK_STATUS = 'READY'
              AND q.PARTITION_KEY IS NULL
        )
        LOOP
            l_parts.DELETE;
            l_child_cnt := 0;

            l_sql := 'SELECT DISTINCT ' || rec.PARTITION_COLUMNS
                  || ', ' || rec.LABEL_EXPRESSION
                  || ' FROM DMT_OWNER.' || rec.TFM_TABLE
                  || ' WHERE RUN_ID = :run_id'
                  || ' AND ' || rec.STATUS_COLUMN || ' IN (''STAGED'',''NEW'',''GENERATED'')';

            BEGIN
                OPEN l_cur FOR l_sql USING rec.RUN_ID;
                LOOP
                    FETCH l_cur INTO l_key, l_label;
                    EXIT WHEN l_cur%NOTFOUND;
                    l_parts.EXTEND;
                    l_parts(l_parts.COUNT).pkey := l_key;
                    l_parts(l_parts.COUNT).plabel := l_label;
                END LOOP;
                CLOSE l_cur;
            EXCEPTION
                WHEN OTHERS THEN
                    IF l_cur%ISOPEN THEN CLOSE l_cur; END IF;
                    DECLARE l_err VARCHAR2(4000) := SQLERRM; BEGIN
                    UPDATE DMT_WORK_QUEUE_TBL
                    SET WORK_STATUS = 'FAILED',
                        ERROR_MESSAGE = 'Split query failed: ' || SUBSTR(l_err, 1, 3000),
                        COMPLETED_AT = SYSTIMESTAMP
                    WHERE QUEUE_ID = rec.QUEUE_ID;
                    COMMIT;
                    END;
                    CONTINUE;
            END;

            IF l_parts.COUNT = 0 THEN
                UPDATE DMT_WORK_QUEUE_TBL
                SET WORK_STATUS = 'DONE',
                    COMPLETED_AT = SYSTIMESTAMP,
                    ERROR_MESSAGE = 'No qualifying rows to process'
                WHERE QUEUE_ID = rec.QUEUE_ID;
            ELSIF l_parts.COUNT = 1 THEN
                UPDATE DMT_WORK_QUEUE_TBL
                SET PARTITION_KEY = l_parts(1).pkey,
                    PARTITION_LABEL = l_parts(1).plabel,
                    WORK_STATUS = 'READY'
                WHERE QUEUE_ID = rec.QUEUE_ID;
            ELSE
                FOR i IN 1..l_parts.COUNT LOOP
                    INSERT INTO DMT_WORK_QUEUE_TBL (
                        RUN_ID, PIPELINE, CEMLI_CODE, PARTITION_KEY, PARTITION_LABEL,
                        SORT_ORDER, DEPENDS_ON, WORK_STATUS
                    ) VALUES (
                        rec.RUN_ID, rec.PIPELINE, rec.CEMLI_CODE,
                        l_parts(i).pkey, l_parts(i).plabel,
                        rec.SORT_ORDER, rec.DEPENDS_ON, 'READY'
                    );
                END LOOP;

                l_child_cnt := l_parts.COUNT;
                UPDATE DMT_WORK_QUEUE_TBL
                SET WORK_STATUS = 'DONE',
                    PARTITION_LABEL = '(split into ' || l_child_cnt || ' partitions)',
                    COMPLETED_AT = SYSTIMESTAMP
                WHERE QUEUE_ID = rec.QUEUE_ID;
            END IF;

            COMMIT;
        END LOOP;
    END split_multi_fbdi;

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
              AND (NEXT_POLL_AFTER IS NULL OR NEXT_POLL_AFTER <= SYSTIMESTAMP)
        )
        LOOP
            l_job_name := 'DMT_PL_' || rec.QUEUE_ID;

            IF child_job_exists(l_job_name) THEN
                CONTINUE;
            END IF;

            BEGIN
                spawn_child(l_job_name,
                    'BEGIN DMT_OWNER.DMT_QUEUE_WORKER_PKG.POLL_ONE(' || rec.QUEUE_ID || '); END;');
            EXCEPTION
                WHEN OTHERS THEN
                    DMT_UTIL_PKG.LOG_ERROR(rec.RUN_ID,
                        'Failed to spawn poll job for ' || rec.CEMLI_CODE,
                        SQLERRM, C_PKG, 'dispatch_ess_polls');
            END;
        END LOOP;
    END dispatch_ess_polls;

    -- ============================================================
    -- Phase 4: Spawn child jobs for READY rows
    -- Only picks up rows that are READY and either:
    --   (a) have a PARTITION_KEY (post-split child), or
    --   (b) have no split config (single-FBDI object)
    -- Marks them VALIDATING so next tick doesn't re-pick them.
    -- ============================================================
    PROCEDURE dispatch_ready IS
        l_job_name VARCHAR2(30);
    BEGIN
        FOR rec IN (
            SELECT q.QUEUE_ID, q.RUN_ID, q.CEMLI_CODE, q.PARTITION_KEY
            FROM DMT_WORK_QUEUE_TBL q
            WHERE q.WORK_STATUS = 'READY'
              AND (q.PARTITION_KEY IS NOT NULL
                   OR NOT EXISTS (SELECT 1 FROM DMT_CEMLI_SPLIT_CFG c
                                  WHERE c.CEMLI_CODE = q.CEMLI_CODE))
            ORDER BY q.SORT_ORDER
        )
        LOOP
            l_job_name := 'DMT_WQ_' || rec.QUEUE_ID;

            -- Don't spawn if child already running
            IF child_job_exists(l_job_name) THEN
                CONTINUE;
            END IF;

            -- Mark in-progress on the run if not already
            UPDATE DMT_PIPELINE_RUN_TBL
            SET RUN_STATUS = 'IN_PROGRESS', STARTED_DATE = SYSTIMESTAMP
            WHERE RUN_ID = rec.RUN_ID AND RUN_STATUS = 'QUEUED';

            -- Claim the row so next tick doesn't re-pick it
            UPDATE DMT_WORK_QUEUE_TBL
            SET WORK_STATUS = 'VALIDATING', STARTED_AT = SYSTIMESTAMP
            WHERE QUEUE_ID = rec.QUEUE_ID;
            COMMIT;

            -- Spawn child job
            BEGIN
                spawn_child(l_job_name,
                    'BEGIN DMT_OWNER.DMT_QUEUE_WORKER_PKG.EXECUTE_ONE(' || rec.QUEUE_ID || '); END;');

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
                    'BEGIN DMT_OWNER.DMT_QUEUE_WORKER_PKG.RECONCILE_ONE(' || rec.QUEUE_ID || '); END;');

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
            SELECT DISTINCT r.RUN_ID, NVL(r.ON_FAILURE_POLICY, 'HALT') AS policy
            FROM DMT_PIPELINE_RUN_TBL r
            WHERE r.RUN_STATUS = 'IN_PROGRESS'
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
    -- Phase 7: Update run-level statuses
    -- ============================================================
    PROCEDURE update_run_statuses IS
        l_total    NUMBER;
        l_done     NUMBER;
        l_failed   NUMBER;
        l_skipped  NUMBER;
    BEGIN
        FOR run_rec IN (
            SELECT RUN_ID FROM DMT_PIPELINE_RUN_TBL
            WHERE RUN_STATUS = 'IN_PROGRESS'
        )
        LOOP
            SELECT COUNT(*),
                   SUM(CASE WHEN WORK_STATUS = 'DONE' THEN 1 ELSE 0 END),
                   SUM(CASE WHEN WORK_STATUS = 'FAILED' THEN 1 ELSE 0 END),
                   SUM(CASE WHEN WORK_STATUS = 'SKIPPED' THEN 1 ELSE 0 END)
            INTO l_total, l_done, l_failed, l_skipped
            FROM DMT_WORK_QUEUE_TBL
            WHERE RUN_ID = run_rec.RUN_ID;

            IF (l_done + l_failed + l_skipped) = l_total THEN
                UPDATE DMT_PIPELINE_RUN_TBL
                SET RUN_STATUS = CASE
                        WHEN l_failed > 0 OR l_skipped > 0 THEN
                            CASE WHEN l_done > 0 THEN 'COMPLETED_ERRORS' ELSE 'FAILED' END
                        ELSE 'COMPLETED'
                    END,
                    COMPLETED_DATE = SYSTIMESTAMP
                WHERE RUN_ID = run_rec.RUN_ID;
            END IF;
        END LOOP;
        COMMIT;
    END update_run_statuses;

    -- EXECUTE_ONE and RECONCILE_ONE are in DMT_QUEUE_WORKER_PKG
    -- (separate package avoids library cache lock self-deadlock
    -- when heartbeat spawns child jobs via DBMS_SCHEDULER.CREATE_JOB)

    -- ============================================================
    -- HEARTBEAT_TICK — main entry point, called every 60s
    -- Lightweight: status checks + child job spawns only.
    -- No Fusion calls, no long-running work.
    -- ============================================================
    PROCEDURE HEARTBEAT_TICK IS
    BEGIN
        promote_ready;
        split_multi_fbdi;
        dispatch_ess_polls;
        dispatch_ready;
        dispatch_reconcile;
        handle_failures;
        update_run_statuses;

        -- Periodic log cleanup (every ~100 ticks = ~100 min)
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
