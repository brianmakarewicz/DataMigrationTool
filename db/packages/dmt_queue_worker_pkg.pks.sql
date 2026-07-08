-- PACKAGE DMT_QUEUE_WORKER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_QUEUE_WORKER_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_QUEUE_WORKER_PKG — Child job entry points
--
-- Separate package from DMT_QUEUE_PKG so that one-shot child
-- jobs (DMT_WQ_*, DMT_RC_*) don't acquire a library cache lock
-- on the heartbeat package. This prevents self-deadlock when the
-- heartbeat spawns children via DBMS_SCHEDULER.CREATE_JOB.
-- ============================================================

    -- Execute one queue row: validate + transform + generate + submit.
    PROCEDURE EXECUTE_ONE (p_queue_id IN NUMBER);

    -- Reconcile one queue row via BIP.
    PROCEDURE RECONCILE_ONE (p_queue_id IN NUMBER);

    -- Poll ESS status for one queue row (single check, no loop).
    -- Advances AWAITING_LOAD → AWAITING_IMPORT or RECONCILING.
    -- Advances AWAITING_IMPORT → RECONCILING.
    PROCEDURE POLL_ONE (p_queue_id IN NUMBER);

END DMT_QUEUE_WORKER_PKG;
/
