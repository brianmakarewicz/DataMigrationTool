-- DMT_APP_SAVEPOINTS (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_APP_SAVEPOINTS" 
   (	"SAVEPOINT_ID" NUMBER, 
	"APP_ID" NUMBER NOT NULL ENABLE, 
	"DESCRIPTION" VARCHAR2(500), 
	"CREATED_DATE" DATE DEFAULT SYSDATE, 
	"EXPORT_SQL" CLOB, 
	 PRIMARY KEY ("SAVEPOINT_ID")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/
