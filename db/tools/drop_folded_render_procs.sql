-- ============================================================
-- drop_folded_render_procs.sql
--
-- APEX port cleanup (backlog #41, "eliminate standalone procedures"):
-- the six live render/APEX-support procedures were FOLDED into
-- DMT_APEX_PAGE_PKG as public methods, preserving their HTML output
-- byte-for-byte, and every APEX region that called them was repointed
-- to the package method:
--   DMT_RUN_DETAIL_TILES        -> DMT_APEX_PAGE_PKG.RENDER_RUN_TILES
--   DMT_RUN_DETAIL_HEADER       -> DMT_APEX_PAGE_PKG.RENDER_RUN_HEADER
--   DMT_OBJECT_DETAIL_BREADCRUMB-> DMT_APEX_PAGE_PKG.RENDER_DETAIL_BREADCRUMB
--   DMT_ESS_JOB_DETAIL          -> DMT_APEX_PAGE_PKG.RENDER_ESS_JOB_DETAIL
--   DMT_RENDER_VIEW             -> DMT_APEX_PAGE_PKG.RENDER_VIEW
--   DMT_PLAN_PREVIEW_HTML       -> DMT_APEX_PAGE_PKG.RENDER_PLAN_PREVIEW
--
-- Their object files and install.sql enrollment lines were removed in
-- the same change; this script converges an ALREADY-installed database
-- (drops the now-orphaned standalone procedures). DMT_SUBMIT_RUN_V2 is
-- intentionally NOT dropped -- it stays standalone as the pipeline
-- submission entry point (a guard-enforcing wrapper), not a renderer.
--
-- Guarded drop-if-exists: safe to run repeatedly; a fresh
-- `build_local_db.sh --fresh` install also converges because the
-- object files and their install.sql lines were removed.
--
-- Run as DMT_OWNER:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @db/tools/drop_folded_render_procs.sql
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
    drop_if_exists('PROCEDURE', 'DMT_RUN_DETAIL_TILES');
    drop_if_exists('PROCEDURE', 'DMT_RUN_DETAIL_HEADER');
    drop_if_exists('PROCEDURE', 'DMT_OBJECT_DETAIL_BREADCRUMB');
    drop_if_exists('PROCEDURE', 'DMT_ESS_JOB_DETAIL');
    drop_if_exists('PROCEDURE', 'DMT_RENDER_VIEW');
    drop_if_exists('PROCEDURE', 'DMT_PLAN_PREVIEW_HTML');
end;
/

exit success
