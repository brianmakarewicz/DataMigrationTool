-- ===========================================================================
-- SYS-owned DATABASE STARTUP trigger: DMT_REAP_ORPHAN_JOBS_TRG (backlog #144)
--
-- WHY: the engine's one-shot worker jobs (DMT_WQ_<queue_id> /
-- DMT_PL_<queue_id> / DMT_PF_<run_id>) are created with AUTO_DROP=TRUE, so a
-- healthy worker drops itself the instant its action returns. If the DB /
-- container is shut down WHILE a worker is mid-run, the action aborts with
-- 'ORA-01014: ORACLE shutdown in progress', AUTO_DROP never fires, and the job
-- survives the restart in a non-terminal scheduler state holding a job_queue
-- slot. A few of those starve the persistent poller DMT_QUEUE_POLLER and the
-- run stalls, prompting another restart -> more orphans.
--
-- RULE (simple + robust): on DB open, ANY DMT_OWNER one-shot worker job that
-- still exists is BY DEFINITION an orphan (a live worker would have auto-dropped
-- before a clean shutdown; a surviving one was killed mid-run). So force-drop
-- every DMT_OWNER scheduler job named DMT_WQ_% / DMT_PL_% / DMT_PF_% (ESCAPE on
-- the literal underscore). The persistent poller DMT_QUEUE_POLLER is NOT in
-- those name families and is never touched. No work-queue inspection needed.
--
-- SAFETY: this is the ONE privileged object we accept -- a local-env infra
-- trigger, created ONCE as SYS and committed to git. It fires AFTER STARTUP ON
-- DATABASE, which is exactly what a `docker restart` triggers. Each DROP_JOB is
-- wrapped in its own BEGIN/EXCEPTION WHEN OTHERS THEN NULL, and the whole body
-- is wrapped again, so a corrupt job or any error can NEVER impede DB open.
-- Idempotent: CREATE OR REPLACE; a clean DB finds no matching jobs and drops
-- nothing.
--
-- Run as: sqlplus / as sysdba   (fresh build does this from build_local_db.sh;
-- the live local DB had it applied once the same way). Not DMT schema DDL.
-- ===========================================================================
CREATE OR REPLACE TRIGGER DMT_REAP_ORPHAN_JOBS_TRG
    AFTER STARTUP ON DATABASE
BEGIN
    FOR j IN (
        SELECT owner, job_name
        FROM   dba_scheduler_jobs
        WHERE  owner = 'DMT_OWNER'
          AND  ( job_name LIKE 'DMT\_WQ\_%' ESCAPE '\'
              OR job_name LIKE 'DMT\_PL\_%' ESCAPE '\'
              OR job_name LIKE 'DMT\_PF\_%' ESCAPE '\' )
    ) LOOP
        BEGIN
            DBMS_SCHEDULER.DROP_JOB(
                job_name => j.owner || '.' || j.job_name,
                force    => TRUE);
        EXCEPTION
            WHEN OTHERS THEN NULL;  -- one bad job must never block DB open
        END;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN NULL;          -- the whole reap is best-effort at open
END;
/
-- Surface any compile error loudly: CREATE OR REPLACE "succeeds" even when the
-- body is invalid, so without this a broken trigger would ship silently and the
-- self-heal would just never fire at the next restart.
SHOW ERRORS TRIGGER DMT_REAP_ORPHAN_JOBS_TRG

