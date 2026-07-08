-- DMT_BU_LOOKUP_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_BU_LOOKUP_TBL" 
   (	"BU_NAME" VARCHAR2(240) NOT NULL ENABLE, 
	"FUSION_BU_ID" VARCHAR2(30) NOT NULL ENABLE, 
	"DEFAULT_BUYER_ID" VARCHAR2(30), 
	"DEFAULT_REQ_BU_ID" VARCHAR2(30), 
	"CREATED_DATE" DATE DEFAULT SYSDATE NOT NULL ENABLE, 
	"LAST_UPDATED_DATE" DATE, 
	"PRIMARY_LEDGER_ID" VARCHAR2(30), 
	 CONSTRAINT "DMT_BU_LOOKUP_TBL_PK" PRIMARY KEY ("BU_NAME")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_BU_LOOKUP_TBL"."BU_NAME" IS 'Procurement BU name as it appears in source data (PRC_BU_NAME on PO headers)';
COMMENT ON COLUMN "DMT_BU_LOOKUP_TBL"."FUSION_BU_ID" IS 'Fusion internal BU ID â€” used in ImportSPOJob ParameterList args 1 and 9';
COMMENT ON COLUMN "DMT_BU_LOOKUP_TBL"."DEFAULT_BUYER_ID" IS 'Default buyer person ID for this BU â€” ParameterList arg 2';
COMMENT ON COLUMN "DMT_BU_LOOKUP_TBL"."DEFAULT_REQ_BU_ID" IS 'Default requisition BU ID for this BU â€” ParameterList arg 4';
COMMENT ON TABLE "DMT_BU_LOOKUP_TBL"  IS 'BU name to Fusion BU ID lookup â€” seeded at deploy time for PO multi-BU support';
