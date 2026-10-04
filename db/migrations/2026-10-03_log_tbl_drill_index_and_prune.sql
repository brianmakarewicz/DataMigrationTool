-- ---------------------------------------------------------------------------
-- Backlog #149 — make the page-54 Activity-Log per-row drill fast under log
-- volume, and add a bounded log-pruning mechanism for DMT_LOG_TBL.
--
-- Context (regression run 225): DMT_LOG_TBL had grown to ~157k rows (run 225
-- alone logged ~9,877). The page-54 drill is always run-scoped — it arrives
-- with P54_RUN_ID set — and its main report filters RUN_ID then sorts
-- LOG_DATE DESC, LOG_ID DESC, while the Previous/Next navigation range-scans
-- LOG_ID within a RUN_ID. The existing single-column DMT_LOG_N1 (RUN_ID)
-- served the filter but forced a SORT for the order-by, and the big table made
-- that slow on the local Docker ORDS, blowing the 90s client read timeout.
--
-- Part 1 — Index. Composite DMT_LOG_N4 (RUN_ID, LOG_DATE, LOG_ID) serves the
-- report's RUN_ID filter AND its (LOG_DATE DESC, LOG_ID DESC) order in one
-- index range scan (no sort), and also serves the Prev/Next LOG_ID range scans
-- scoped to a RUN_ID. Guarded + idempotent (ORA-00955 name-in-use and
-- ORA-01408 column-list-already-indexed are both ignored), so re-running the
-- migration is a no-op.
--
-- Part 2 — Prune. No schema change here — the pruning procedure lives in
-- DMT_LOG_PKG (db/packages/dmt_log_pkg.pk{s,b}.sql) and the retention is the
-- existing DMT_CONFIG_TBL key RETENTION_DAYS (default 90), whose seeded
-- description already covers activity-log entries. This migration only creates
-- the index; the package is installed by the normal package install step.
-- ---------------------------------------------------------------------------

BEGIN
  EXECUTE IMMEDIATE
    'CREATE INDEX "DMT_LOG_N4" ON "DMT_LOG_TBL" ("RUN_ID","LOG_DATE","LOG_ID")';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE NOT IN (-955, -1408) THEN RAISE; END IF;
END;
/
