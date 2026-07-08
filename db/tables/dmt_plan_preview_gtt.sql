-- DMT_PLAN_PREVIEW_GTT (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE GLOBAL TEMPORARY TABLE "DMT_PLAN_PREVIEW_GTT" 
   (	"SORT_ORDER" NUMBER, 
	"PIPELINE" VARCHAR2(30), 
	"CEMLI_CODE" VARCHAR2(60), 
	"DEPENDS_ON" VARCHAR2(4000), 
	"INITIAL_STATUS" VARCHAR2(30)
   )  ON COMMIT DELETE ROWS';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/
