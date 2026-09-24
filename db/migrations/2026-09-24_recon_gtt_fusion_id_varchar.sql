-- =========================================================================
-- Migration: DMT_RECON_STAGE_GTT.FUSION_ID NUMBER -> VARCHAR2(200) (2026-09-24)
-- docs/DMT_DESIGN.html section 5 ("BIP reconciliation report contract - v1").
--
-- WHY: the shared reconciliation report contract's FUSION_ID field is widened
-- from NUMBER to VARCHAR2 so an object whose proof-of-load is at a finer grain
-- than the header can carry a '~'-joined composite (GLBalances now stages the
-- per-line composite JE_HEADER_ID~JE_LINE_NUM). The generic reconcile engine
-- INSERTs the parsed FUSION_ID into this session global temporary table, so its
-- FUSION_ID column must be VARCHAR2 too or the composite raises ORA-01722.
--
-- The carrier object type DMT_RECON_ROW_OBJ.FUSION_ID is likewise VARCHAR2(200)
-- and is redeployed with CREATE OR REPLACE from db/types/dmt_recon_row_tbl.sql
-- (its own drop-and-recreate preamble), so it is NOT handled here.
--
-- DMT_RECON_STAGE_GTT is a SESSION global temporary table: it holds no
-- persistent data (rows live only inside a reconcile call), so it is safe to
-- drop and recreate. The create-table script db/tables/dmt_recon_stage_gtt.sql
-- now creates FUSION_ID at VARCHAR2(200) for fresh installs; this migration
-- converges an EXISTING database whose column is still NUMBER.
--
-- IDEMPOTENT: guarded on the column's current data type. Once VARCHAR2 the
-- guard is false and a re-run is a clean no-op. Deploy as DMT2_OWNER.
-- =========================================================================
set define off
set serveroutput on

prompt == Recreate DMT_RECON_STAGE_GTT with FUSION_ID VARCHAR2(200) ==
declare
  l_type user_tab_columns.data_type%type;
begin
  select data_type
    into l_type
    from user_tab_columns
   where table_name  = 'DMT_RECON_STAGE_GTT'
     and column_name = 'FUSION_ID';

  if l_type = 'NUMBER' then
    -- Session GTT: no persistent data. Drop and recreate at the new shape.
    begin
      execute immediate 'TRUNCATE TABLE "DMT_RECON_STAGE_GTT"';
    exception when others then null;
    end;
    execute immediate 'DROP TABLE "DMT_RECON_STAGE_GTT"';
    execute immediate q'[CREATE GLOBAL TEMPORARY TABLE "DMT_RECON_STAGE_GTT"
   (	"RUN_ID"          NUMBER NOT NULL,
	"OBJECT_TYPE"     VARCHAR2(60),
	"RECORD_KEY"      VARCHAR2(1000),
	"SOURCE_TYPE"     VARCHAR2(20),
	"FUSION_STATUS"   VARCHAR2(20),
	"FUSION_ID"       VARCHAR2(200),
	"ERROR_MESSAGE"   VARCHAR2(4000),
	"LOAD_REQUEST_ID" NUMBER,
	"SOURCE_REF"      VARCHAR2(240),
	"DMT_REFERENCE"   VARCHAR2(240)
   )  ON COMMIT PRESERVE ROWS]';
    dbms_output.put_line('DMT_RECON_STAGE_GTT.FUSION_ID recreated as VARCHAR2(200).');
  else
    dbms_output.put_line(
      'DMT_RECON_STAGE_GTT.FUSION_ID already ' || l_type || ' -- no change (idempotent).');
  end if;
exception
  when no_data_found then
    null;  -- GTT not present yet; the create-table script builds it at VARCHAR2(200).
end;
/

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-09-24_recon_gtt_fusion_id_varchar.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'recongttfusion', USER);

commit;
