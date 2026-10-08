-- Drop the unreferenced packages that would bypass the central Fusion user if
-- revived (backlog #286, fixed under #309, 2026-10-07). Each read
-- FUSION_USERNAME / FUSION_PASSWORD straight from DMT_CONFIG_TBL instead of
-- going through DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS, and none has a caller in
-- db/, apex/ or scripts/ (grep-verified):
--   DMT_REST_LOADER_PKG -- generic REST loader, installed but never called
--   DMT_BIP_SETUP_PKG   -- BIP proof-of-concept package
-- Their .pks/.pkb files and @@ lines are removed from db/install.sql in the same
-- change, so a fresh install never creates them; this migration drops them from
-- a database created before the change. Run as DMT_OWNER.
--
-- Plain DROP statements (no dynamic SQL). Re-running on a database where the
-- packages are already gone reports ORA-04043 (object does not exist) for each
-- line and changes nothing, so the script is safe to re-run.
whenever sqlerror continue

prompt == Drop DMT_REST_LOADER_PKG ==
drop package DMT_REST_LOADER_PKG;

prompt == Drop DMT_BIP_SETUP_PKG ==
drop package DMT_BIP_SETUP_PKG;

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_drop_central_user_bypass_packages.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'dropbypasspkgs', USER);

commit;
