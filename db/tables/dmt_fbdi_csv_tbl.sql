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
