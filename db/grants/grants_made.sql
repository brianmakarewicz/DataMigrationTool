-- Grants MADE by DMT_OWNER on its objects.
-- Grantees may not exist on a local test DB; errors are tolerated in install.sql.
whenever sqlerror continue
GRANT SELECT ON "DMT_CONFIG_TBL" TO "DMT_LOOKUP";
GRANT SELECT ON "DMT_LOG_ID_SEQ" TO "DMT_LOOKUP";
GRANT INSERT ON "DMT_LOG_TBL" TO "DMT_LOOKUP";
GRANT SELECT ON "DMT_LOG_TBL" TO "DMT_LOOKUP";
GRANT INHERIT PRIVILEGES ON "DMT_OWNER" TO "PUBLIC";
whenever sqlerror exit failure rollback
