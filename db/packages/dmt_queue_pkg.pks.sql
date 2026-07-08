-- PACKAGE DMT_QUEUE_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_QUEUE_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_QUEUE_PKG — Heartbeat + async child-job queue poller
--
-- Architecture:
--   One permanent DBMS_SCHEDULER job fires HEARTBEAT_TICK every
--   60s. The heartbeat is lightweight (status checks + job spawns,
--   no Fusion calls). Heavy work runs in one-shot child jobs:
--     EXECUTE_ONE  — validate + transform + generate + SUBMIT_LOAD
--     RECONCILE_ONE — BIP reconciliation
--   Each child runs in its own DB session, so multiple objects
--   process in parallel and nothing blocks the heartbeat.
--
-- Job lifecycle:
--   The heartbeat job (DMT_QUEUE_POLLER) is created ONCE at deploy
--   time and never dropped. ENSURE_POLLER_RUNNING enables it;
--   STOP_POLLER_IF_IDLE disables it. No CREATE_JOB/DROP_JOB at
--   runtime = no library cache lock contention with APEX sessions.
--
-- Child job naming: DMT_WQ_{QUEUE_ID} / DMT_RC_{QUEUE_ID}
-- ============================================================

    C_POLLER_JOB     CONSTANT VARCHAR2(30) := 'DMT_QUEUE_POLLER';
    C_POLL_INTERVAL  CONSTANT PLS_INTEGER  := 60;   -- seconds
    -- (A3, 2026-07-08: the hardcoded C_ESS_TIMEOUT constant is retired —
    --  the poll timeout is the ESS_POLL_TIMEOUT_MINUTES configuration
    --  value in DMT_CONFIG_TBL, read by DMT_QUEUE_WORKER_PKG.POLL_ONE;
    --  design section 2 "Timeouts (decided 2026-07-07)".)

    -- Heartbeat: called by DBMS_SCHEDULER every 60s.
    -- Promotes PENDING, polls ESS, spawns child jobs for
    -- READY/RECONCILING rows, handles failures, and rolls run
    -- statuses up from work items (the single RUN_STATUS writer).
    PROCEDURE HEARTBEAT_TICK;

    -- Legacy alias — calls HEARTBEAT_TICK.
    PROCEDURE PROCESS_QUEUE;

    -- Enable the permanent heartbeat job.
    PROCEDURE ENSURE_POLLER_RUNNING;

    -- Disable the heartbeat job if no active work remains.
    PROCEDURE STOP_POLLER_IF_IDLE;

END DMT_QUEUE_PKG;
/
