-- DMT_HDL_MESSAGE_GTT -- session-private staging table for the HCM Data Loader
-- error messages of one data set (backlog #288, replaces the dynamic-SQL
-- DMT_HDL_UTIL_PKG.RECONCILE_HDL).
--
-- DMT_HDL_UTIL_PKG.STAGE_HDL_MESSAGES reads EVERY page of
--   GET .../dataLoadDataSets/{RequestId}/child/messages
-- (following hasMore, so a data set with more than one page of messages loses
-- nothing) and STATICALLY inserts one row per ERROR message here, keyed by the HDL
-- request id. ERROR_TEXT is the message already named for the reader:
--   [FUSION_ERROR] <SourceSystemId> (<file> line <n>): <message>
-- (the line part, the id part or both are dropped when Fusion did not supply them).
-- Each HCM object's DMT_<obj>_RESULTS_PKG then applies these rows to its own,
-- literally named TFM tables with STATIC SQL, matching each row on the exact
-- SourceSystemId its generator wrote. No EXECUTE IMMEDIATE anywhere.
--
-- ON COMMIT PRESERVE ROWS: reconciliation commits between steps; the staged
-- messages must survive until every TFM table of the object has been applied.
-- STAGE_HDL_MESSAGES deletes its own request's rows first, so a re-run (the base
-- lag retry) or a second object in the same session starts clean.
--
-- Guarded, idempotent DDL (permitted in install scripts only, design section 7).

begin
  execute immediate 'CREATE GLOBAL TEMPORARY TABLE "DMT_HDL_MESSAGE_GTT"
   (	"REQUEST_ID"        NUMBER NOT NULL,
	"MESSAGE_LINE_ID"   NUMBER,
	"SOURCE_SYSTEM_ID"  VARCHAR2(4000),
	"DAT_FILE_NAME"     VARCHAR2(240),
	"FILE_LINE"         NUMBER,
	"BUSINESS_OBJECT"   VARCHAR2(240),
	"MESSAGE_TEXT"      VARCHAR2(4000),
	"ERROR_TEXT"        VARCHAR2(4000)
   )  ON COMMIT PRESERVE ROWS';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

COMMENT ON TABLE "DMT_HDL_MESSAGE_GTT" IS 'Session GTT holding the HDL error messages of one data set (all pages), staged by DMT_HDL_UTIL_PKG.STAGE_HDL_MESSAGES; each HCM results package applies them to its own TFM tables with static SQL on the exact SourceSystemId. Backlog #288.';
COMMENT ON COLUMN "DMT_HDL_MESSAGE_GTT"."REQUEST_ID" IS 'HDL data set RequestId (the work item LOAD_ESS_JOB_ID) the message belongs to.';
COMMENT ON COLUMN "DMT_HDL_MESSAGE_GTT"."MESSAGE_LINE_ID" IS 'Fusion MessageLineId (order within a file line).';
COMMENT ON COLUMN "DMT_HDL_MESSAGE_GTT"."SOURCE_SYSTEM_ID" IS 'SourceSystemId of the record the message is about; NULL for file-level and data-set-level messages.';
COMMENT ON COLUMN "DMT_HDL_MESSAGE_GTT"."DAT_FILE_NAME" IS 'The .dat file the message is about (e.g. Worker.dat); NULL for data-set-level messages.';
COMMENT ON COLUMN "DMT_HDL_MESSAGE_GTT"."FILE_LINE" IS 'Line number in the .dat file; NULL when Fusion reports against the logical object only.';
COMMENT ON COLUMN "DMT_HDL_MESSAGE_GTT"."BUSINESS_OBJECT" IS 'Fusion BusinessObjectDiscriminator (e.g. WorkTerms).';
COMMENT ON COLUMN "DMT_HDL_MESSAGE_GTT"."MESSAGE_TEXT" IS 'Fusion MessageText, verbatim.';
COMMENT ON COLUMN "DMT_HDL_MESSAGE_GTT"."ERROR_TEXT" IS '[FUSION_ERROR] <SourceSystemId> (<file> line <n>): <MessageText>, built by DMT_HDL_UTIL_PKG.FORMAT_HDL_ERROR.';
