-- Grants MADE by DMT_OWNER on its objects.
-- Grantees may not exist on a local test DB; errors are tolerated in install.sql.
whenever sqlerror continue
GRANT SELECT ON "DMT_CONFIG_TBL" TO "DMT_LOOKUP";
GRANT SELECT ON "DMT_LOG_ID_SEQ" TO "DMT_LOOKUP";
GRANT INSERT ON "DMT_LOG_TBL" TO "DMT_LOOKUP";
GRANT SELECT ON "DMT_LOG_TBL" TO "DMT_LOOKUP";
-- Schema-relative: grant on the CONNECTED owner, not a literal schema name.
begin execute immediate 'GRANT INHERIT PRIVILEGES ON "' || USER || '" TO PUBLIC'; exception when others then null; end;
/
whenever sqlerror exit failure rollback
