-- ============================================================================
-- local_lookup_setup.sql — run ONCE as SYSTEM on the LOCAL Docker Oracle Free
-- database (FREEPDB1) to create the DMT_LOOKUP schema owner (COA mapping /
-- lookup schema — 17 DMT_OWNER synonyms point at it).
-- NEVER run this on ATP (there DMT_LOOKUP already exists; see
-- schema/lookup/01_create_dmt_lookup.sql for the ATP original).
--
--   sql system/<pwd>@//localhost:1522/FREEPDB1 @db_full/tools/local_lookup_setup.sql <dmt_lookup_password>
--
-- SYS-owned package grants (UTL_HTTP, UTL_RAW, DBMS_LOB) are made by
-- build_local_db.sh via `sqlplus / as sysdba` — SYSTEM cannot grant them.
-- ============================================================================
set define on
define LKP_PWD = &1

declare
  l_cnt number;
begin
  select count(*) into l_cnt from dba_users where username = 'DMT_LOOKUP';
  if l_cnt = 0 then
    execute immediate 'create user DMT_LOOKUP identified by "&LKP_PWD" quota unlimited on users';
  end if;
end;
/

grant create session, create table, create sequence, create procedure,
      create view, create synonym, create trigger to DMT_LOOKUP;

prompt DMT_LOOKUP ready on local DB.
exit
