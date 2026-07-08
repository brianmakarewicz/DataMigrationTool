-- DMT_STG_TFM_ERROR_TBL (DMT_DESIGN.html section 5 -- decided 2026-07-06, refined 2026-07-07)
-- Run-stamped home for staging rows that die before TFM (pre-validation /
-- transform failures). Errors only: success is the TFM row itself (run-stamped,
-- timestamped) -- no success rows are written here. ERROR_TEXT carries the
-- section-5 tags ([PRE_VALIDATION] or [TRANSFORM_ERROR]).
-- No TFM_SEQUENCE_ID by design: these rows have no TFM row by definition.
-- No foreign keys by design (same rationale as DMT_LOG_TBL, section 5):
-- diagnostics must never fail to write because of referential ordering, and
-- STG_SEQUENCE_ID points at a different STG table per CEMLI/SUB_OBJECT.
-- Retention: rows past RETENTION_DAYS are deleted by the purge job (section 6).

begin
  execute immediate 'CREATE TABLE "DMT_STG_TFM_ERROR_TBL"
   (	"ERROR_ID" NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL ENABLE,
	"RUN_ID" NUMBER NOT NULL ENABLE,
	"QUEUE_ID" NUMBER,
	"CEMLI_CODE" VARCHAR2(60) NOT NULL ENABLE,
	"SUB_OBJECT" VARCHAR2(200),
	"STG_SEQUENCE_ID" NUMBER NOT NULL ENABLE,
	"ERROR_TEXT" CLOB,
	"CREATED_DATE" DATE DEFAULT SYSDATE NOT NULL ENABLE,
	 CONSTRAINT "DMT_STG_TFM_ERROR_PK" PRIMARY KEY ("ERROR_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

-- Contract indexes (section 5 backlog: "index RUN_ID and QUEUE_ID"):
-- every funnel / run-detail / retention query keys on RUN_ID; the Activity
-- Log / Object Detail attribution path keys on QUEUE_ID.
begin
  execute immediate 'CREATE INDEX "DMT_STG_TFM_ERROR_N1" ON "DMT_STG_TFM_ERROR_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_STG_TFM_ERROR_N2" ON "DMT_STG_TFM_ERROR_TBL" ("QUEUE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
