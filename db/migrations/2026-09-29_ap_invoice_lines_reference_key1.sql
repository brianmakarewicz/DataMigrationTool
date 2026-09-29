-- =========================================================================
-- Migration: DMT_AP_INVOICE_LINES_INT_TFM_TBL.REFERENCE_KEY1  (2026-09-29)
-- Reference carrier Slot A for AP invoice LINES (backlog #12).
-- docs/DMT_DESIGN.html: "Reference carriers stamped on load, config-driven per
-- object, each slot verified to round-trip to a base-table column" (LOCKED
-- 2026-09-24). For AP, Slot A = REFERENCE_KEY1.
--
-- WHY: every AP invoice LINE we send to Fusion should carry a permanent DMT
-- lineage id (DMT:<run_id>:<work_queue_id>:<tfm_seq_id>) in a field that
-- round-trips to the Fusion base table. AP_INVOICE_LINES_INTERFACE has
-- REFERENCE_KEY1..5 (Oracle FBDI: validation none, destination
-- AP_INVOICE_LINES_ALL.REFERENCE_KEY1..5); the slot was previously unused and
-- comes back NULL on loaded lines. The generator now stamps REFERENCE_KEY1 with
-- BUILD_REF and emits it as the trailing (position 165) column of
-- ApInvoiceLinesInterface.csv. This is a LINEAGE stamp only -- the reconciler is
-- unchanged and still matches each line on the exact line (RECON_KEY = report
-- RECORD_KEY, i.e. INVOICE_ID~LINE_NUMBER). REFERENCE_KEY1 is not read by
-- matching.
--
-- NON-DESTRUCTIVE and IDEMPOTENT: adds the column only when absent; re-running
-- is a no-op. TFM_STATUS / any existing data is never touched. The create-table
-- script db/tables/dmt_ap_invoice_lines_int_tfm_tbl.sql now creates
-- REFERENCE_KEY1 for fresh installs; this migration converges an EXISTING
-- database. Deploy as DMT2_OWNER (never ADMIN). ci_promote runs every
-- db/migrations file in chronological filename order, so this deploys to GOLD.
-- =========================================================================
set define off
set serveroutput on

prompt == Add DMT_AP_INVOICE_LINES_INT_TFM_TBL.REFERENCE_KEY1 (reference carrier Slot A, idempotent) ==
declare
  l_n pls_integer;
begin
  select count(*) into l_n
    from user_tab_columns
   where table_name = 'DMT_AP_INVOICE_LINES_INT_TFM_TBL'
     and column_name = 'REFERENCE_KEY1';
  if l_n = 0 then
    execute immediate
      'ALTER TABLE "DMT_AP_INVOICE_LINES_INT_TFM_TBL" ADD ("REFERENCE_KEY1" VARCHAR2(150))';
    dbms_output.put_line('Added REFERENCE_KEY1.');
  else
    dbms_output.put_line('REFERENCE_KEY1 already present; no-op.');
  end if;
end;
/

comment on column "DMT_AP_INVOICE_LINES_INT_TFM_TBL"."REFERENCE_KEY1" is
  'Reference carrier Slot A (backlog #12): DMT lineage id DMT:<run>:<wq>:<tfm> stamped at generation, emitted as trailing REFERENCE_KEY1 in ApInvoiceLinesInterface.csv, round-trips to AP_INVOICE_LINES_ALL.REFERENCE_KEY1. Lineage only; not read by reconcile matching.';
