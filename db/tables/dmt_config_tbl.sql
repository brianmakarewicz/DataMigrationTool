-- DMT_CONFIG_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_CONFIG_TBL" 
   (	"CONFIG_KEY" VARCHAR2(100) NOT NULL ENABLE, 
	"CONFIG_VALUE" VARCHAR2(500), 
	"DESCRIPTION" VARCHAR2(500), 
	"LAST_UPDATED_DATE" DATE, 
	"LAST_UPDATED_BY" VARCHAR2(100), 
	 CONSTRAINT "DMT_CONFIG_TBL_PK" PRIMARY KEY ("CONFIG_KEY")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_CONFIG_TBL"."CONFIG_KEY" IS 'Configuration key e.g. FUSION_URL, FUSION_USERNAME';
COMMENT ON COLUMN "DMT_CONFIG_TBL"."CONFIG_VALUE" IS 'Configuration value';
COMMENT ON COLUMN "DMT_CONFIG_TBL"."LAST_UPDATED_BY" IS 'DB session user who last updated this row';
COMMENT ON TABLE "DMT_CONFIG_TBL"  IS 'Tool-level configuration. Use DMT_UTIL_PKG.SET_FUSION_URL and SET_CONFIG to manage â€” do not update directly.';
