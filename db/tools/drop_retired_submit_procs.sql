-- ============================================================
-- drop_retired_submit_procs.sql
--
-- Engine re-review residue (2026-07-08, docs/tranche-reviews/
-- 2026-07-08-engine-review.md ITEM 1): the design document names
-- three standalone submit procedures as dead code — nothing calls
-- them (the archived APEX export apex/DMTApplication.sql calls only
-- DMT_SUBMIT_RUN_V2, which is now a thin wrapper over
-- DMT_SCHEDULER_PKG.SUBMIT_PIPELINE). Their files and install.sql
-- enrollment lines were removed in the same change; this script
-- converges an already-installed database.
--
-- Guarded drop-if-exists: safe to run repeatedly; a fresh
-- `build_local_db.sh --fresh` install also converges because the
-- object files and their install.sql lines were removed.
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @db/tools/drop_retired_submit_procs.sql
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
    drop_if_exists('PROCEDURE', 'DMT_SUBMIT_RUN');
    drop_if_exists('PROCEDURE', 'DMT_SUBMIT_SIMPLE');
    drop_if_exists('PROCEDURE', 'DMT_SUBMIT_TEST');
end;
/

exit success
