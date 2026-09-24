-- =========================================================================
-- Migration: DMT_GL_INTERFACE_TFM_TBL.FUSION_JE_HEADER_ID NUMBER -> VARCHAR2(100)
-- (2026-09-24)
-- docs/DMT_DESIGN.html section 5 ("BIP reconciliation report contract - v1")
-- and section 7 ("Reconciliation captures the Fusion base-table id").
--
-- WHY: GLBalances' TFM table is journal-LINE grained, but the reconciler used
-- to stamp the journal-HEADER id (JE_HEADER_ID) into FUSION_JE_HEADER_ID -- so
-- every line of one journal carried the SAME id and the lines collided in the
-- Fusion-id uniqueness audit. The reconciler now stamps the per-LINE composite
-- 'JE_HEADER_ID~JE_LINE_NUM' (from GL_JE_LINES, the base table), which is a
-- string. The column must therefore become VARCHAR2 to hold that composite,
-- following the contract's '~'-joined composite-key convention.
--
-- SAFE TO NULL FIRST: FUSION_JE_HEADER_ID is recon-derived positive proof of
-- load. It is written ONLY by BIP reconciliation and is re-stamped from scratch
-- on every reconcile. Clearing it is NOT a TFM_STATUS reset (TFM_STATUS is
-- untouched) -- the next reconcile re-derives it. A NUMBER -> VARCHAR2 MODIFY
-- fails with ORA-01439 if the column holds any data, so the column is NULLed
-- before the type change.
--
-- IDEMPOTENT: the whole block is guarded on the column's CURRENT data type.
-- Once the column is VARCHAR2 the guard is false and a re-run is a clean no-op
-- (the NULL and MODIFY do not fire again). Re-running this file any number of
-- times leaves a VARCHAR2(100) column and changes nothing else.
--
-- The create-table script db/tables/dmt_gl_interface_tfm_tbl.sql now creates
-- FUSION_JE_HEADER_ID at VARCHAR2(100) for fresh installs. This migration
-- converges an EXISTING database whose column is still NUMBER. Deploy as
-- DMT2_OWNER (never ADMIN). ci_promote runs every db/migrations file in
-- chronological filename order, so this deploys to GOLD.
-- =========================================================================
set define off
set serveroutput on

prompt == Convert DMT_GL_INTERFACE_TFM_TBL.FUSION_JE_HEADER_ID to VARCHAR2(100) ==
declare
  l_type user_tab_columns.data_type%type;
begin
  select data_type
    into l_type
    from user_tab_columns
   where table_name  = 'DMT_GL_INTERFACE_TFM_TBL'
     and column_name = 'FUSION_JE_HEADER_ID';

  if l_type = 'NUMBER' then
    -- Clear recon-derived proof so the NUMBER -> VARCHAR2 MODIFY is legal
    -- (ORA-01439). This is NOT a TFM_STATUS reset; the next reconcile re-stamps
    -- the composite id. TFM_STATUS is not touched.
    execute immediate
      'UPDATE "DMT_GL_INTERFACE_TFM_TBL" SET "FUSION_JE_HEADER_ID" = NULL '
      || 'WHERE "FUSION_JE_HEADER_ID" IS NOT NULL';
    execute immediate
      'ALTER TABLE "DMT_GL_INTERFACE_TFM_TBL" '
      || 'MODIFY ("FUSION_JE_HEADER_ID" VARCHAR2(100))';
    dbms_output.put_line('FUSION_JE_HEADER_ID converted NUMBER -> VARCHAR2(100).');
  else
    dbms_output.put_line(
      'FUSION_JE_HEADER_ID already ' || l_type || ' -- no change (idempotent).');
  end if;
exception
  when no_data_found then
    -- Column not present (pre-recon database); the create-table script adds it
    -- at VARCHAR2(100). Nothing to convert here.
    null;
end;
/

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-09-24_gl_fusion_line_key.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'glfusionlinekey', USER);

commit;
