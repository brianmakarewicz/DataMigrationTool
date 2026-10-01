-- =========================================================================
-- Migration: GLBalances recon onto the shared Contract v1 parser (2026-09-30)
-- Backlog #92 — conformance migration. docs/DMT_DESIGN.html section 5.
--
-- GLBalances was the ONLY object reconciling through the generic recon engine
-- (DMT_RECON_ENGINE_PKG, Option 1), which has its OWN report reader and
-- dispatched DMT_GL_RESULTS_PKG.APPLY_GL from DMT_RECON_STAGE_GTT. That was a GL
-- one-off: two parsers in the codebase. This migration converges an EXISTING
-- database onto Option A — GLBalances now reconciles through the ONE shared
-- Contract v1 parser DMT_RECON_CONTRACT_PKG.FETCH_ROWS, called from its own
-- reconciler DMT_GL_RESULTS_PKG.RECONCILE_BATCH (RECON dispatch style), exactly
-- like the other ~29 objects. The package body is redeployed from the committed
-- files (db/packages/dmt_gl_results_pkg.*); this migration only converges the
-- two registry rows.
--
-- Fresh installs are born correct from db/seed/dmt_pipeline_def_tbl.sql +
-- db/seed/dmt_bip_report_tbl.sql. ADDITIVE / registry-only. Idempotent (MERGE +
-- guarded UPDATE). Deploy as DMT2_OWNER (never ADMIN). Logged once in
-- DMT_MIGRATION_LOG.
-- =========================================================================
set define off
set serveroutput on

prompt == Clear GLBalances APPLY_PROC (off the retired generic engine) ==
-- Keep CONTRACT_VERSION = 1 (it gates the shared FETCH_ROWS) + the documentation
-- columns; clear APPLY_PROC so the object is no longer dispatched to
-- DMT_RECON_ENGINE_PKG.
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 'GLBalances'                     cemli_code,
           1                                contract_version,
           'DMT_GL_INTERFACE_TFM_TBL'       tfm_table,
           'FUSION_JE_HEADER_ID'            fusion_id_column
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."CONTRACT_VERSION" = s.contract_version,
    t."TFM_TABLE"        = s.tfm_table,
    t."FUSION_ID_COLUMN" = s.fusion_id_column,
    t."APPLY_PROC"       = NULL;

prompt == Route GLBalances RECON_PROC at its own reconciler (Option A, RECON style) ==
update "DMT_PIPELINE_DEF_TBL"
   set "RECON_PROC"          = 'DMT_GL_RESULTS_PKG.RECONCILE_BATCH',
       "RECON_HAS_CEMLI_ARG" = 'N'
 where "CEMLI_CODE" = 'GLBalances'
   and (  "RECON_PROC" <> 'DMT_GL_RESULTS_PKG.RECONCILE_BATCH'
       or "RECON_HAS_CEMLI_ARG" <> 'N'
       or "RECON_PROC" is null
       or "RECON_HAS_CEMLI_ARG" is null);

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-09-30_glbalances_shared_parser_option_a.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'glsharedparser', USER);

commit;
