-- DMT_MOCK_TFM_TBL (Stage C task 4, 2026-07-08)
-- Transform-layer table for the Mock engine-test objects (MockObject /
-- MockChild, DMT_MOCK_PKG). Exists so the queue engine's catalog-driven
-- accounting gate (design section 5 "Object-status accounting" + the
-- Overview work-item DONE/FAILED rows) and run-status rollup (Overview
-- run-status table: COMPLETED_ERRORS / NO_ROWS_PROCESSED read ROW
-- outcomes) can be proven offline with real countable rows.
-- The table ships empty in production (DMT_MOCK_PKG must compile against
-- it); the mock REGISTRATION rows (pipeline def, catalog, MOCK_* config
-- keys) are test-setup only — test/unit/setup_mock_objects.sql — so no
-- mock object is ever dispatchable on a production install.
-- Status vocabulary mirrors the Overview TFM row-status table:
-- STAGED / GENERATED / LOADED / FAILED / UNACCOUNTED.
-- UNACCOUNTED (added 2026-07-21): the real stored terminal status set by the
-- one shared unaccounted sweep (DMT_QUEUE_WORKER_PKG.SWEEP_UNACCOUNTED) for a
-- row reconciliation could neither confirm LOADED nor mark FAILED with a real
-- Fusion error. DMT_MOCK_TFM_TBL is the only TFM table carrying an IN-list
-- CHECK on TFM_STATUS; every other TFM table constrains TFM_STATUS to NOT NULL
-- only, so the sweep's UPDATE ... = 'UNACCOUNTED' is already accepted there.

begin
  execute immediate 'CREATE TABLE "DMT_MOCK_TFM_TBL"
   (	"MOCK_ID" NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL ENABLE,
	"RUN_ID" NUMBER NOT NULL ENABLE,
	"CEMLI_CODE" VARCHAR2(60) NOT NULL ENABLE,
	"RECORD_KEY" VARCHAR2(200),
	"TFM_STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE,
	"ERROR_TEXT" CLOB,
	"CREATED_DATE" DATE DEFAULT SYSDATE,
	 CONSTRAINT "DMT_MOCK_TFM_PK" PRIMARY KEY ("MOCK_ID")
  USING INDEX  ENABLE,
	 CONSTRAINT "DMT_MOCK_TFM_STATUS_CK" CHECK (
        TFM_STATUS IN (''STAGED'',''GENERATED'',''LOADED'',''FAILED'',''UNACCOUNTED'')) ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_MOCK_TFM_RUN_IX" ON "DMT_MOCK_TFM_TBL" ("RUN_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

-- ---------------------------------------------------------------------------
-- 2026-07-08 conformance tranche: STATUS renamed to TFM_STATUS (the catalog-
-- driven engine reads STATUS_COLUMN from DMT_CEMLI_CATALOG_TBL, now uniformly
-- TFM_STATUS). Converges a pre-existing database; the check constraint is
-- dropped and re-added because its condition text names the column.
-- Fresh installs already get the final shape from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_MOCK_TFM_TBL' and column_name = 'STATUS';
  if l_n = 1 then
    begin
      execute immediate 'ALTER TABLE "DMT_MOCK_TFM_TBL" DROP CONSTRAINT "DMT_MOCK_TFM_STATUS_CK"';
    exception when others then
      if sqlcode != -2443 then raise; end if;  -- -2443 = constraint does not exist
    end;
    execute immediate 'ALTER TABLE "DMT_MOCK_TFM_TBL" RENAME COLUMN "STATUS" TO "TFM_STATUS"';
    execute immediate 'ALTER TABLE "DMT_MOCK_TFM_TBL" ADD CONSTRAINT "DMT_MOCK_TFM_STATUS_CK" CHECK (
        TFM_STATUS IN (''STAGED'',''GENERATED'',''LOADED'',''FAILED'',''UNACCOUNTED''))';
  end if;
end;
/

-- ---------------------------------------------------------------------------
-- 2026-07-21: add 'UNACCOUNTED' to the TFM_STATUS IN-list. UNACCOUNTED is the
-- real stored terminal status set by the shared unaccounted sweep. Idempotent
-- drop-and-recreate of the named CHECK (keeps the constraint name). Fresh
-- installs already get the final IN-list from the CREATE above; this converges
-- a pre-existing database whose CHECK was created without UNACCOUNTED.
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_constraints
  where  table_name = 'DMT_MOCK_TFM_TBL' and constraint_name = 'DMT_MOCK_TFM_STATUS_CK';
  if l_n = 1 then
    execute immediate 'ALTER TABLE "DMT_MOCK_TFM_TBL" DROP CONSTRAINT "DMT_MOCK_TFM_STATUS_CK"';
  end if;
  execute immediate 'ALTER TABLE "DMT_MOCK_TFM_TBL" ADD CONSTRAINT "DMT_MOCK_TFM_STATUS_CK" CHECK (
        TFM_STATUS IN (''STAGED'',''GENERATED'',''LOADED'',''FAILED'',''UNACCOUNTED''))';
exception when others then
  if sqlcode not in (-2264,-2260) then raise; end if;  -- name already used / already exists
end;
/
