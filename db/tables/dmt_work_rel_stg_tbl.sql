-- DMT_WORK_REL_STG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_WORK_REL_STG_TBL" 
   (	"STG_SEQUENCE_ID" NUMBER DEFAULT DMT_OWNER.DMT_WORK_REL_STG_SEQ.NEXTVAL NOT NULL ENABLE, 
	"EFFECTIVE_START_DATE" VARCHAR2(240), 
	"EFFECTIVE_END_DATE" VARCHAR2(240), 
	"PERSON_NUMBER" VARCHAR2(240), 
	"LEGAL_EMPLOYER_NAME" VARCHAR2(240), 
	"ACTION_CODE" VARCHAR2(240), 
	"WORKER_TYPE" VARCHAR2(240), 
	"DATE_START" VARCHAR2(240), 
	"PRIMARY_FLAG" VARCHAR2(240), 
	"SOURCE_ID" VARCHAR2(200), 
	"STAGE_DATE" DATE DEFAULT SYSDATE, 
	"STG_STATUS" VARCHAR2(30) DEFAULT ''NEW'', 
	"ERROR_TEXT" CLOB, 
	"LAST_UPDATED_DATE" DATE, 
	"SCENARIO_ID" NUMBER, 
	 CONSTRAINT "DMT_WORK_REL_STG_PK" PRIMARY KEY ("STG_SEQUENCE_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

-- 2026-07-08 conformance tranche: rename must precede the index DDL below
-- (a pre-existing database still has the old column when the index runs).
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_WORK_REL_STG_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_WORK_REL_STG_TBL" RENAME COLUMN "STATUS" TO "STG_STATUS"';
  end if;
end;
/

COMMENT ON COLUMN "DMT_WORK_REL_STG_TBL"."STG_SEQUENCE_ID" IS 'PK - from DMT_WORK_REL_STG_SEQ. Populated by DB default, never supplied by user.';
COMMENT ON COLUMN "DMT_WORK_REL_STG_TBL"."PERSON_NUMBER" IS 'Worker person number â€” links to Worker record in Fusion HCM';
COMMENT ON COLUMN "DMT_WORK_REL_STG_TBL"."ACTION_CODE" IS 'HIRE, ADD_CWK, or ADD_PEND_WKR';
COMMENT ON COLUMN "DMT_WORK_REL_STG_TBL"."WORKER_TYPE" IS 'E=Employee, C=Contingent Worker';
COMMENT ON COLUMN "DMT_WORK_REL_STG_TBL"."SOURCE_ID" IS 'Natural key from source system';
COMMENT ON COLUMN "DMT_WORK_REL_STG_TBL"."ERROR_TEXT" IS 'Concatenated errors. Appended at each step - never overwritten.';
COMMENT ON TABLE "DMT_WORK_REL_STG_TBL"  IS 'WorkRelationship staging. Raw user-loaded data only. Run-specific data in DMT_WORK_REL_TFM_TBL. HDL business object: WorkRelationship.';

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche (design section 7: STG/TFM infra-column
-- dictionary + contract-index dictionary): converges a pre-existing database.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
begin
  execute immediate 'CREATE INDEX "DMT_WORK_REL_STG_N1" ON "DMT_WORK_REL_STG_TBL" ("STG_STATUS")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_WORK_REL_STG_N2" ON "DMT_WORK_REL_STG_TBL" ("SCENARIO_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_WORK_REL_STG_TBL"."STG_STATUS" IS 'Staging lifecycle: NEW > TRANSFORMED / FAILED. Forward-only, never reset; errors accumulate in ERROR_TEXT.';
