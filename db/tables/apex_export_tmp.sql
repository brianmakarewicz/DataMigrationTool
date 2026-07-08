-- APEX_EXPORT_TMP (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE GLOBAL TEMPORARY TABLE "APEX_EXPORT_TMP" 
   (	"FILE_NAME" VARCHAR2(500), 
	"CONTENTS" CLOB
   )  ON COMMIT PRESERVE ROWS';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/
