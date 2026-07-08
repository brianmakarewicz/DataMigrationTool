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
-- STAGED / GENERATED / LOADED / FAILED.

begin
  execute immediate 'CREATE TABLE "DMT_MOCK_TFM_TBL"
   (	"MOCK_ID" NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL ENABLE,
	"RUN_ID" NUMBER NOT NULL ENABLE,
	"CEMLI_CODE" VARCHAR2(60) NOT NULL ENABLE,
	"RECORD_KEY" VARCHAR2(200),
	"STATUS" VARCHAR2(30) DEFAULT ''STAGED'' NOT NULL ENABLE,
	"ERROR_TEXT" CLOB,
	"CREATED_DATE" DATE DEFAULT SYSDATE,
	 CONSTRAINT "DMT_MOCK_TFM_PK" PRIMARY KEY ("MOCK_ID")
  USING INDEX  ENABLE,
	 CONSTRAINT "DMT_MOCK_TFM_STATUS_CK" CHECK (
        STATUS IN (''STAGED'',''GENERATED'',''LOADED'',''FAILED'')) ENABLE
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
