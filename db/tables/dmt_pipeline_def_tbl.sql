-- DMT_PIPELINE_DEF_TBL (DMT_DESIGN.html section 6 -- decided 2026-07-06;
-- complete seed content decided 2026-07-07, see db/seed/dmt_pipeline_def_tbl.sql)
-- Pipeline definitions: which objects each pipeline code runs, in what order,
-- with what dependencies. Replaces the hardcoded sequences in DMT_SCHEDULER_PKG
-- and feeds catalog-driven queue dispatch (section 12 backlog).
-- Every in-scope object has exactly one pipeline home (decided 2026-07-07),
-- hence the unique constraint on CEMLI_CODE alone.
-- DEPENDS_ON is a comma-separated list of canonical CEMLI codes (same format
-- DMT_WORK_QUEUE_TBL.DEPENDS_ON already uses; the queue engine strips spaces).
-- POSTRUN_JOB is the per-object post-run ESS job -- today only Assets has one;
-- every other object is explicitly none (NULL).

begin
  execute immediate 'CREATE TABLE "DMT_PIPELINE_DEF_TBL"
   (	"PIPELINE_DEF_ID" NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL ENABLE,
	"PIPELINE_CODE" VARCHAR2(30) NOT NULL ENABLE,
	"CEMLI_CODE" VARCHAR2(60) NOT NULL ENABLE,
	"SORT_ORDER" NUMBER NOT NULL ENABLE,
	"DEPENDS_ON" VARCHAR2(4000),
	"POSTRUN_JOB" VARCHAR2(500),
	 CONSTRAINT "DMT_PIPELINE_DEF_PK" PRIMARY KEY ("PIPELINE_DEF_ID")
  USING INDEX  ENABLE,
	 CONSTRAINT "DMT_PIPELINE_DEF_UK1" UNIQUE ("CEMLI_CODE")
  USING INDEX  ENABLE,
	 CONSTRAINT "DMT_PIPELINE_DEF_CK1" CHECK (
        PIPELINE_CODE IN (''P2P'',''O2C'',''PROJECTS'',''FINANCIALS'',''HCM'',''CONFIGURATION'')) ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

-- Contract index: the scheduler reads one pipeline's members in run order.
begin
  execute immediate 'CREATE INDEX "DMT_PIPELINE_DEF_N1" ON "DMT_PIPELINE_DEF_TBL" ("PIPELINE_CODE","SORT_ORDER")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
