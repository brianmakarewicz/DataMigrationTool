-- =========================================================================
-- Migration: Expenditures import job -> ImportProcessParallelEssJob (2026-07-22)
--
-- The onestop ImportAndProcessTxnsJob fails on this pod with ORA-01008
-- ("not all variables bound") inside its own update_xface_id, regardless of
-- ParameterList content -- it is the wrong job. The proven costing job is
-- ImportProcessParallelEssJob (validated live, UI request 9777408), submitted
-- as a SEPARATE ESS request with the 13-arg ParameterList (arg4 PREV_NOT_IMPORTED,
-- arg8 the run's work-queue-id Expenditure Batch, arg13 ORA_PJC_DETAIL) whose
-- values are now emitted one-<paramList>-element-each by SUBMIT_IMPORT_JOB.
--
-- Config-value change to an insert-only seed table; applied once via
-- DMT_MIGRATION_LOG. Deploy as DMT_OWNER (never ADMIN). Idempotent.
-- Fresh installs get the new value from db/seed/dmt_erp_interface_options_tbl.sql.
-- =========================================================================
set define off

update DMT_OWNER.DMT_ERP_INTERFACE_OPTIONS_TBL
set    IMPORT_JOB_NAME = '/oracle/apps/ess/projects/costing/transactions/onestop;ImportProcessParallelEssJob'
where  CEMLI_CODE = 'Expenditures'
and    IMPORT_JOB_NAME <> '/oracle/apps/ess/projects/costing/transactions/onestop;ImportProcessParallelEssJob';

commit;
