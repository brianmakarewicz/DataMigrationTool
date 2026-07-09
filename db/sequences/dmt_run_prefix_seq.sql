-- DMT_RUN_PREFIX_SEQ — run prefixes are 5-digit (10000-99999), owner decision 2026-07-08
-- (widened from the original 4-digit 1000-9999 spec of 2026-07-06; DMT_DESIGN.html section 6 / Q5).
begin
  execute immediate 'CREATE SEQUENCE  "DMT_RUN_PREFIX_SEQ"  MINVALUE 10000 MAXVALUE 99999 INCREMENT BY 1 START WITH 10000 NOCACHE  NOORDER  NOCYCLE  NOKEEP  NOSCALE  GLOBAL';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/
-- Converge a database created under the old 4-digit spec: if the live sequence
-- still carries MAXVALUE 9999, recreate it on the 5-digit range. New prefixes
-- (10000+) cannot collide with already-stamped 4-digit ones.
declare
  l_max number;
begin
  select max_value into l_max from user_sequences where sequence_name = 'DMT_RUN_PREFIX_SEQ';
  if l_max = 9999 then
    execute immediate 'DROP SEQUENCE "DMT_RUN_PREFIX_SEQ"';
    execute immediate 'CREATE SEQUENCE  "DMT_RUN_PREFIX_SEQ"  MINVALUE 10000 MAXVALUE 99999 INCREMENT BY 1 START WITH 10000 NOCACHE  NOORDER  NOCYCLE  NOKEEP  NOSCALE  GLOBAL';
  end if;
end;
/
