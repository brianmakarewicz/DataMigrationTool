-- ============================================================
-- drop_retired_adaptor_stubs.sql
--
-- Backlog §12 (P3): the two adaptor packages DMT_EBS_ADAPTOR_PKG and
-- DMT_GENERIC_ADAPTOR_PKG are never-built pull-model stubs (TODO bodies,
-- no callers) that contradict the actual push architecture: EBS source
-- data is pushed over the ATP_LINK DB link into DMT_CSV_LANDING_TBL by
-- the separate EBSAdaptors repo, and DMT_CSV_LOADER_PKG parses it into
-- STG; generic sources arrive via the CSV upload path. The stubs are
-- deleted from the repo (package files + install.sql lines removed).
--
-- Guarded drop-if-exists: safe to run repeatedly; a fresh
-- `build_local_db.sh --fresh` install also converges because the object
-- files and their install.sql lines were removed.
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @db/tools/drop_retired_adaptor_stubs.sql
-- ============================================================

whenever sqlerror exit failure
set serveroutput on

declare
    procedure drop_if_exists (p_type in varchar2, p_name in varchar2) is
        l_cnt pls_integer;
    begin
        select count(*) into l_cnt
        from   user_objects
        where  object_name = p_name
        and    object_type = p_type;

        if l_cnt = 0 then
            dbms_output.put_line('SKIP  ' || p_type || ' ' || p_name || ' (does not exist)');
        else
            execute immediate 'drop ' || p_type || ' "' || p_name || '"';
            dbms_output.put_line('DROP  ' || p_type || ' ' || p_name);
        end if;
    end drop_if_exists;
begin
    drop_if_exists('PACKAGE', 'DMT_EBS_ADAPTOR_PKG');
    drop_if_exists('PACKAGE', 'DMT_GENERIC_ADAPTOR_PKG');
end;
/

exit success
