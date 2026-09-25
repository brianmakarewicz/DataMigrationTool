-- Grant EXECUTE on DMT_CSV_INGEST_PKG to the EBS adaptor (issue #469).
-- The EBS-side push calls START_FILE / APPEND_CHUNK remotely over ATP_LINK to
-- land large CSV CLOBs chunk by chunk (LOB append runs locally as DMT2_OWNER).
-- Grantee EBS_ADAPTOR may not exist on a local test DB; errors are tolerated
-- in install.sql (see grants_made.sql for the same convention).
whenever sqlerror continue
GRANT EXECUTE ON "DMT_CSV_INGEST_PKG" TO "EBS_ADAPTOR";
whenever sqlerror exit failure rollback
