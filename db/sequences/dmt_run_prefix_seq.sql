-- DMT_RUN_PREFIX_SEQ — run prefixes are 4-digit (1000-9999) per DMT_DESIGN.html section 6 / Q5
begin
  execute immediate 'CREATE SEQUENCE  "DMT_RUN_PREFIX_SEQ"  MINVALUE 1000 MAXVALUE 9999 INCREMENT BY 1 START WITH 1000 NOCACHE  NOORDER  NOCYCLE  NOKEEP  NOSCALE  GLOBAL';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/
