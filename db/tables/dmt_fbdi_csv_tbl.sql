-- DMT_FBDI_CSV_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_FBDI_CSV_TBL" 
   (	"FBDI_CSV_ID" NUMBER NOT NULL ENABLE, 
	"OBJECT_TYPE" VARCHAR2(100) NOT NULL ENABLE, 
	"FILENAME" VARCHAR2(200) NOT NULL ENABLE, 
	"ROW_COUNT" NUMBER NOT NULL ENABLE, 
	"CSV_CONTENT" CLOB NOT NULL ENABLE, 
	"CREATED_DATE" DATE DEFAULT SYSDATE NOT NULL ENABLE, 
	"RUN_ID" NUMBER, 
	"INTEGRATION_ID" NUMBER GENERATED ALWAYS AS ("RUN_ID"+0) VIRTUAL , 
	 CONSTRAINT "DMT_FBDI_CSV_TBL_PK" PRIMARY KEY ("FBDI_CSV_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_FBDI_CSV_TBL"."FBDI_CSV_ID" IS 'PK - from DMT_FBDI_CSV_ID_SEQ';
COMMENT ON COLUMN "DMT_FBDI_CSV_TBL"."OBJECT_TYPE" IS 'Object type label e.g. Suppliers, SupplierAddresses, SupplierSites';
COMMENT ON COLUMN "DMT_FBDI_CSV_TBL"."FILENAME" IS 'CSV filename inside the zip e.g. PoSupplierImport.csv';
COMMENT ON COLUMN "DMT_FBDI_CSV_TBL"."ROW_COUNT" IS 'Number of data rows (excludes header)';
COMMENT ON COLUMN "DMT_FBDI_CSV_TBL"."CSV_CONTENT" IS 'Full CSV content including header row';
COMMENT ON COLUMN "DMT_FBDI_CSV_TBL"."CREATED_DATE" IS 'Timestamp of insert';
COMMENT ON TABLE "DMT_FBDI_CSV_TBL"  IS 'Persisted CSV content for each FBDI object type per run. One row per object type per integration.';

-- FBDI CSV<->ZIP remodel (design section 3): CSV is the CHILD of ZIP -- one zip
-- owns many CSV rows (one per physical file). FBDI_ZIP_ID links up to the zip;
-- FILE_SEQ preserves the exact member order so the built archive is byte-identical.
begin
  execute immediate 'ALTER TABLE "DMT_FBDI_CSV_TBL" ADD ("FBDI_ZIP_ID" NUMBER)';
exception when others then if sqlcode not in (-1430) then raise; end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_FBDI_CSV_TBL" ADD ("FILE_SEQ" NUMBER DEFAULT 1 NOT NULL)';
exception when others then if sqlcode not in (-1430) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_FBDI_CSV_ZIP_IX" ON "DMT_FBDI_CSV_TBL" ("FBDI_ZIP_ID")';
exception when others then if sqlcode not in (-955,-1408) then raise; end if;
end;
/
COMMENT ON COLUMN "DMT_FBDI_CSV_TBL"."FBDI_ZIP_ID" IS 'FK up to DMT_FBDI_ZIP_TBL -- the zip this CSV is a member of';
COMMENT ON COLUMN "DMT_FBDI_CSV_TBL"."FILE_SEQ" IS 'Member order within the zip (1..N); preserves add1file order for byte-identical archives';
