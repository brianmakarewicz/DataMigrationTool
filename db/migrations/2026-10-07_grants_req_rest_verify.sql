-- "Verify in Fusion" REST lookup fixes (backlog #223,
-- docs/findings/verify_in_fusion_not_found.md).
--
-- 1. Grants / Award Headers: the configured resource gmsGrants does not exist on
--    the pod (HTTP 404 for every user, with or without a filter). The awards
--    resource is `awards`, queried by AwardNumber = the prefixed award number
--    (verified live 2026-10-07 for 93298RTAWD-G1, AwardId 300000334921417). The
--    display fields must be real `awards` fields: GrantId and AwardStatusCode do
--    not exist; the status field is ContractStatus.
--
-- 2. Requisitions / Req Headers NOTES: the verify no longer reads a separate
--    DMT_CONFIG <Object>_USERNAME override; it runs as the object's load user
--    from DMT_ERP_INTERFACE_OPTIONS_TBL via DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS
--    (code change in DMT_REST_LOOKUP_PKG). Only the NOTES text changes.
--
-- Mirrors the committed seed change in db/seed/dmt_rest_lookup_tbl.sql (whose
-- Grants / Award Headers inserts skip existing rows) so an existing database
-- converges. Idempotent: UPDATEs to fixed values, migration-log MERGE. No DDL.

prompt == Grants REST verify: awards resource + real display fields ==
update DMT_REST_LOOKUP_TBL
set    REST_ENDPOINT  = '/fscmRestApi/resources/11.13.18.05/awards',
       QUERY_FILTER   = 'AwardNumber={KEY}',
       KEY_COLUMN     = 'AWARD_NUMBER',
       DISPLAY_FIELDS = 'AwardId,AwardNumber,AwardName,SponsorName,StartDate,ContractStatus',
       DISPLAY_LABELS = 'Award ID,Award #,Name,Sponsor,Start,Status',
       NOTES          = 'awards resource (gmsGrants does not exist: HTTP 404); query by AwardNumber = the prefixed award number. Verified live 2026-10-07.'
where  OBJECT_TYPE IN ('Grants', 'Award Headers');

prompt == Requisitions REST verify: notes name the load-user credential source ==
update DMT_REST_LOOKUP_TBL
set    NOTES = CASE OBJECT_TYPE
                 WHEN 'Requisitions'
                 THEN 'Verify queries RequisitionHeaderId = the Fusion header id captured by reconciliation onto the TFM (FUSION_REQUISITION_HEADER_ID); exact and user-independent, so it sidesteps the data-security scoping and the system-generated-number problem. Runs as the Requisitions load user (DMT_ERP_INTERFACE_OPTIONS_TBL via DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS = calvin.roth).'
                 ELSE 'Verify queries RequisitionHeaderId = the Fusion header id captured by reconciliation onto the TFM (FUSION_REQUISITION_HEADER_ID); exact and user-independent. Runs as the Requisitions load user (DMT_ERP_INTERFACE_OPTIONS_TBL via DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS = calvin.roth).'
               END
where  OBJECT_TYPE IN ('Requisitions', 'Req Headers');

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_grants_req_rest_verify.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'grantsreqrestverify', USER);

commit;
