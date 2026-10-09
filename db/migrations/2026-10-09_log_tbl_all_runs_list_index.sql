-- ---------------------------------------------------------------------------
-- Backlog #150 follow-up: make the page-54 Activity Log list fast when no run
-- is selected (the all-runs list).
--
-- The run-scoped list (P54_RUN_ID set, the normal path from Run Detail) was
-- fixed by #150: it walks DMT_LOG_N4 (RUN_ID, LOG_DATE, LOG_ID) descending.
-- The all-runs list orders the whole log table by LOG_DATE DESC, LOG_ID DESC
-- and had no index for that order, so it read every row and sorted them
-- (TABLE ACCESS FULL + SORT ORDER BY, ~186k rows on local).
--
-- This composite serves that order directly. The all-runs list query carries
-- an INDEX_DESC(l DMT_LOG_N5) hint (apex/f501src page 54, region
-- log-entries-all). Guarded and idempotent: ORA-00955 (name in use) and
-- ORA-01408 (column list already indexed) are both ignored, so re-running this
-- file is a no-op. The same block is in db/tables/dmt_log_tbl.sql for fresh
-- installs.
-- ---------------------------------------------------------------------------

BEGIN
  EXECUTE IMMEDIATE
    'CREATE INDEX "DMT_LOG_N5" ON "DMT_LOG_TBL" ("LOG_DATE","LOG_ID")';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE NOT IN (-955, -1408) THEN RAISE; END IF;
END;
/
