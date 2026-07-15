-- ============================================================
-- drop_retired_dead_render_procs.sql
--
-- APEX port cleanup (DMT_DESIGN.html section 12, P3 "eliminate
-- standalone procedures"): two standalone procedures are named as
-- dead code — nothing calls them (no DB dependency, and the archived
-- APEX export apex/DMTApplication.sql references neither):
--   DMT_FBDI_FILE_CHAIN, DMT_PLAN_RUN_GTT
-- (The other three named-dead submit procedures were already retired
-- by drop_retired_submit_procs.sql.) Their object files and install.sql
-- enrollment lines were removed in the same change; this script
-- converges an already-installed database.
--
-- Guarded drop-if-exists: safe to run repeatedly; a fresh
-- `build_local_db.sh --fresh` install also converges because the
-- object files and their install.sql lines were removed.
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @db/tools/drop_retired_dead_render_procs.sql
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
    drop_if_exists('PROCEDURE', 'DMT_FBDI_FILE_CHAIN');
    drop_if_exists('PROCEDURE', 'DMT_PLAN_RUN_GTT');
end;
/

exit success
