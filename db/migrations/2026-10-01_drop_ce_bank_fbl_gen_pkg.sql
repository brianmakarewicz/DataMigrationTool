-- Drop DMT_CE_BANK_FBL_GEN_PKG (backlog #39, 2026-10-01). The Cash Management
-- Banks object (banks -> branches -> accounts) now loads to Fusion over the REST
-- resources (cashBanks / cashBankBranches / cashBankAccounts) through
-- DMT_CE_BANK_RESULTS_PKG, not a flat FBL file. The runner's "generate" step now
-- just promotes the STAGED TFM rows of all three tiers to GENERATED inline, so the
-- FBL generator is dead code with no remaining caller (grep-verified: its only
-- caller was DMT_CE_BANK_RUNNER_PKG, which no longer references it). Its .pks/.pkb
-- files are removed from db/packages and their @@ lines removed from db/install.sql
-- in the same change, so a fresh install never creates it; this migration drops it
-- from any instance created before the change.
--
-- Idempotent / re-runnable: the DROP is guarded on USER_OBJECTS, so a re-run on a
-- database where the package is already gone is a no-op.
DECLARE
    n NUMBER;
BEGIN
    SELECT COUNT(*) INTO n FROM user_objects
     WHERE object_name = 'DMT_CE_BANK_FBL_GEN_PKG' AND object_type = 'PACKAGE';
    IF n > 0 THEN
        EXECUTE IMMEDIATE 'DROP PACKAGE "DMT_CE_BANK_FBL_GEN_PKG"';
    END IF;
END;
/

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-01_drop_ce_bank_fbl_gen_pkg.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'dropcebankfbl', USER);

commit;
