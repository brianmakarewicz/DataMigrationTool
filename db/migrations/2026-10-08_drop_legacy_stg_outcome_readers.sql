BEGIN EXECUTE IMMEDIATE 'DROP VIEW DMT_DASHBOARD_CEMLI_SUMMARY_V'; EXCEPTION WHEN OTHERS THEN IF SQLCODE IN (-942, -4043) THEN NULL; ELSE RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP VIEW DMT_SCENARIO_SUMMARY_V'; EXCEPTION WHEN OTHERS THEN IF SQLCODE IN (-942, -4043) THEN NULL; ELSE RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP PACKAGE DMT_REPORT_PKG'; EXCEPTION WHEN OTHERS THEN IF SQLCODE IN (-942, -4043) THEN NULL; ELSE RAISE; END IF; END;
/
-- ----------------------------------------------------------------------
-- Migration 2026-10-08: drop the legacy readers of STG outcome status
-- (backlog #400).
--
-- Reconciliation stopped writing LOADED / FAILED and error text back to the
-- STG tables in backlog #310; the outcome lives only on the TFM row and, for
-- rows that never reached TFM, in DMT_STG_TFM_ERROR_TBL. The design document
-- (section 7, "Reporting derives success from TFM and pre-TFM errors from the
-- error table - never from STG") forbids reading an outcome from STG. These
-- three objects still did, so they reported frozen data:
--   DMT_SCENARIO_SUMMARY_V         - STG_STATUS per STG table, read only by
--   DMT_DASHBOARD_CEMLI_SUMMARY_V  - counted STG_STATUS = 'LOADED' / 'FAILED'
--   DMT_REPORT_PKG                 - GET_SUPPLIER_ERRORS read STG_STATUS =
--                                    'FAILED' and STG ERROR_TEXT; its other
--                                    function GET_INTEGRATION_SUMMARY had no
--                                    caller either.
-- Nothing references any of them: no package, view or script in the repo, no
-- APEX page region or process on the local database, and USER_DEPENDENCIES
-- shows only the dashboard view depending on the scenario view. They are
-- deleted rather than rebuilt; the Run Detail and Object Detail screens already
-- read outcomes from TFM through DMT_RECORD_DETAIL_V and its siblings.
--
-- The object files and their db/install.sql lines are removed in the same
-- change, so a fresh install never creates them; this migration converges an
-- existing database. Idempotent: each drop swallows ORA-00942 / ORA-04043
-- (object already gone). The dashboard view is dropped before the view it
-- reads. Executable blocks lead and each is one physical line followed by "/"
-- (deploy runner splitting rule, backlog #81).
-- ----------------------------------------------------------------------
