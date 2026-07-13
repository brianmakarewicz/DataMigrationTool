-- DMT_FBDI_ZIP_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_FBDI_ZIP_TBL" 
   (	"FBDI_ZIP_ID" NUMBER NOT NULL ENABLE, 
	"OBJECT_TYPE" VARCHAR2(100) NOT NULL ENABLE,
	"FILENAME" VARCHAR2(200) NOT NULL ENABLE, 
	"ZIP_SIZE_BYTES" NUMBER NOT NULL ENABLE, 
	"ZIP_CONTENT" BLOB NOT NULL ENABLE, 
	"CREATED_DATE" DATE DEFAULT SYSDATE NOT NULL ENABLE, 
	"PARAMETER_LIST" VARCHAR2(1000), 
	"RUN_ID" NUMBER, 
	"INTEGRATION_ID" NUMBER GENERATED ALWAYS AS ("RUN_ID"+0) VIRTUAL , 
	 CONSTRAINT "DMT_FBDI_ZIP_TBL_PK" PRIMARY KEY ("FBDI_ZIP_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_FBDI_ZIP_TBL"."FBDI_ZIP_ID" IS 'PK - from DMT_FBDI_ZIP_ID_SEQ';
COMMENT ON COLUMN "DMT_FBDI_ZIP_TBL"."OBJECT_TYPE" IS 'Object type label e.g. Suppliers, SupplierAddresses, SupplierSites';
COMMENT ON COLUMN "DMT_FBDI_ZIP_TBL"."FILENAME" IS 'Zip filename submitted to UCM e.g. PozSuppliersInt.zip';
COMMENT ON COLUMN "DMT_FBDI_ZIP_TBL"."ZIP_SIZE_BYTES" IS 'Size of the zip BLOB in bytes';
COMMENT ON COLUMN "DMT_FBDI_ZIP_TBL"."ZIP_CONTENT" IS 'Full zip BLOB as submitted to Fusion UCM';
COMMENT ON COLUMN "DMT_FBDI_ZIP_TBL"."CREATED_DATE" IS 'Timestamp of insert';
COMMENT ON TABLE "DMT_FBDI_ZIP_TBL"  IS 'Persisted FBDI zip content for each object type per run. One row per object type per integration.';

-- FBDI CSV<->ZIP remodel (design section 1): the ZIP no longer points at a single
-- CSV; CSV rows point UP at the zip via DMT_FBDI_CSV_TBL.FBDI_ZIP_ID. The loader
-- stamps PARAMETER_LIST by FBDI_ZIP_ID (looked up from the primary csv id), so the
-- FBDI_CSV_ID column is gone from the final shape above. Guarded DROP converges
-- existing databases; on a fresh install (column never created) it is a no-op.
begin
  execute immediate 'ALTER TABLE "DMT_FBDI_ZIP_TBL" DROP COLUMN "FBDI_CSV_ID"';
exception when others then if sqlcode not in (-904,-957) then raise; end if;
end;
/
