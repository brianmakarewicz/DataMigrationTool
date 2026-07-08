-- DMT_PREFIX_MASTER_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_PREFIX_MASTER_TBL" 
   (	"PREFIX_ID" NUMBER NOT NULL ENABLE, 
	"CEMLI" VARCHAR2(100) NOT NULL ENABLE, 
	"PREFIX" VARCHAR2(10) NOT NULL ENABLE, 
	"UPDATED_BY" VARCHAR2(200), 
	"EMAIL_NOTIFICATION" VARCHAR2(500), 
	"LAST_UPDATED_DATE" DATE, 
	 CONSTRAINT "DMT_PREFIX_MASTER_TBL_PK" PRIMARY KEY ("PREFIX_ID")
  USING INDEX  ENABLE, 
	 CONSTRAINT "DMT_PREFIX_MASTER_TBL_U1" UNIQUE ("CEMLI")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_PREFIX_MASTER_TBL"."PREFIX_ID" IS 'PK - from DMT_PREFIX_MASTER_ID_SEQ';
COMMENT ON COLUMN "DMT_PREFIX_MASTER_TBL"."CEMLI" IS 'Unique CEMLI code e.g. C001-Suppliers, C004-PurchaseOrders';
COMMENT ON COLUMN "DMT_PREFIX_MASTER_TBL"."PREFIX" IS 'Current prefix value. Incremented by 1 each time this CEMLI runs. Seeded at install (e.g. 1001).';
COMMENT ON COLUMN "DMT_PREFIX_MASTER_TBL"."UPDATED_BY" IS 'OIC instance ID of the integration that last updated this prefix';
COMMENT ON COLUMN "DMT_PREFIX_MASTER_TBL"."EMAIL_NOTIFICATION" IS 'Email address(es) for run completion notifications - seeded or updated manually';
COMMENT ON TABLE "DMT_PREFIX_MASTER_TBL"  IS 'One row per CEMLI. PREFIX auto-increments on each run to allow repeated test conversions without collision.';
