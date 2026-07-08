-- ============================================================================
-- local_db_setup.sql — run ONCE as SYSTEM (or PDBADMIN) on the LOCAL Docker
-- Oracle Free database (FREEPDB1) to create the DMT_OWNER schema owner.
-- NEVER run this on ATP. DDL after this point runs as DMT_OWNER, never admin.
--
--   sql system/<pwd>@//localhost:1521/FREEPDB1 @db_full/tools/local_db_setup.sql <dmt_owner_password>
-- ============================================================================
set define on
define DMT_PWD = &1

declare
  l_cnt number;
begin
  select count(*) into l_cnt from dba_users where username = 'DMT_OWNER';
  if l_cnt = 0 then
    execute immediate 'create user DMT_OWNER identified by "&DMT_PWD" quota unlimited on users';
  end if;
end;
/

grant create session, create table, create view, create sequence,
      create procedure, create trigger, create type, create synonym,
      create materialized view, create job to DMT_OWNER;
-- packages used by DMT code (same as ATP grants where possible)
grant execute on dbms_crypto to DMT_OWNER;
grant execute on utl_http to DMT_OWNER;
grant execute on dbms_lock to DMT_OWNER;
grant execute on dbms_scheduler to DMT_OWNER;
grant execute on dbms_metadata to DMT_OWNER;
-- NOTE: dbms_network_acl_admin (needed by DMT_UTIL_PKG) is SYS-owned and
-- cannot be granted by SYSTEM; build_local_db.sh grants it via
-- `sqlplus / as sysdba` inside the container.

prompt DMT_OWNER ready on local DB.
exit
