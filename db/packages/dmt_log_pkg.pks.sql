-- PACKAGE DMT_LOG_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_LOG_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_LOG_PKG
-- Maintenance for the execution log DMT_LOG_TBL.
--
-- Backlog #149. DMT_LOG_TBL grows without bound (every pipeline run adds
-- thousands of rows -- regression run 225 alone logged ~9,877, and the table
-- stood at ~157k). This package adds a SAFE, bounded way to prune old log
-- rows so the table -- and the page-54 Activity-Log drill that reads it --
-- stay fast, WITHOUT ever touching recent or still-running activity.
--
-- Retention is config-driven: DMT_CONFIG_TBL key RETENTION_DAYS (default 90),
-- read via DMT_UTIL_PKG.GET_CONFIG. The seeded description of that key already
-- names activity-log entries as in scope.
--
-- Three hard, non-negotiable safety guards (a prune can NEVER delete recent or
-- in-flight data, whatever the config says):
--   1. MINIMUM FLOOR. Nothing newer than C_MIN_RETENTION_DAYS (7) is ever
--      deleted, even if RETENTION_DAYS is set smaller or to a bad value. The
--      effective cutoff is SYSDATE - GREATEST(RETENTION_DAYS, 7).
--   2. ACTIVE-RUN PROTECTION. A log row is kept if its RUN_ID belongs to a
--      pipeline run that is NOT in a terminal state (still QUEUED or
--      IN_PROGRESS) OR whose run row is itself newer than the cutoff. The
--      current and recent runs are never pruned regardless of a log row's own
--      age.
--   3. NULL retention / missing config resolves to the default 90, never to
--      "delete everything".
--
-- The deletes are batched (COMMIT every C_BATCH_SIZE rows) so a large purge
-- never holds one giant transaction. A dry-run mode reports what WOULD be
-- deleted without deleting. Nothing here is auto-scheduled destructively; this
-- is a callable procedure. It may be wired to run at a safe point (e.g. after
-- a run completes) by a caller that accepts the retention guard above.
-- ============================================================

    -- Default retention when RETENTION_DAYS is unset or non-numeric.
    C_DEFAULT_RETENTION_DAYS CONSTANT PLS_INTEGER := 90;

    -- Hard floor: a prune can NEVER delete anything newer than this many days,
    -- no matter what RETENTION_DAYS says. The last line of defence for recent
    -- data.
    C_MIN_RETENTION_DAYS     CONSTANT PLS_INTEGER := 7;

    -- Delete batch size (rows per COMMIT).
    C_BATCH_SIZE             CONSTANT PLS_INTEGER := 5000;

    -- Resolve the effective retention in days: GREATEST(RETENTION_DAYS, floor),
    -- with the default substituted when the config key is missing or not a
    -- valid positive number. Exposed so callers / the dry run can report it.
    FUNCTION EFFECTIVE_RETENTION_DAYS RETURN PLS_INTEGER;

    -- Count how many DMT_LOG_TBL rows the current config WOULD delete, applying
    -- every safety guard. Reads only -- deletes nothing. Use this to preview a
    -- prune before running it.
    FUNCTION ROWS_ELIGIBLE_FOR_PRUNE RETURN PLS_INTEGER;

    -- Prune old activity-log rows beyond the effective retention, honouring all
    -- three safety guards above. Batched + committed. Non-destructive to recent
    -- and in-flight runs.
    --
    --   p_dry_run    : TRUE (default) counts and logs what WOULD be deleted but
    --                  deletes nothing. Pass FALSE to actually delete. The safe
    --                  default means an accidental call to THIS (three-argument)
    --                  overload never destroys data. The no-argument overload
    --                  below is the deliberate real-delete entry point.
    --   x_deleted    : rows deleted (0 on a dry run).
    --   x_error_code : DMT_UTIL_PKG.C_SUCCESS or C_ERROR. On C_ERROR the detail
    --                  is in DMT_LOG_TBL; exceptions never escape.
    PROCEDURE PRUNE_LOGS (
        p_dry_run    IN  BOOLEAN DEFAULT TRUE,
        x_deleted    OUT NUMBER,
        x_error_code OUT NUMBER
    );

    -- Convenience wrapper for a scheduler / APEX button: prune for real and
    -- swallow the outcome into the activity log. Never raises.
    PROCEDURE PRUNE_LOGS;

END DMT_LOG_PKG;
/
