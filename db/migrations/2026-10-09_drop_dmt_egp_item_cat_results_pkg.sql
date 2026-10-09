BEGIN EXECUTE IMMEDIATE 'DROP PACKAGE DMT_EGP_ITEM_CAT_RESULTS_PKG'; EXCEPTION WHEN OTHERS THEN IF SQLCODE = -4043 THEN NULL; ELSE RAISE; END IF; END;
/
merge into DMT_MIGRATION_LOG t using (select '2026-10-09_drop_dmt_egp_item_cat_results_pkg.sql' migration_name from dual) s on (t.migration_name = s.migration_name) when not matched then insert (migration_name, checksum, applied_by) values (s.migration_name, 'dropitemcatresults', USER);
commit;
-- ----------------------------------------------------------------------
-- Migration 2026-10-09: drop the dead DMT_EGP_ITEM_CAT_RESULTS_PKG
-- (backlog #607).
--
-- Item categories ride in the Items FBDI zip and are reconciled by the Items
-- report V3 (record type ItemCategory) through
-- DMT_EGP_ITEM_RESULTS_PKG.APPLY_CONTRACT_V1_ITEMS (backlog #480 / #482).
-- Nothing calls DMT_EGP_ITEM_CAT_RESULTS_PKG: no pipeline definition, queue
-- step, reconcile or reset registry row, package, view or APEX process names
-- it (USER_DEPENDENCIES shows no dependant; the only USER_SOURCE mentions are
-- comments in DMT_LOADER_PKG and DMT_QUEUE_WORKER_PKG recording that it is
-- retired). It still sent the retired P_BATCH_ID = run id to the retired
-- ITEM_CAT_DM report.
--
-- Its two package files, their db/install.sql lines and the orphan
-- bip/ItemCategories files (ITEM_CAT_DM.xdm, ITEM_CAT_RPT.xdo, query.sql) are
-- removed in the same change, so a fresh install never creates it; this
-- migration converges an existing database. The Fusion catalog copies of the
-- retired report are left in place (this work never deletes a Fusion BIP
-- object).
--
-- Idempotent: the drop runs only if the package exists (ORA-04043, object
-- does not exist, is swallowed; any other error raises), and the migration-log
-- MERGE inserts once. Executable statements lead and each is one physical
-- line (deploy runner splitting rule, backlog #81).
-- ----------------------------------------------------------------------
