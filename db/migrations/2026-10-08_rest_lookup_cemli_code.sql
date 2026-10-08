-- Verify in Fusion: every object's Fusion user from the central utility (backlog #430).
--
-- DMT_REST_LOOKUP_PKG.LOOKUP_RECORD no longer reads the HCM_USERNAME /
-- HCM_PASSWORD config keys for AUTH_TYPE = 'HCM' rows; every verify resolves its
-- user and password together through DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS
-- (DMT_ERP_INTERFACE_OPTIONS_TBL), like the loads. Five HCM registry rows are keyed
-- by a label that is neither an object code nor a display-catalog label, so they
-- name their object code in the new CEMLI_CODE column (without it they would fall
-- back to the global fin_impl user).
-- The create-table script and the seed already carry the column and the mapping for
-- fresh installs; this converges an existing database. Guarded and idempotent: the
-- column is added only when missing and the MERGE only writes rows that differ.
-- Run as the schema owner, BEFORE recompiling DMT_REST_LOOKUP_PKG (the body
-- references the column).

set serveroutput on
declare
  l_n number;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_REST_LOOKUP_TBL' and column_name = 'CEMLI_CODE';
  if l_n = 0 then
    execute immediate 'alter table DMT_REST_LOOKUP_TBL add (CEMLI_CODE varchar2(100))';
    dbms_output.put_line('added CEMLI_CODE to DMT_REST_LOOKUP_TBL');
  end if;
end;
/

merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Participant Enrollments'  as "OBJECT_TYPE", 'BenParticipant'       as "CEMLI_CODE" from dual union all
       select 'Dependent Enrollments',                     'BenDependent'                         from dual union all
       select 'Beneficiary Designations',                  'BenBeneficiary'                       from dual union all
       select 'Performance Evaluations',                   'PerfEvaluations'                      from dual union all
       select 'Payroll Relationships',                     'PayrollRelationships'                 from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set t."CEMLI_CODE" = s."CEMLI_CODE"
  where t."CEMLI_CODE" is null or t."CEMLI_CODE" <> s."CEMLI_CODE";
commit;

merge into DMT_MIGRATION_LOG t
using (select '2026-10-08_rest_lookup_cemli_code.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'restlkpcemli', USER);

commit;
