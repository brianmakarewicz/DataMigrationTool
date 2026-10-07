-- ARInvoices "Verify in Fusion" REST lookup: key on the Fusion
-- CustomerTransactionId instead of TRX_NUMBER (objects/ARInvoices/README.md
-- Known Issues 5).
--
-- An auto-numbering transaction source (External Source) gets no TRX_NUMBER from
-- DMT, so the old filter TransactionNumber={KEY} had no key and returned
-- NOT_FOUND even for a LOADED invoice. The reconciler stamps the Fusion
-- CUSTOMER_TRX_ID into DMT_RA_LINES_TFM_TBL.FUSION_CUSTOMER_TRX_ID, and
-- DMT_RECORD_DETAIL_V now returns it as the AR Lines LOOKUP_KEY; the REST
-- resource receivablesInvoices accepts q=CustomerTransactionId=<id> (verified
-- live 2026-10-07 for customer_trx_id 1586956).
--
-- Mirrors the committed seed change in db/seed/dmt_rest_lookup_tbl.sql (whose
-- inserts skip existing rows) so an existing database converges. Idempotent:
-- UPDATE to fixed values, migration-log MERGE. No DDL.

prompt == AR REST verify: query by CustomerTransactionId ==
update DMT_REST_LOOKUP_TBL
set    QUERY_FILTER = 'CustomerTransactionId={KEY}',
       KEY_COLUMN   = 'FUSION_CUSTOMER_TRX_ID',
       NOTES        = CASE OBJECT_TYPE
                        WHEN 'AR Lines'
                        THEN 'AR invoice lines - queries the parent transaction by the Fusion CustomerTransactionId the reconciler stamped (auto-numbered sources send no TRX_NUMBER)'
                        ELSE 'AR invoice - queried by the Fusion CustomerTransactionId the reconciler stamped (auto-numbered sources send no TRX_NUMBER)'
                      END
where  OBJECT_TYPE IN ('ARInvoices', 'AR Lines');

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-07_ar_rest_verify_by_trx_id.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'arrestverifytrxid', USER);

commit;
