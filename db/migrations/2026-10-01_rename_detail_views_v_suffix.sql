DECLARE TYPE t IS TABLE OF VARCHAR2(128); l t := t(q'[DMT_V_ABSENCE_DETAIL]',q'[DMT_V_AP_INV_LINES_DETAIL]',q'[DMT_V_AP_INVOICES_DETAIL]',q'[DMT_V_AR_DISTS_DETAIL]',q'[DMT_V_AR_LINES_DETAIL]',q'[DMT_V_ASSET_ASSIGN_DETAIL]',q'[DMT_V_ASSET_BOOK_DETAIL]',q'[DMT_V_ASSET_HDR_DETAIL]',q'[DMT_V_ASSIGNMENT_DETAIL]',q'[DMT_V_BEN_BENFY_DETAIL]',q'[DMT_V_BEN_DEPEND_DETAIL]',q'[DMT_V_BEN_PARTIC_DETAIL]',q'[DMT_V_BILL_EVENTS_DETAIL]',q'[DMT_V_CUST_ACCOUNTS_DETAIL]',q'[DMT_V_CUST_ACCT_SITE_USES_DETAIL]',q'[DMT_V_CUST_ACCT_SITES_DETAIL]',q'[DMT_V_CUST_LOCATIONS_DETAIL]',q'[DMT_V_CUST_PARTIES_DETAIL]',q'[DMT_V_CUST_PARTY_SITES_DETAIL]',q'[DMT_V_CUST_SITE_USES_DETAIL]',q'[DMT_V_EXPENDITURES_DETAIL]',q'[DMT_V_GL_BUDGET_DETAIL]',q'[DMT_V_GL_JOURNAL_DETAIL]',q'[DMT_V_GRANT_BDGT_PRDS_DETAIL]',q'[DMT_V_GRANT_CERTS_DETAIL]',q'[DMT_V_GRANT_CFDAS_DETAIL]',q'[DMT_V_GRANT_FUND_ALLOC_DETAIL]',q'[DMT_V_GRANT_FUND_SRC_DETAIL]',q'[DMT_V_GRANT_FUNDING_DETAIL]',q'[DMT_V_GRANT_HEADERS_DETAIL]',q'[DMT_V_GRANT_KEYWORDS_DETAIL]',q'[DMT_V_GRANT_ORG_CREDITS_DETAIL]',q'[DMT_V_GRANT_PERSONNEL_DETAIL]',q'[DMT_V_GRANT_PRJ_FUND_SRC_DETAIL]',q'[DMT_V_GRANT_PRJ_TSK_BRD_DETAIL]',q'[DMT_V_GRANT_PROJECTS_DETAIL]',q'[DMT_V_GRANT_REFERENCES_DETAIL]',q'[DMT_V_GRANT_TERMS_DETAIL]',q'[DMT_V_PERF_EVAL_DETAIL]',q'[DMT_V_PERF_EVAL_RATING_DETAIL]',q'[DMT_V_PERSON_ADDR_DETAIL]',q'[DMT_V_PERSON_EMAIL_DETAIL]',q'[DMT_V_PERSON_LEGISL_DETAIL]',q'[DMT_V_PERSON_NAME_DETAIL]',q'[DMT_V_PERSON_NID_DETAIL]',q'[DMT_V_PERSON_PHONE_DETAIL]',q'[DMT_V_PLAN_BUDGET_DETAIL]',q'[DMT_V_PO_DISTS_DETAIL]',q'[DMT_V_PO_HEADERS_DETAIL]',q'[DMT_V_PO_LINE_LOCS_DETAIL]',q'[DMT_V_PO_LINES_DETAIL]',q'[DMT_V_PRJ_BUDGET_DETAIL]',q'[DMT_V_PROJECT_TASKS_DETAIL]',q'[DMT_V_PROJECT_TEAM_DETAIL]',q'[DMT_V_PROJECTS_DETAIL]',q'[DMT_V_RCV_HEADERS_DETAIL]',q'[DMT_V_RCV_TRANSACTIONS_DETAIL]',q'[DMT_V_REQ_DISTS_DETAIL]',q'[DMT_V_REQ_HEADERS_DETAIL]',q'[DMT_V_REQ_LINES_DETAIL]',q'[DMT_V_SAL_BASIS_DETAIL]',q'[DMT_V_SALARY_DETAIL]',q'[DMT_V_SUP_ADDR_DETAIL]',q'[DMT_V_SUP_CONTACTS_DETAIL]',q'[DMT_V_SUP_SITE_ASSN_DETAIL]',q'[DMT_V_SUP_SITE_DETAIL]',q'[DMT_V_SUPPLIERS_DETAIL]',q'[DMT_V_TALENT_PROF_DETAIL]',q'[DMT_V_TALENT_PROF_ITEM_DETAIL]',q'[DMT_V_TAX_CARD_COMP_DETAIL]',q'[DMT_V_TAX_CARD_DETAIL]',q'[DMT_V_TXN_CONTROLS_DETAIL]',q'[DMT_V_W2_BAL_DETAIL]',q'[DMT_V_W2_BAL_DTL_DETAIL]',q'[DMT_V_WORK_REL_DETAIL]',q'[DMT_V_WORK_SCHED_DETAIL]',q'[DMT_V_WORK_SCHED_DTL_DETAIL]',q'[DMT_V_WORKER_DETAIL]'); n NUMBER; BEGIN FOR i IN 1..l.COUNT LOOP SELECT COUNT(*) INTO n FROM user_views WHERE view_name=l(i); IF n>0 THEN EXECUTE IMMEDIATE 'DROP VIEW "'||l(i)||'"'; END IF; END LOOP; END;
/

-- ----------------------------------------------------------------------
-- Migration 2026-10-01: rename the 78 DMT_V_<x>_DETAIL drill views to the
-- canonical DMT_<x>_DETAIL_V (*_V suffix) convention (backlog #25, naming
-- conformance sweep). The renamed CREATE OR REPLACE view files now live at
-- db/views/dmt_<x>_detail_v.sql and their @@ lines in db/install.sql point at
-- the new names, so a FRESH install creates only the new-named views. This
-- migration converges an EXISTING database (created before the rename) by
-- dropping the 78 old-named views; the new-named views are (re)created by the
-- view-deploy step that runs the committed db/views/*.sql files.
--
-- Behaviour is unchanged: every view's SELECT is byte-identical to before --
-- only the object name changed. Every APEX region that read an old name has
-- been repointed to the new name in the single source of truth
-- (apex/f501src/livedmt2/pages/*.apx, imported to local app 501 / ATP app 500)
-- and in the legacy split-SQL baseline (apex/f500/application/pages/*.sql), so
-- no console page points at a dropped view.
--
-- Idempotent / re-runnable: each DROP is guarded on USER_VIEWS, so a re-run on
-- a database where the old views are already gone is a no-op. The executable
-- PL/SQL block is the FIRST statement and is written on a SINGLE physical line
-- (the deploy runner, scripts/dmt_deploy.py, splits on ";\n" / "/\n" and skips
-- chunks beginning with "--", so a leading executable one-liner with its "/"
-- alone on the next line is the only shape that runs reliably -- same pattern
-- as 2026-09-22_drop_dead_pay_rel_detail_view.sql, backlog #81).
-- ----------------------------------------------------------------------

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-01_rename_detail_views_v_suffix.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'renamedetailv', USER);

commit;
