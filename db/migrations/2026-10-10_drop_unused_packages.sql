BEGIN EXECUTE IMMEDIATE 'DROP PACKAGE DMT_RECON_ENGINE_PKG'; EXCEPTION WHEN OTHERS THEN IF SQLCODE = -4043 THEN NULL; ELSE RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE DMT_RECON_STAGE_GTT PURGE'; EXCEPTION WHEN OTHERS THEN IF SQLCODE = -942 THEN NULL; ELSE RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP PACKAGE DMT_POZ_SUP_ADDR_VALIDATOR_PKG'; EXCEPTION WHEN OTHERS THEN IF SQLCODE = -4043 THEN NULL; ELSE RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP PACKAGE DMT_POZ_SUP_SITE_VALIDATOR_PKG'; EXCEPTION WHEN OTHERS THEN IF SQLCODE = -4043 THEN NULL; ELSE RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP PACKAGE DMT_POZ_SUP_SITE_ASSN_VALIDATOR_PKG'; EXCEPTION WHEN OTHERS THEN IF SQLCODE = -4043 THEN NULL; ELSE RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP PACKAGE DMT_POZ_SUP_CONT_VALIDATOR_PKG'; EXCEPTION WHEN OTHERS THEN IF SQLCODE = -4043 THEN NULL; ELSE RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP PACKAGE DMT_REGRESSION_PKG'; EXCEPTION WHEN OTHERS THEN IF SQLCODE = -4043 THEN NULL; ELSE RAISE; END IF; END;
/
merge into DMT_MIGRATION_LOG t using (select '2026-10-10_drop_unused_packages.sql' migration_name from dual) s on (t.migration_name = s.migration_name) when not matched then insert (migration_name, checksum, applied_by) values (s.migration_name, 'dropunusedpkgs', USER);
commit;
-- ----------------------------------------------------------------------
-- Migration 2026-10-10: drop packages nothing calls (backlog #731 plus the
-- owner-approved unused-package audit of 2026-10-10).
--
-- Dropped, each proven unreferenced: no other package, view, trigger,
-- procedure or type depends on it (USER_DEPENDENCIES on the local database),
-- no other object's source names it (USER_SOURCE), no scheduler job or
-- program runs it, no registry row names it (DMT_PIPELINE_DEF_TBL,
-- DMT_CEMLI_CATALOG_TBL, DMT_BIP_REPORT_TBL or any other table column that
-- holds a PKG.PROC), and nothing in db/, apex/, bip/, scripts/ or test/
-- calls it (no dynamic EXECUTE IMMEDIATE string builds its name either).
--
--   DMT_RECON_ENGINE_PKG  the dormant generic Contract v1 reconcile engine.
--       GLBalances, its only user, moved back to its own reconciler on
--       2026-09-30. Its session staging table DMT_RECON_STAGE_GTT, read and
--       written only by this package, is dropped with it, and the engine's
--       dispatch helper DMT_QUEUE_WORKER_PKG.INVOKE_APPLY is removed in the
--       same change.
--   DMT_POZ_SUP_ADDR_VALIDATOR_PKG, DMT_POZ_SUP_SITE_VALIDATOR_PKG,
--   DMT_POZ_SUP_SITE_ASSN_VALIDATOR_PKG, DMT_POZ_SUP_CONT_VALIDATOR_PKG
--       pass-through stubs. The four supplier child objects are validated by
--       DMT_POZ_SUP_VALIDATOR_PKG (VALIDATE_ADDRESSES, VALIDATE_SITES,
--       VALIDATE_SITE_ASSIGNMENTS, VALIDATE_CONTACTS), called from
--       DMT_LOADER_PKG.
--   DMT_REGRESSION_PKG  a spec-only package holding one global variable
--       (G_IID) that no code reads or writes.
--
-- The package and table files and their db/install.sql lines are removed in
-- the same change, so a fresh install never creates them; this migration
-- converges an existing database.
--
-- Idempotent: each drop runs only if the object exists (ORA-04043 package
-- does not exist, ORA-00942 table does not exist, are swallowed; any other
-- error raises), and the migration-log MERGE inserts once. Executable
-- statements lead and each is one physical line (deploy runner splitting
-- rule, backlog #81).
-- ----------------------------------------------------------------------
