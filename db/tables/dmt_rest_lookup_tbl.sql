-- DMT_REST_LOOKUP_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_REST_LOOKUP_TBL" 
   (	"REST_LOOKUP_ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"OBJECT_TYPE" VARCHAR2(100) NOT NULL ENABLE, 
	"REST_ENDPOINT" VARCHAR2(500) NOT NULL ENABLE, 
	"QUERY_FILTER" VARCHAR2(500) NOT NULL ENABLE, 
	"KEY_COLUMN" VARCHAR2(100) NOT NULL ENABLE, 
	"DISPLAY_FIELDS" VARCHAR2(1000) NOT NULL ENABLE, 
	"DISPLAY_LABELS" VARCHAR2(1000) NOT NULL ENABLE, 
	"AUTH_TYPE" VARCHAR2(30) DEFAULT ''ERP'', 
	"ENABLED" VARCHAR2(1) DEFAULT ''Y'' NOT NULL ENABLE, 
	"NOTES" VARCHAR2(500), 
	"REST_FRAMEWORK_VERSION" VARCHAR2(10), 
	"ABSENT_FIELD" VARCHAR2(100), 
	"ABSENT_VALUE" VARCHAR2(100), 
	"NOT_APPLICABLE_REASON" VARCHAR2(500), 
	"CEMLI_CODE" VARCHAR2(100), 
	 PRIMARY KEY ("REST_LOOKUP_ID")
  USING INDEX  ENABLE, 
	 CONSTRAINT "DMT_REST_LOOKUP_OBJ_UK" UNIQUE ("OBJECT_TYPE")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

-- 2026-10-08 (backlog #460): Verify-in-Fusion lookup options.
--   REST_FRAMEWORK_VERSION  sent as the REST-Framework-Version header; '4' enables
--                           child-attribute filters (q=Address.AddressId=...) so a
--                           child record is found by its own Fusion id.
--   ABSENT_FIELD/ABSENT_VALUE  a resource that always answers one row (ledgerBalances
--                           returns '#Missing' amounts) is "not found" when items[0].
--                           ABSENT_FIELD equals ABSENT_VALUE.
--   NOT_APPLICABLE_REASON   set when Fusion exposes no REST read resource for the
--                           object (proven on the pod); the verify reports
--                           NOT_APPLICABLE with this reason instead of calling Fusion.
begin
  execute immediate 'ALTER TABLE "DMT_REST_LOOKUP_TBL" ADD ("REST_FRAMEWORK_VERSION" VARCHAR2(10))';
exception when others then if sqlcode not in (-1430) then raise; end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_REST_LOOKUP_TBL" ADD ("ABSENT_FIELD" VARCHAR2(100))';
exception when others then if sqlcode not in (-1430) then raise; end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_REST_LOOKUP_TBL" ADD ("ABSENT_VALUE" VARCHAR2(100))';
exception when others then if sqlcode not in (-1430) then raise; end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_REST_LOOKUP_TBL" ADD ("NOT_APPLICABLE_REASON" VARCHAR2(500))';
exception when others then if sqlcode not in (-1430) then raise; end if;
end;
/

-- 2026-10-08 (backlog #430): CEMLI_CODE names the object whose Fusion user the
-- verify reads as (DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS). Set only on rows whose
-- OBJECT_TYPE is neither an object code nor a display label in the object display
-- catalog (DMT_V_CEMLI_TFM_TABLES); NULL means the catalog / the key resolves it.
begin
  execute immediate 'ALTER TABLE "DMT_REST_LOOKUP_TBL" ADD ("CEMLI_CODE" VARCHAR2(100))';
exception when others then if sqlcode not in (-1430) then raise; end if;
end;
/
