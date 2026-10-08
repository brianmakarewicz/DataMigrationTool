-- Absences reconciliation report V2 and "Verify in Fusion" lookup (backlog #293).
--
-- 1. Points the Absences Contract v1 registry row (BIP_REPORT_ID 100000030) at
--    /Custom/DMT2/Absences/DMT_ABSENCES_RECON_V2_DM.xdm and its report
--    DMT_ABSENCES_RECON_V2_RPT.xdo. V2 selects rows by the HDL request id (never
--    the run prefix), joins the key map on each row's own SourceSystemOwner and
--    confirms the absence in ANC_PER_ABS_ENTRIES. V2 is deployed ALONGSIDE V1
--    (BIP objects are never overwritten). The record key is now the absence's
--    own TFM sequence id, which is the SourceSystemId the generator writes.
-- 2. The Absences "Verify in Fusion" REST lookup filtered the absences resource
--    with 'PersonNumber={KEY}' and asked for PascalCase fields. The resource's
--    attributes are camelCase, so Fusion answered HTTP 400 ("URL request
--    parameter q with value PersonNumber=... is not valid") and the button never
--    worked. It now filters on the loaded entry's own id
--    (personAbsenceEntryId={KEY}, key FUSION_ABSENCE_ENTRY_ID), which also picks
--    the right absence when a person has several. Proven read-only 2026-10-08:
--    absences?q=personAbsenceEntryId=300000220392184 returns that one entry.
--
-- Mirrors the committed seed changes in db/seed/dmt_bip_report_tbl.sql and
-- db/seed/dmt_rest_lookup_tbl.sql. Idempotent: plain UPDATEs to fixed values,
-- migration-log MERGE. No DDL.

prompt == Repoint Absences recon registry row to V2 ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Absences/DMT_ABSENCES_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Absences/DMT_ABSENCES_RECON_V2_RPT.xdo',
       NOTES               = 'Absence HDL base-table reconciliation (Contract v1). V2 (2026-10-08, backlog #293): '
                          || 'rows selected by the HDL request id, key map joined on each row''s own owner, '
                          || 'absence confirmed in ANC_PER_ABS_ENTRIES. Deployed alongside V1, never overwriting it.',
       RECON_KEY_SQL       = 'TO_CHAR(TFM_SEQUENCE_ID)  (the HDL SourceSystemId)'
where  BIP_REPORT_ID = 100000030
and    CEMLI_CODE    = 'Absences';

prompt == Absences Verify-in-Fusion lookup keys on the absence entry id ==
update DMT_REST_LOOKUP_TBL
set    QUERY_FILTER   = 'personAbsenceEntryId={KEY}',
       KEY_COLUMN     = 'FUSION_ABSENCE_ENTRY_ID',
       DISPLAY_FIELDS = 'personAbsenceEntryId,personNumber,absenceType,absenceStatusCd,approvalStatusCd,startDate,endDate,duration',
       DISPLAY_LABELS = 'Entry ID,Person,Type,Status,Approval,Start,End,Duration'
where  OBJECT_TYPE = 'Absences';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-08_absences_recon_v2_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'absreconv2', USER);

commit;
