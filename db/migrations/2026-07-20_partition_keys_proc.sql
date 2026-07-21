-- =========================================================================
-- Migration: PARTITION_KEYS_PROC on DMT_PIPELINE_DEF_TBL  (2026-07-20)
-- Work-queue-ID core / spawn-per-partition rework (PR #205).
--
-- Adds one nullable column naming the PKG.FUNCTION the queue worker calls
-- (through DMT_QUEUE_WORKER_PKG.invoke_registered, style KEYS) to get a
-- spawn-per-partition object's distinct partition tokens with STATIC SQL over
-- that object's OWN transform table(s). Set only for Items/Assets/Requisitions;
-- NULL for every object that is not split into per-partition child work items.
-- This replaced the retired dynamic SELECT DISTINCT in EXECUTE_ONE, so there is
-- no fourth EXECUTE IMMEDIATE site (the owner rejected sanctioning one).
--
-- ADDITIVE + NULLABLE. Idempotent. Deploy as DMT_OWNER (never ADMIN).
-- The create-table script db/tables/dmt_pipeline_def_tbl.sql already carries
-- the column (git-first); this migration converges an existing database and
-- re-seeds the three spawn objects' function names.
-- =========================================================================
set define off
set serveroutput on

prompt == PARTITION_KEYS_PROC on DMT_PIPELINE_DEF_TBL ==
begin
  execute immediate 'ALTER TABLE "DMT_PIPELINE_DEF_TBL" ADD ("PARTITION_KEYS_PROC" VARCHAR2(200))';
exception when others then
  if sqlcode not in (-1430) then raise; end if;
end;
/

prompt == Seed the three spawn-per-partition objects' keys functions ==
merge into "DMT_PIPELINE_DEF_TBL" t
using (
    select 'Items'        cemli_code, 'DMT_EGP_ITEM_RESULTS_PKG.GET_PARTITION_KEYS' keys_proc from dual
    union all select 'Assets',        'DMT_FA_ASSET_RESULTS_PKG.GET_PARTITION_KEYS' from dual
    union all select 'Requisitions',  'DMT_REQ_RESULTS_PKG.GET_PARTITION_KEYS'      from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set t."PARTITION_KEYS_PROC" = s.keys_proc;

commit;
