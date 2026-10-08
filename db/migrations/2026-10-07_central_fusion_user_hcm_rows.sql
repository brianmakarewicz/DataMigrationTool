-- Central Fusion user (backlog #309): converges an EXISTING database with the
-- committed seed change in db/seed/dmt_erp_interface_options_tbl.sql (the
-- seed's other rows are insert-and-skip, so this block is repeated here for
-- databases that already ran the seed). Adds one DMT_ERP_INTERFACE_OPTIONS_TBL
-- row per HCM CEMLI naming hcm_impl, so HDL and its preflight resolve the same
-- user through DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS. Run
-- db/tools/setup_runtime_config.py afterwards to fill the masked passwords.
-- Idempotent: MERGE on CEMLI_CODE, never clobbers an existing user/password;
-- migration-log MERGE. No DDL.

prompt == HCM objects: per-object Fusion user hcm_impl ==
-- ---------------------------------------------------------------------------
-- HCM objects: per-object Fusion user hcm_impl (backlog #309, owner decision
-- 2026-10-07: one central utility, DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS, decides
-- the Fusion user for every call). HDL upload / submit / poll / error fetch /
-- id lookups, the BIP reconcile and the run preflight all resolve the user
-- from these rows. hcm_impl holds the HCM Data Loader role (fin_impl gets
-- HTTP 403 on uploadFile). These rows are DMT-only (no Fusion
-- FUN_ERP_INTERFACE_OPTIONS counterpart, hence the DMT-HCM-nn ids). The codes
-- are the twelve HCM pipeline CEMLIs plus the three codes the HCM results
-- packages pass to DMT_HDL_UTIL_PKG (AbsenceEntries, WorkerAssignments,
-- PayrollRelationships). The password goes in masked;
-- db/tools/setup_runtime_config.py fills it from connections.json by username.
-- MERGE on CEMLI_CODE: re-runnable; an existing user/password is never clobbered.
-- ---------------------------------------------------------------------------
merge into "DMT_ERP_INTERFACE_OPTIONS_TBL" t
using (select 'DMT-HCM-01' id, 'Workers'              cemli from dual union all
       select 'DMT-HCM-02',    'Salaries'                   from dual union all
       select 'DMT-HCM-03',    'SalaryBases'                from dual union all
       select 'DMT-HCM-04',    'Absences'                   from dual union all
       select 'DMT-HCM-05',    'W2Balances'                 from dual union all
       select 'DMT-HCM-06',    'BenParticipant'             from dual union all
       select 'DMT-HCM-07',    'BenDependent'               from dual union all
       select 'DMT-HCM-08',    'BenBeneficiary'             from dual union all
       select 'DMT-HCM-09',    'TaxCards'                   from dual union all
       select 'DMT-HCM-10',    'TalentProfiles'             from dual union all
       select 'DMT-HCM-11',    'PerfEvaluations'            from dual union all
       select 'DMT-HCM-12',    'WorkSchedules'              from dual union all
       select 'DMT-HCM-13',    'AbsenceEntries'             from dual union all
       select 'DMT-HCM-14',    'WorkerAssignments'          from dual union all
       select 'DMT-HCM-15',    'PayrollRelationships'       from dual) s
on (t."CEMLI_CODE" = s.cemli)
when matched then
  update set t."FUSION_USERNAME" = 'hcm_impl',
             t."FUSION_PASSWORD" = '***MASKED-SET-ME***'
  where t."FUSION_USERNAME" is null
when not matched then
  insert ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","LOAD_INTERFACE_FLAG","LOADER_TYPE",
          "CEMLI_CODE","FUSION_USERNAME","FUSION_PASSWORD")
  values (s.id, 'HCM', 'N', 'HDL', s.cemli, 'hcm_impl', '***MASKED-SET-ME***');
commit;

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_central_fusion_user_hcm_rows.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'centralfusionuser', USER);

commit;
