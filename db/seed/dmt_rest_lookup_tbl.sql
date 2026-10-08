-- Seed data for DMT_REST_LOOKUP_TBL (68 rows, snapshot 2026-07-03, plus later corrections)
-- Idempotent: duplicate-key inserts are skipped; corrected rows are MERGEd so they converge.
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Items','/fscmRestApi/resources/11.13.18.05/itemsV2','ItemNumber={KEY}','SEGMENT1','ItemId,ItemNumber,ItemDescription,ItemStatusValue,ItemClass','Item ID,Number,Description,Status,Class','ERP','Y','itemsV2 resource; query by ItemNumber. Sub-object labels (Item Master, Item Categories) resolve to Items via the catalog. Verified live 2026-07-15.');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Suppliers','/fscmRestApi/resources/11.13.18.05/suppliers','Supplier={KEY}','SEGMENT1','SupplierId,Supplier,SupplierNumber,Status,CreationDate','Supplier ID,Name,Number,Status,Created','ERP','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('PurchaseOrders','/fscmRestApi/resources/11.13.18.05/purchaseOrders','OrderNumber={KEY}','DOCUMENT_NUM','POHeaderId,OrderNumber,ProcurementBUId,Supplier,Status,TotalAmount,CurrencyCode','PO ID,Order #,BU ID,Supplier,Status,Total,Currency','ERP','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('APInvoices','/fscmRestApi/resources/11.13.18.05/invoices','InvoiceNumber={KEY}','INVOICE_NUM','InvoiceId,InvoiceNumber,VendorName,InvoiceAmount,InvoiceCurrencyCode,InvoiceDate,ValidationStatus','Invoice ID,Number,Vendor,Amount,Currency,Date,Status','ERP','Y','Config correct. fin_impl user may lack BU access to see migrated invoices. Verify works for invoices the user can access.');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Customers','/crmRestApi/resources/11.13.18.05/hubOrganizations','OrganizationName={KEY}','PARTY_NAME','PartyId,OrganizationName,PartyNumber,OrigSystemReference,CreationDate','Party ID,Name,Number,Source Ref,Created','ERP','Y','crmRestApi hubOrganizations; query by OrganizationName = the migrated party name (the record-detail display key). The fscmRestApi path 404s on this instance and OrigSystemReference is not a queryable finder; QUERY_FUSION_RECORD falls back from the lookup key to the display key so the name match is found. Verified live 2026-07-15.');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('ARInvoices','/fscmRestApi/resources/11.13.18.05/receivablesInvoices','CustomerTransactionId={KEY}','FUSION_CUSTOMER_TRX_ID','CustomerTransactionId,TransactionNumber,TransactionDate,BillToCustomerName,TransactionAmount,TransactionStatus','Trx ID,Number,Date,Customer,Amount,Status','ERP','Y','AR invoice - queried by the Fusion CustomerTransactionId the reconciler stamped (auto-numbered sources send no TRX_NUMBER)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('GLBalances','/fscmRestApi/resources/11.13.18.05/journalBatches','BatchName LIKE ''{KEY}%''','BATCH_NAME','JournalBatchId,BatchName,BatchStatus,PostingStatus,AccountingPeriodName','Batch ID,Name,Status,Posting,Period','ERP','Y','journalBatches; Fusion appends a suffix to the batch name so query BatchName LIKE key%. Verified live 2026-07-15.');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Projects','/fscmRestApi/resources/11.13.18.05/projects','ProjectNumber={KEY}','PROJECT_NUMBER','ProjectId,ProjectNumber,ProjectName,ProjectStatusCode,OrganizationName,StartDate','Project ID,Number,Name,Status,Org,Start','ERP','Y',NULL);
exception when dup_val_on_index then null;
end;
/
-- Requisitions: MERGE (not insert-and-skip) so the corrected endpoint/filter/notes
-- converge on any already-seeded DB, per the "registry seeds converge on re-run"
-- standard (DMT_DESIGN section 7). This row's config was corrected after the
-- original snapshot, so an insert-only would be silently skipped on dmt2-local.
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Requisitions' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT"  = '/fscmRestApi/resources/11.13.18.05/purchaseRequisitions',
  t."QUERY_FILTER"   = 'RequisitionHeaderId={KEY}',
  t."KEY_COLUMN"     = 'FUSION_REQUISITION_HEADER_ID',
  t."DISPLAY_FIELDS" = 'RequisitionHeaderId,Requisition,Preparer,DocumentStatus,RequisitioningBU',
  t."DISPLAY_LABELS" = 'Req ID,Number,Preparer,Status,BU',
  t."AUTH_TYPE"      = 'ERP',
  t."ENABLED"        = 'Y',
  t."NOTES"          = 'Verify queries RequisitionHeaderId = the Fusion header id captured by reconciliation onto the TFM (FUSION_REQUISITION_HEADER_ID); exact and user-independent, so it sidesteps the data-security scoping and the system-generated-number problem. Runs as the Requisitions load user (DMT_ERP_INTERFACE_OPTIONS_TBL via DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS = calvin.roth).'
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES")
  values ('Requisitions','/fscmRestApi/resources/11.13.18.05/purchaseRequisitions','RequisitionHeaderId={KEY}','FUSION_REQUISITION_HEADER_ID','RequisitionHeaderId,Requisition,Preparer,DocumentStatus,RequisitioningBU','Req ID,Number,Preparer,Status,BU','ERP','Y','Verify queries RequisitionHeaderId = the Fusion header id captured by reconciliation onto the TFM (FUSION_REQUISITION_HEADER_ID); exact and user-independent, so it sidesteps the data-security scoping and the system-generated-number problem. Runs as the Requisitions load user (DMT_ERP_INTERFACE_OPTIONS_TBL via DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS = calvin.roth).');
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Workers','/hcmRestApi/resources/11.13.18.05/workers','PersonNumber={KEY}','PERSON_NUMBER','PersonId,PersonNumber,DisplayName,WorkerType,StartDate,CreationDate','Person ID,Number,Name,Type,Start Date,Created','HCM','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('SalaryBases','/hcmRestApi/resources/11.13.18.05/salaryBases','SalaryBasisName={KEY}','SALARY_BASIS_NAME','SalaryBasisId,SalaryBasisName,SalaryBasisCode,ElementName,InputValueName','Basis ID,Name,Code,Element,Input Value','HCM','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Salaries','/hcmRestApi/resources/11.13.18.05/salaries','AssignmentNumber={KEY}','ASSIGNMENT_NUMBER','SalaryId,AssignmentNumber,SalaryAmount,SalaryBasisName,DateFrom,ActionCode','Salary ID,Assignment,Amount,Basis,From Date,Action','HCM','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('PerfEvaluations','/hcmRestApi/resources/11.13.18.05/performanceEvaluations','PersonNumber={KEY}','PERSON_NUMBER','EvaluationId,PerformanceDocumentName,EvalStatus,PersonNumber,StartDate,EndDate','Evaluation ID,Document,Status,Person,Start,End','HCM','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('WorkSchedules','/hcmRestApi/resources/11.13.18.05/workPatterns','PersonNumber={KEY}','PERSON_NUMBER','WorkPatternAssignmentId,PersonNumber,AssignmentNumber,WorkPatternType,DateFrom,RepeatCycle','Pattern ID,Person,Assignment,Type,From Date,Repeat','HCM','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Absences','/hcmRestApi/resources/11.13.18.05/absences','PersonNumber={KEY}','PERSON_NUMBER','PersonAbsenceEntryId,PersonNumber,AbsenceType,AbsenceStatus,StartDate,EndDate,Duration','Entry ID,Person,Type,Status,Start,End,Duration','HCM','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('SupplierAddresses','/fscmRestApi/resources/11.13.18.05/suppliers','Supplier={KEY}','VENDOR_NAME','SupplierId,Supplier,SupplierNumber,Status,CreationDate','Supplier ID,Name,Number,Status,Created','ERP','Y','Verifies parent supplier exists in Fusion (addresses are child resources)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('SupplierSites','/fscmRestApi/resources/11.13.18.05/suppliers','Supplier={KEY}','VENDOR_NAME','SupplierId,Supplier,SupplierNumber,Status,CreationDate','Supplier ID,Name,Number,Status,Created','ERP','Y','Verifies parent supplier exists in Fusion (sites are child resources)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('SupplierSiteAssignments','/fscmRestApi/resources/11.13.18.05/suppliers','Supplier={KEY}','VENDOR_NAME','SupplierId,Supplier,SupplierNumber,Status,CreationDate','Supplier ID,Name,Number,Status,Created','ERP','Y','Verifies parent supplier exists in Fusion (site assignments are child resources)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('SupplierContacts','/fscmRestApi/resources/11.13.18.05/suppliers','Supplier={KEY}','VENDOR_NAME','SupplierId,Supplier,SupplierNumber,Status,CreationDate','Supplier ID,Name,Number,Status,Created','ERP','Y','Verifies parent supplier exists in Fusion (contacts are child resources)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('BlanketPOs','/fscmRestApi/resources/11.13.18.05/purchaseAgreements','AgreementNumber={KEY}','SEGMENT1','AgreementHeaderId,AgreementNumber,Supplier,Status,Amount,CurrencyCode','Agreement ID,Number,Supplier,Status,Amount,Currency','ERP','Y','purchaseAgreements resource; query by AgreementNumber = the migrated agreement number. Verified live 2026-07-15.');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Contracts','/fscmRestApi/resources/11.13.18.05/purchaseAgreements','AgreementNumber={KEY}','SEGMENT1','AgreementHeaderId,AgreementNumber,Supplier,Status,Amount,CurrencyCode','Agreement ID,Number,Supplier,Status,Amount,Currency','ERP','Y','purchaseAgreements resource; query by AgreementNumber = the migrated agreement number. Verified live 2026-07-15.');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Grants','/fscmRestApi/resources/11.13.18.05/awards','AwardNumber={KEY}','AWARD_NUMBER','AwardId,AwardNumber,AwardName,SponsorName,StartDate,ContractStatus','Award ID,Award #,Name,Sponsor,Start,Status','ERP','Y','awards resource (gmsGrants does not exist: HTTP 404); query by AwardNumber = the prefixed award number. Verified live 2026-10-07.');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('BenParticipant','/hcmRestApi/resources/11.13.18.05/workers','PersonNumber={KEY}','PERSON_NUMBER','PersonId,PersonNumber,DisplayName,WorkerType,StartDate,CreationDate','Person ID,Number,Name,Type,Start Date,Created','HCM','Y','Verifies worker exists in Fusion (enrollment is child of worker)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Supplier Addresses','/fscmRestApi/resources/11.13.18.05/suppliers','Supplier={KEY}','VENDOR_NAME','SupplierId,Supplier,SupplierNumber,Status,CreationDate','Supplier ID,Name,Number,Status,Created','ERP','Y','Verifies parent supplier (addresses are child)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Supplier Sites','/fscmRestApi/resources/11.13.18.05/suppliers','Supplier={KEY}','VENDOR_NAME','SupplierId,Supplier,SupplierNumber,Status,CreationDate','Supplier ID,Name,Number,Status,Created','ERP','Y','Verifies parent supplier (sites are child)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Site Assignments','/fscmRestApi/resources/11.13.18.05/suppliers','Supplier={KEY}','VENDOR_NAME','SupplierId,Supplier,SupplierNumber,Status,CreationDate','Supplier ID,Name,Number,Status,Created','ERP','Y','Verifies parent supplier (site assigns are child)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Supplier Contacts','/fscmRestApi/resources/11.13.18.05/suppliers','Supplier={KEY}','VENDOR_NAME','SupplierId,Supplier,SupplierNumber,Status,CreationDate','Supplier ID,Name,Number,Status,Created','ERP','Y','Verifies parent supplier (contacts are child)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Blanket PO Headers','/fscmRestApi/resources/11.13.18.05/purchaseAgreements','AgreementNumber={KEY}','SEGMENT1','AgreementHeaderId,AgreementNumber,Supplier,Status,Amount,CurrencyCode','Agreement ID,Number,Supplier,Status,Amount,Currency','ERP','Y','purchaseAgreements resource; query by AgreementNumber. Verified live 2026-07-15.');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Contract Headers','/fscmRestApi/resources/11.13.18.05/purchaseAgreements','AgreementNumber={KEY}','SEGMENT1','AgreementHeaderId,AgreementNumber,Supplier,Status,Amount,CurrencyCode','Agreement ID,Number,Supplier,Status,Amount,Currency','ERP','Y','purchaseAgreements resource; query by AgreementNumber. Verified live 2026-07-15.');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('PO Lines','/fscmRestApi/resources/11.13.18.05/purchaseOrders','OrderNumber={KEY}','DOCUMENT_NUM','POHeaderId,OrderNumber,ProcurementBUId,Supplier,Status,TotalAmount,CurrencyCode','PO ID,Order #,BU ID,Supplier,Status,Total,Currency','ERP','Y','Verifies parent PO (lines are child)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('PO Line Locations','/fscmRestApi/resources/11.13.18.05/purchaseOrders','OrderNumber={KEY}','DOCUMENT_NUM','POHeaderId,OrderNumber,ProcurementBUId,Supplier,Status,TotalAmount,CurrencyCode','PO ID,Order #,BU ID,Supplier,Status,Total,Currency','ERP','Y','Verifies parent PO (line locs are child)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('PO Distributions','/fscmRestApi/resources/11.13.18.05/purchaseOrders','OrderNumber={KEY}','DOCUMENT_NUM','POHeaderId,OrderNumber,ProcurementBUId,Supplier,Status,TotalAmount,CurrencyCode','PO ID,Order #,BU ID,Supplier,Status,Total,Currency','ERP','Y','Verifies parent PO (dists are child)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('AP Invoice Headers','/fscmRestApi/resources/11.13.18.05/invoices','InvoiceNumber={KEY}','INVOICE_NUM','InvoiceId,InvoiceNumber,VendorName,InvoiceAmount,InvoiceCurrencyCode,InvoiceDate,ValidationStatus','Invoice ID,Number,Vendor,Amount,Currency,Date,Status','ERP','Y','Config correct. fin_impl user may lack BU access to see migrated invoices. Verify works for invoices the user can access.');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('AP Invoice Lines','/fscmRestApi/resources/11.13.18.05/invoices','InvoiceNumber={KEY}','INVOICE_NUM','InvoiceId,InvoiceNumber,VendorName,InvoiceAmount,InvoiceCurrencyCode,InvoiceDate,ValidationStatus','Invoice ID,Number,Vendor,Amount,Currency,Date,Status','ERP','Y','Config correct. fin_impl user may lack BU access to see migrated invoices. Verify works for invoices the user can access.');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('GL Journal Lines','/fscmRestApi/resources/11.13.18.05/generalLedgerJournals','JournalHeaderId={KEY}','FUSION_JE_HEADER_ID','JournalHeaderId,JournalBatchName,JournalName,LedgerName,Period,Status','Header ID,Batch,Journal,Ledger,Period,Status','ERP','Y','GL Journal entries');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Award Headers','/fscmRestApi/resources/11.13.18.05/awards','AwardNumber={KEY}','AWARD_NUMBER','AwardId,AwardNumber,AwardName,SponsorName,StartDate,ContractStatus','Award ID,Award #,Name,Sponsor,Start,Status','ERP','Y','awards resource (gmsGrants does not exist: HTTP 404); query by AwardNumber = the prefixed award number. Verified live 2026-10-07.');
exception when dup_val_on_index then null;
end;
/
-- Req Headers: the row the page-57 "Verify in Fusion" button actually uses for a
-- requisition header (its sub-object label matches OBJECT_TYPE directly). Query by
-- RequisitionHeaderId = the Fusion header id the reconciler now stores on the TFM
-- row (FUSION_REQUISITION_HEADER_ID, surfaced as the record's LOOKUP_KEY). That is
-- an exact, user-independent lookup, so it sidesteps the data-security scoping and
-- the system-generated-number problem. MERGE so the change converges on re-run.
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Req Headers' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT"  = '/fscmRestApi/resources/11.13.18.05/purchaseRequisitions',
  t."QUERY_FILTER"   = 'RequisitionHeaderId={KEY}',
  t."KEY_COLUMN"     = 'FUSION_REQUISITION_HEADER_ID',
  t."DISPLAY_FIELDS" = 'RequisitionHeaderId,Requisition,Preparer,DocumentStatus,RequisitioningBU',
  t."DISPLAY_LABELS" = 'Req ID,Number,Preparer,Status,BU',
  t."AUTH_TYPE"      = 'ERP',
  t."ENABLED"        = 'Y',
  t."NOTES"          = 'Verify queries RequisitionHeaderId = the Fusion header id captured by reconciliation onto the TFM (FUSION_REQUISITION_HEADER_ID); exact and user-independent. Runs as the Requisitions load user (DMT_ERP_INTERFACE_OPTIONS_TBL via DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS = calvin.roth).'
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES")
  values ('Req Headers','/fscmRestApi/resources/11.13.18.05/purchaseRequisitions','RequisitionHeaderId={KEY}','FUSION_REQUISITION_HEADER_ID','RequisitionHeaderId,Requisition,Preparer,DocumentStatus,RequisitioningBU','Req ID,Number,Preparer,Status,BU','ERP','Y','Verify queries RequisitionHeaderId = the Fusion header id captured by reconciliation onto the TFM (FUSION_REQUISITION_HEADER_ID); exact and user-independent. Runs as the Requisitions load user (DMT_ERP_INTERFACE_OPTIONS_TBL via DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS = calvin.roth).');
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Req Lines','/fscmRestApi/resources/11.13.18.05/purchaseRequisitions','Requisition={KEY}','REQUISITION_NUMBER','RequisitionHeaderId,RequisitionNumber,PreparerName,Status,TotalAmount,CreationDate','Req ID,Number,Preparer,Status,Amount,Created','ERP','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Req Distributions','/fscmRestApi/resources/11.13.18.05/purchaseRequisitions','Requisition={KEY}','REQUISITION_NUMBER','RequisitionHeaderId,RequisitionNumber,PreparerName,Status,TotalAmount,CreationDate','Req ID,Number,Preparer,Status,Amount,Created','ERP','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('PO Headers','/fscmRestApi/resources/11.13.18.05/purchaseOrders','OrderNumber={KEY}','DOCUMENT_NUM','POHeaderId,OrderNumber,ProcurementBUId,Supplier,Status,TotalAmount,CurrencyCode','PO ID,Order #,BU ID,Supplier,Status,Total,Currency','ERP','Y','Standard PO headers');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('AR Lines','/fscmRestApi/resources/11.13.18.05/receivablesInvoices','CustomerTransactionId={KEY}','FUSION_CUSTOMER_TRX_ID','CustomerTransactionId,TransactionNumber,TransactionDate,BillToCustomerName,TransactionAmount,TransactionStatus','Trx ID,Number,Date,Customer,Amount,Status','ERP','Y','AR invoice lines - queries the parent transaction by the Fusion CustomerTransactionId the reconciler stamped (auto-numbered sources send no TRX_NUMBER)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Tasks','/fscmRestApi/resources/11.13.18.05/projects','ProjectNumber={KEY}','PROJECT_NUMBER','ProjectId,ProjectNumber,ProjectName,ProjectStatusCode,OrganizationName,StartDate','Project ID,Number,Name,Status,Org,Start','ERP','Y','Verifies parent project (tasks are child resources)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Salary Bases','/hcmRestApi/resources/11.13.18.05/salaryBases','SalaryBasisName={KEY}','SALARY_BASIS_NAME','SalaryBasisId,SalaryBasisName,SalaryBasisCode,ElementName,InputValueName','Basis ID,Name,Code,Element,Input Value','HCM','Y','Same as SalaryBases CEMLI entry - SUB_OBJECT display name');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Performance Evaluations','/hcmRestApi/resources/11.13.18.05/performanceEvaluations','PersonNumber={KEY}','PERSON_NUMBER','EvaluationId,PerformanceDocumentName,EvalStatus,PersonNumber,StartDate,EndDate','Evaluation ID,Document,Status,Person,Start,End','HCM','Y','Same as PerfEvaluations CEMLI entry - SUB_OBJECT display name');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Work Schedules','/hcmRestApi/resources/11.13.18.05/workPatterns','PersonNumber={KEY}','PERSON_NUMBER','WorkPatternAssignmentId,PersonNumber,AssignmentNumber,WorkPatternType,DateFrom,RepeatCycle','Pattern ID,Person,Assignment,Type,From Date,Repeat','HCM','Y','Same as WorkSchedules CEMLI entry - SUB_OBJECT display name');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Participant Enrollments','/hcmRestApi/resources/11.13.18.05/workers','PersonNumber={KEY}','PERSON_NUMBER','PersonId,PersonNumber,DisplayName,WorkerType,StartDate,CreationDate','Person ID,Number,Name,Type,Start Date,Created','HCM','Y','Verifies worker exists (enrollments are child of worker)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Person Names','/hcmRestApi/resources/11.13.18.05/workers','PersonNumber={KEY}','PERSON_NUMBER','PersonId,PersonNumber,DisplayName,WorkerType,StartDate,CreationDate','Person ID,Number,Name,Type,Start Date,Created','HCM','Y','Verifies worker exists (person names are child resource)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Person Emails','/hcmRestApi/resources/11.13.18.05/workers','PersonNumber={KEY}','PERSON_NUMBER','PersonId,PersonNumber,DisplayName,WorkerType,StartDate,CreationDate','Person ID,Number,Name,Type,Start Date,Created','HCM','Y','Verifies worker exists (person emails are child resource)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Person Phones','/hcmRestApi/resources/11.13.18.05/workers','PersonNumber={KEY}','PERSON_NUMBER','PersonId,PersonNumber,DisplayName,WorkerType,StartDate,CreationDate','Person ID,Number,Name,Type,Start Date,Created','HCM','Y','Verifies worker exists (person phones are child resource)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Person Addresses','/hcmRestApi/resources/11.13.18.05/workers','PersonNumber={KEY}','PERSON_NUMBER','PersonId,PersonNumber,DisplayName,WorkerType,StartDate,CreationDate','Person ID,Number,Name,Type,Start Date,Created','HCM','Y','Verifies worker exists (person addresses are child resource)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Person NIDs','/hcmRestApi/resources/11.13.18.05/workers','PersonNumber={KEY}','PERSON_NUMBER','PersonId,PersonNumber,DisplayName,WorkerType,StartDate,CreationDate','Person ID,Number,Name,Type,Start Date,Created','HCM','Y','Verifies worker exists (person nids are child resource)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Person Legislation','/hcmRestApi/resources/11.13.18.05/workers','PersonNumber={KEY}','PERSON_NUMBER','PersonId,PersonNumber,DisplayName,WorkerType,StartDate,CreationDate','Person ID,Number,Name,Type,Start Date,Created','HCM','Y','Verifies worker exists (person legislation are child resource)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Work Relationships','/hcmRestApi/resources/11.13.18.05/workers','PersonNumber={KEY}','PERSON_NUMBER','PersonId,PersonNumber,DisplayName,WorkerType,StartDate,CreationDate','Person ID,Number,Name,Type,Start Date,Created','HCM','Y','Verifies worker exists (work relationships are child resource)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Assignments','/hcmRestApi/resources/11.13.18.05/workers','PersonNumber={KEY}','PERSON_NUMBER','PersonId,PersonNumber,DisplayName,WorkerType,StartDate,CreationDate','Person ID,Number,Name,Type,Start Date,Created','HCM','Y','Verifies worker exists (assignments are child resource)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('W2 Balances','/hcmRestApi/resources/11.13.18.05/workers','PersonNumber={KEY}','PERSON_NUMBER','PersonId,PersonNumber,DisplayName,WorkerType,StartDate,CreationDate','Person ID,Number,Name,Type,Start Date,Created','HCM','Y','Verifies worker exists (w2 balances are child resource)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Dependent Enrollments','/hcmRestApi/resources/11.13.18.05/workers','PersonNumber={KEY}','PERSON_NUMBER','PersonId,PersonNumber,DisplayName,WorkerType,StartDate,CreationDate','Person ID,Number,Name,Type,Start Date,Created','HCM','Y','Verifies worker exists (dependent enrollments are child resource)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Beneficiary Designations','/hcmRestApi/resources/11.13.18.05/workers','PersonNumber={KEY}','PERSON_NUMBER','PersonId,PersonNumber,DisplayName,WorkerType,StartDate,CreationDate','Person ID,Number,Name,Type,Start Date,Created','HCM','Y','Verifies worker exists (beneficiary designations are child resource)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Payroll Relationships','/hcmRestApi/resources/11.13.18.05/workers','PersonNumber={KEY}','PERSON_NUMBER','PersonId,PersonNumber,DisplayName,WorkerType,StartDate,CreationDate','Person ID,Number,Name,Type,Start Date,Created','HCM','Y','Verifies worker exists (payroll relationships are child resource)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Tax Cards','/hcmRestApi/resources/11.13.18.05/workers','PersonNumber={KEY}','PERSON_NUMBER','PersonId,PersonNumber,DisplayName,WorkerType,StartDate,CreationDate','Person ID,Number,Name,Type,Start Date,Created','HCM','Y','Verifies worker exists (tax cards are child resource)');
exception when dup_val_on_index then null;
end;
/
-- Verify-in-Fusion corrections 2026-10-08 (backlog #460-#468): each row below was
-- checked against the live demo pod with a read-only GET before being configured.
-- MERGE (registry seeds converge on re-run) so the corrections reach existing databases.
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Assets' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/fixedAssets',
  t."QUERY_FILTER" = 'AssetNumber={KEY}',
  t."KEY_COLUMN" = 'ASSET_NUMBER',
  t."DISPLAY_FIELDS" = 'AssetNumber',
  t."DISPLAY_LABELS" = 'Asset #',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Fixed Assets: Verify reports NOT_APPLICABLE (no Fusion REST read resource; see NOT_APPLICABLE_REASON). Asset Books / Asset Assignments resolve here through the object catalog.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = 'Fusion Assets has no REST read resource on this pod: fixedAssets, assets, assetBooks, fixedAssetBooks, assetDistributions, assetTransactions, massAdditions and other candidate names all return HTTP 404 (2026-10-08), and Oracle documents Fixed Assets REST only as erpintegrations write operations. Asset records are proven by BIP reconciliation against the FA base tables.'
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Assets', '/fscmRestApi/resources/11.13.18.05/fixedAssets', 'AssetNumber={KEY}', 'ASSET_NUMBER', 'AssetNumber', 'Asset #', 'ERP', 'Y', 'Fixed Assets: Verify reports NOT_APPLICABLE (no Fusion REST read resource; see NOT_APPLICABLE_REASON). Asset Books / Asset Assignments resolve here through the object catalog.', NULL, NULL, NULL, 'Fusion Assets has no REST read resource on this pod: fixedAssets, assets, assetBooks, fixedAssetBooks, assetDistributions, assetTransactions, massAdditions and other candidate names all return HTTP 404 (2026-10-08), and Oracle documents Fixed Assets REST only as erpintegrations write operations. Asset records are proven by BIP reconciliation against the FA base tables.');
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Asset Headers' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/fixedAssets',
  t."QUERY_FILTER" = 'AssetNumber={KEY}',
  t."KEY_COLUMN" = 'ASSET_NUMBER',
  t."DISPLAY_FIELDS" = 'AssetNumber',
  t."DISPLAY_LABELS" = 'Asset #',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Asset headers - same as the Assets row: NOT_APPLICABLE, no Fusion REST read resource.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = 'Fusion Assets has no REST read resource on this pod: fixedAssets, assets, assetBooks, fixedAssetBooks, assetDistributions, assetTransactions, massAdditions and other candidate names all return HTTP 404 (2026-10-08), and Oracle documents Fixed Assets REST only as erpintegrations write operations. Asset records are proven by BIP reconciliation against the FA base tables.'
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Asset Headers', '/fscmRestApi/resources/11.13.18.05/fixedAssets', 'AssetNumber={KEY}', 'ASSET_NUMBER', 'AssetNumber', 'Asset #', 'ERP', 'Y', 'Asset headers - same as the Assets row: NOT_APPLICABLE, no Fusion REST read resource.', NULL, NULL, NULL, 'Fusion Assets has no REST read resource on this pod: fixedAssets, assets, assetBooks, fixedAssetBooks, assetDistributions, assetTransactions, massAdditions and other candidate names all return HTTP 404 (2026-10-08), and Oracle documents Fixed Assets REST only as erpintegrations write operations. Asset records are proven by BIP reconciliation against the FA base tables.');
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'BillingEvents' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/projectBillingEvents',
  t."QUERY_FILTER" = 'EventId={KEY}',
  t."KEY_COLUMN" = 'FUSION_BILLING_EVENT_ID',
  t."DISPLAY_FIELDS" = 'EventId,EventNumber,SourceReference,ContractNumber,ProjectNumber,CompletionDate,BillTrnsAmount,BillTrnsCurrencyCode',
  t."DISPLAY_LABELS" = 'Event ID,Event #,Source Ref,Contract,Project,Date,Amount,Currency',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'projectBillingEvents queried by EventId = the Fusion event id reconciliation stamped (FUSION_EVENT_ID). The resource needs a Projects billing role: fin_impl gets HTTP 403, ppm_impl reads it, so BillingEvents runs as ppm_impl (its DMT_ERP_INTERFACE_OPTIONS_TBL row, resolved by GET_CEMLI_CREDENTIALS; backlog #462). Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('BillingEvents', '/fscmRestApi/resources/11.13.18.05/projectBillingEvents', 'EventId={KEY}', 'FUSION_BILLING_EVENT_ID', 'EventId,EventNumber,SourceReference,ContractNumber,ProjectNumber,CompletionDate,BillTrnsAmount,BillTrnsCurrencyCode', 'Event ID,Event #,Source Ref,Contract,Project,Date,Amount,Currency', 'ERP', 'Y', 'projectBillingEvents queried by EventId = the Fusion event id reconciliation stamped (FUSION_EVENT_ID). The resource needs a Projects billing role: fin_impl gets HTTP 403, ppm_impl reads it, so BillingEvents runs as ppm_impl (its DMT_ERP_INTERFACE_OPTIONS_TBL row, resolved by GET_CEMLI_CREDENTIALS; backlog #462). Verified live on the demo pod 2026-10-08.', NULL, NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Billing Events' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/projectBillingEvents',
  t."QUERY_FILTER" = 'EventId={KEY}',
  t."KEY_COLUMN" = 'FUSION_BILLING_EVENT_ID',
  t."DISPLAY_FIELDS" = 'EventId,EventNumber,SourceReference,ContractNumber,ProjectNumber,CompletionDate,BillTrnsAmount,BillTrnsCurrencyCode',
  t."DISPLAY_LABELS" = 'Event ID,Event #,Source Ref,Contract,Project,Date,Amount,Currency',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Project billing events - same as the BillingEvents row (EventId = FUSION_EVENT_ID). Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Billing Events', '/fscmRestApi/resources/11.13.18.05/projectBillingEvents', 'EventId={KEY}', 'FUSION_BILLING_EVENT_ID', 'EventId,EventNumber,SourceReference,ContractNumber,ProjectNumber,CompletionDate,BillTrnsAmount,BillTrnsCurrencyCode', 'Event ID,Event #,Source Ref,Contract,Project,Date,Amount,Currency', 'ERP', 'Y', 'Project billing events - same as the BillingEvents row (EventId = FUSION_EVENT_ID). Verified live on the demo pod 2026-10-08.', NULL, NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Locations' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/crmRestApi/resources/11.13.18.05/hubOrganizations',
  t."QUERY_FILTER" = 'Address.LocationId={KEY}',
  t."KEY_COLUMN" = 'FUSION_LOCATION_ID',
  t."DISPLAY_FIELDS" = 'PartyId,PartyNumber,OrganizationName,SourceSystemReferenceValue,FormattedAddress',
  t."DISPLAY_LABELS" = 'Party ID,Party #,Name,Source Ref,Primary Address',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Customer locations - Fusion has no standalone REST resource for HZ locations; the party that uses the location is read with a child filter on its Address.LocationId (REST-Framework-Version 4). A location not attached to any party site is not reachable over REST. Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = '4',
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Locations', '/crmRestApi/resources/11.13.18.05/hubOrganizations', 'Address.LocationId={KEY}', 'FUSION_LOCATION_ID', 'PartyId,PartyNumber,OrganizationName,SourceSystemReferenceValue,FormattedAddress', 'Party ID,Party #,Name,Source Ref,Primary Address', 'ERP', 'Y', 'Customer locations - Fusion has no standalone REST resource for HZ locations; the party that uses the location is read with a child filter on its Address.LocationId (REST-Framework-Version 4). A location not attached to any party site is not reachable over REST. Verified live on the demo pod 2026-10-08.', '4', NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Party Sites' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/crmRestApi/resources/11.13.18.05/hubOrganizations',
  t."QUERY_FILTER" = 'Address.AddressId={KEY}',
  t."KEY_COLUMN" = 'FUSION_PARTY_SITE_ID',
  t."DISPLAY_FIELDS" = 'PartyId,PartyNumber,OrganizationName,SourceSystemReferenceValue,FormattedAddress',
  t."DISPLAY_LABELS" = 'Party ID,Party #,Name,Source Ref,Primary Address',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Party sites - hubOrganizations child filter Address.AddressId = the Fusion party site id (REST-Framework-Version 4). Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = '4',
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Party Sites', '/crmRestApi/resources/11.13.18.05/hubOrganizations', 'Address.AddressId={KEY}', 'FUSION_PARTY_SITE_ID', 'PartyId,PartyNumber,OrganizationName,SourceSystemReferenceValue,FormattedAddress', 'Party ID,Party #,Name,Source Ref,Primary Address', 'ERP', 'Y', 'Party sites - hubOrganizations child filter Address.AddressId = the Fusion party site id (REST-Framework-Version 4). Verified live on the demo pod 2026-10-08.', '4', NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Party Site Uses' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/crmRestApi/resources/11.13.18.05/hubOrganizations',
  t."QUERY_FILTER" = 'Address.AddressPurpose.AddressPurposeId={KEY}',
  t."KEY_COLUMN" = 'FUSION_PARTY_SITE_USE_ID',
  t."DISPLAY_FIELDS" = 'PartyId,PartyNumber,OrganizationName,SourceSystemReferenceValue,FormattedAddress',
  t."DISPLAY_LABELS" = 'Party ID,Party #,Name,Source Ref,Primary Address',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Party site uses - hubOrganizations child filter Address.AddressPurpose.AddressPurposeId = the Fusion party site use id (REST-Framework-Version 4). Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = '4',
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Party Site Uses', '/crmRestApi/resources/11.13.18.05/hubOrganizations', 'Address.AddressPurpose.AddressPurposeId={KEY}', 'FUSION_PARTY_SITE_USE_ID', 'PartyId,PartyNumber,OrganizationName,SourceSystemReferenceValue,FormattedAddress', 'Party ID,Party #,Name,Source Ref,Primary Address', 'ERP', 'Y', 'Party site uses - hubOrganizations child filter Address.AddressPurpose.AddressPurposeId = the Fusion party site use id (REST-Framework-Version 4). Verified live on the demo pod 2026-10-08.', '4', NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Accounts' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/receivablesCustomerAccountActivities',
  t."QUERY_FILTER" = 'AccountId={KEY}',
  t."KEY_COLUMN" = 'FUSION_CUST_ACCOUNT_ID',
  t."DISPLAY_FIELDS" = 'AccountId,AccountNumber,CustomerName,CustomerId,CreationDate',
  t."DISPLAY_LABELS" = 'Account ID,Account #,Customer,Party ID,Created',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Customer accounts - receivablesCustomerAccountActivities by AccountId = the Fusion cust account id (hubOrganizations does not exist under fscmRestApi: HTTP 404). Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Accounts', '/fscmRestApi/resources/11.13.18.05/receivablesCustomerAccountActivities', 'AccountId={KEY}', 'FUSION_CUST_ACCOUNT_ID', 'AccountId,AccountNumber,CustomerName,CustomerId,CreationDate', 'Account ID,Account #,Customer,Party ID,Created', 'ERP', 'Y', 'Customer accounts - receivablesCustomerAccountActivities by AccountId = the Fusion cust account id (hubOrganizations does not exist under fscmRestApi: HTTP 404). Verified live on the demo pod 2026-10-08.', NULL, NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Account Sites' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/receivablesCustomerAccountSiteActivities',
  t."QUERY_FILTER" = 'BillToSiteUseId={KEY}',
  t."KEY_COLUMN" = 'FUSION_SITE_USE_ID (BILL_TO use of the site)',
  t."DISPLAY_FIELDS" = 'BillToSiteUseId,BillToSiteNumber,BillToSiteAddress,AccountNumber,CustomerName',
  t."DISPLAY_LABELS" = 'Bill-To Use ID,Site #,Address,Account #,Customer',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Customer account sites - Fusion exposes account sites over REST only through their bill-to use, so the record-detail key is the Fusion id of the BILL_TO use of this site from the same run. Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Account Sites', '/fscmRestApi/resources/11.13.18.05/receivablesCustomerAccountSiteActivities', 'BillToSiteUseId={KEY}', 'FUSION_SITE_USE_ID (BILL_TO use of the site)', 'BillToSiteUseId,BillToSiteNumber,BillToSiteAddress,AccountNumber,CustomerName', 'Bill-To Use ID,Site #,Address,Account #,Customer', 'ERP', 'Y', 'Customer account sites - Fusion exposes account sites over REST only through their bill-to use, so the record-detail key is the Fusion id of the BILL_TO use of this site from the same run. Verified live on the demo pod 2026-10-08.', NULL, NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Account Site Uses' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/receivablesCustomerAccountSiteActivities',
  t."QUERY_FILTER" = 'BillToSiteUseId={KEY}',
  t."KEY_COLUMN" = 'FUSION_SITE_USE_ID',
  t."DISPLAY_FIELDS" = 'BillToSiteUseId,BillToSiteNumber,BillToSiteAddress,AccountNumber,CustomerName',
  t."DISPLAY_LABELS" = 'Bill-To Use ID,Site #,Address,Account #,Customer',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Customer account site uses - receivablesCustomerAccountSiteActivities by BillToSiteUseId = the Fusion site use id. The resource lists bill-to uses only. Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Account Site Uses', '/fscmRestApi/resources/11.13.18.05/receivablesCustomerAccountSiteActivities', 'BillToSiteUseId={KEY}', 'FUSION_SITE_USE_ID', 'BillToSiteUseId,BillToSiteNumber,BillToSiteAddress,AccountNumber,CustomerName', 'Bill-To Use ID,Site #,Address,Account #,Customer', 'ERP', 'Y', 'Customer account site uses - receivablesCustomerAccountSiteActivities by BillToSiteUseId = the Fusion site use id. The resource lists bill-to uses only. Verified live on the demo pod 2026-10-08.', NULL, NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Expenditures' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/projectCosts',
  t."QUERY_FILTER" = 'TransactionNumber={KEY}',
  t."KEY_COLUMN" = 'FUSION_EXPENDITURE_ITEM_ID',
  t."DISPLAY_FIELDS" = 'TransactionNumber,OriginalTransactionReference,ProjectNumber,TaskNumber,ExpenditureType,ExpenditureItemDate,Quantity,RawCostInTransactionCurrency',
  t."DISPLAY_LABELS" = 'Item ID,Source Ref,Project,Task,Type,Date,Qty,Raw Cost',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Project expenditure items - projectCosts by TransactionNumber = the Fusion expenditure item id reconciliation stamped. projectExpenditureItems only carries bill-rate overrides, and a non-numeric key there returned HTTP 500 (backlog #314). Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Expenditures', '/fscmRestApi/resources/11.13.18.05/projectCosts', 'TransactionNumber={KEY}', 'FUSION_EXPENDITURE_ITEM_ID', 'TransactionNumber,OriginalTransactionReference,ProjectNumber,TaskNumber,ExpenditureType,ExpenditureItemDate,Quantity,RawCostInTransactionCurrency', 'Item ID,Source Ref,Project,Task,Type,Date,Qty,Raw Cost', 'ERP', 'Y', 'Project expenditure items - projectCosts by TransactionNumber = the Fusion expenditure item id reconciliation stamped. projectExpenditureItems only carries bill-rate overrides, and a non-numeric key there returned HTTP 500 (backlog #314). Verified live on the demo pod 2026-10-08.', NULL, NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Expenditure Items' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/projectCosts',
  t."QUERY_FILTER" = 'TransactionNumber={KEY}',
  t."KEY_COLUMN" = 'FUSION_EXPENDITURE_ITEM_ID',
  t."DISPLAY_FIELDS" = 'TransactionNumber,OriginalTransactionReference,ProjectNumber,TaskNumber,ExpenditureType,ExpenditureItemDate,Quantity,RawCostInTransactionCurrency',
  t."DISPLAY_LABELS" = 'Item ID,Source Ref,Project,Task,Type,Date,Qty,Raw Cost',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Expenditure items - same as the Expenditures row (projectCosts TransactionNumber = Fusion expenditure item id). Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Expenditure Items', '/fscmRestApi/resources/11.13.18.05/projectCosts', 'TransactionNumber={KEY}', 'FUSION_EXPENDITURE_ITEM_ID', 'TransactionNumber,OriginalTransactionReference,ProjectNumber,TaskNumber,ExpenditureType,ExpenditureItemDate,Quantity,RawCostInTransactionCurrency', 'Item ID,Source Ref,Project,Task,Type,Date,Qty,Raw Cost', 'ERP', 'Y', 'Expenditure items - same as the Expenditures row (projectCosts TransactionNumber = Fusion expenditure item id). Verified live on the demo pod 2026-10-08.', NULL, NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'GLBudgets' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/ledgerBalances',
  t."QUERY_FILTER" = 'finder=AccountBalanceFinder;mode=Detail,{KEY}',
  t."KEY_COLUMN" = 'LEDGER_NAME/SEGMENTn/PERIOD_NAME/CURRENCY_CODE/BUDGET_NAME',
  t."DISPLAY_FIELDS" = 'LedgerName,AccountCombination,PeriodName,Scenario,PeriodActivity,EndingBalance,Currency',
  t."DISPLAY_LABELS" = 'Ledger,Account,Period,Budget,Period Amount,Ending Balance,Currency',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'GL budget balances - ledgerBalances AccountBalanceFinder (ledger, account combination, period, currency, scenario = budget name; generalLedgerJournals holds no budget data and 404s). The resource always answers one row, so PeriodActivity = #Missing means not found. Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = 'PeriodActivity',
  t."ABSENT_VALUE" = '#Missing',
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('GLBudgets', '/fscmRestApi/resources/11.13.18.05/ledgerBalances', 'finder=AccountBalanceFinder;mode=Detail,{KEY}', 'LEDGER_NAME/SEGMENTn/PERIOD_NAME/CURRENCY_CODE/BUDGET_NAME', 'LedgerName,AccountCombination,PeriodName,Scenario,PeriodActivity,EndingBalance,Currency', 'Ledger,Account,Period,Budget,Period Amount,Ending Balance,Currency', 'ERP', 'Y', 'GL budget balances - ledgerBalances AccountBalanceFinder (ledger, account combination, period, currency, scenario = budget name; generalLedgerJournals holds no budget data and 404s). The resource always answers one row, so PeriodActivity = #Missing means not found. Verified live on the demo pod 2026-10-08.', NULL, 'PeriodActivity', '#Missing', NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'MiscReceipts' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/inventoryCompletedTransactions',
  t."QUERY_FILTER" = 'TransactionId={KEY}',
  t."KEY_COLUMN" = 'FUSION_ID',
  t."DISPLAY_FIELDS" = 'TransactionId,Item,TransactionType,TransactionQuantity,TransactionUOM,SubinventoryCode,TransactionDate,Reference',
  t."DISPLAY_LABELS" = 'Txn ID,Item,Type,Qty,UOM,Subinventory,Date,Reference',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Miscellaneous receipts - inventoryCompletedTransactions by TransactionId = the Fusion transaction id. Runs as the MiscReceipts load user (scm_impl). Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('MiscReceipts', '/fscmRestApi/resources/11.13.18.05/inventoryCompletedTransactions', 'TransactionId={KEY}', 'FUSION_ID', 'TransactionId,Item,TransactionType,TransactionQuantity,TransactionUOM,SubinventoryCode,TransactionDate,Reference', 'Txn ID,Item,Type,Qty,UOM,Subinventory,Date,Reference', 'ERP', 'Y', 'Miscellaneous receipts - inventoryCompletedTransactions by TransactionId = the Fusion transaction id. Runs as the MiscReceipts load user (scm_impl). Verified live on the demo pod 2026-10-08.', NULL, NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Inventory Transactions' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/inventoryCompletedTransactions',
  t."QUERY_FILTER" = 'TransactionId={KEY}',
  t."KEY_COLUMN" = 'FUSION_ID',
  t."DISPLAY_FIELDS" = 'TransactionId,Item,TransactionType,TransactionQuantity,TransactionUOM,SubinventoryCode,TransactionDate,Reference',
  t."DISPLAY_LABELS" = 'Txn ID,Item,Type,Qty,UOM,Subinventory,Date,Reference',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Inventory transactions - inventoryCompletedTransactions by TransactionId = the Fusion transaction id. Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Inventory Transactions', '/fscmRestApi/resources/11.13.18.05/inventoryCompletedTransactions', 'TransactionId={KEY}', 'FUSION_ID', 'TransactionId,Item,TransactionType,TransactionQuantity,TransactionUOM,SubinventoryCode,TransactionDate,Reference', 'Txn ID,Item,Type,Qty,UOM,Subinventory,Date,Reference', 'ERP', 'Y', 'Inventory transactions - inventoryCompletedTransactions by TransactionId = the Fusion transaction id. Verified live on the demo pod 2026-10-08.', NULL, NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Transaction Lots' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/inventoryCompletedTransactions',
  t."QUERY_FILTER" = 'TransactionId={KEY}',
  t."KEY_COLUMN" = 'FUSION_TRANSACTION_ID',
  t."DISPLAY_FIELDS" = 'TransactionId,Item,TransactionType,TransactionQuantity,TransactionUOM,SubinventoryCode,TransactionDate,Reference',
  t."DISPLAY_LABELS" = 'Txn ID,Item,Type,Qty,UOM,Subinventory,Date,Reference',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Transaction lots - reads back the Fusion transaction the lot was received under (FUSION_TRANSACTION_ID on the lot row); the transaction carries the lot as its lots child. Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Transaction Lots', '/fscmRestApi/resources/11.13.18.05/inventoryCompletedTransactions', 'TransactionId={KEY}', 'FUSION_TRANSACTION_ID', 'TransactionId,Item,TransactionType,TransactionQuantity,TransactionUOM,SubinventoryCode,TransactionDate,Reference', 'Txn ID,Item,Type,Qty,UOM,Subinventory,Date,Reference', 'ERP', 'Y', 'Transaction lots - reads back the Fusion transaction the lot was received under (FUSION_TRANSACTION_ID on the lot row); the transaction carries the lot as its lots child. Verified live on the demo pod 2026-10-08.', NULL, NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Transaction Serials' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/inventoryItemSerialNumbers',
  t."QUERY_FILTER" = 'SerialNumber={KEY}',
  t."KEY_COLUMN" = 'FM_SERIAL_NUMBER',
  t."DISPLAY_FIELDS" = 'SerialNumber,ItemNumber,OrganizationCode,SubinventoryCode,StatusCode,ReceiptDate',
  t."DISPLAY_LABELS" = 'Serial #,Item,Org,Subinventory,Status,Received',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Transaction serials - inventoryItemSerialNumbers by SerialNumber = the run-prefixed serial number (the serial row carries no Fusion id). Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Transaction Serials', '/fscmRestApi/resources/11.13.18.05/inventoryItemSerialNumbers', 'SerialNumber={KEY}', 'FM_SERIAL_NUMBER', 'SerialNumber,ItemNumber,OrganizationCode,SubinventoryCode,StatusCode,ReceiptDate', 'Serial #,Item,Org,Subinventory,Status,Received', 'ERP', 'Y', 'Transaction serials - inventoryItemSerialNumbers by SerialNumber = the run-prefixed serial number (the serial row carries no Fusion id). Verified live on the demo pod 2026-10-08.', NULL, NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'ProjectBudgets' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/projectBudgets',
  t."QUERY_FILTER" = 'PlanVersionId={KEY}',
  t."KEY_COLUMN" = 'FUSION_BUDGET_VERSION_ID',
  t."DISPLAY_FIELDS" = 'PlanVersionId,PlanVersionName,PlanVersionNumber,PlanVersionStatus,ProjectNumber,FinancialPlanType',
  t."DISPLAY_LABELS" = 'Version ID,Version,Version #,Status,Project,Plan Type',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Project budgets - projectBudgets by PlanVersionId = the Fusion budget version id reconciliation stamped. Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('ProjectBudgets', '/fscmRestApi/resources/11.13.18.05/projectBudgets', 'PlanVersionId={KEY}', 'FUSION_BUDGET_VERSION_ID', 'PlanVersionId,PlanVersionName,PlanVersionNumber,PlanVersionStatus,ProjectNumber,FinancialPlanType', 'Version ID,Version,Version #,Status,Project,Plan Type', 'ERP', 'Y', 'Project budgets - projectBudgets by PlanVersionId = the Fusion budget version id reconciliation stamped. Verified live on the demo pod 2026-10-08.', NULL, NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Project Budget Lines' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/projectBudgets',
  t."QUERY_FILTER" = 'PlanVersionId={KEY}',
  t."KEY_COLUMN" = 'FUSION_BUDGET_VERSION_ID',
  t."DISPLAY_FIELDS" = 'PlanVersionId,PlanVersionName,PlanVersionNumber,PlanVersionStatus,ProjectNumber,FinancialPlanType',
  t."DISPLAY_LABELS" = 'Version ID,Version,Version #,Status,Project,Plan Type',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Project budget lines - the budget version they belong to, by PlanVersionId = FUSION_BUDGET_VERSION_ID. Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Project Budget Lines', '/fscmRestApi/resources/11.13.18.05/projectBudgets', 'PlanVersionId={KEY}', 'FUSION_BUDGET_VERSION_ID', 'PlanVersionId,PlanVersionName,PlanVersionNumber,PlanVersionStatus,ProjectNumber,FinancialPlanType', 'Version ID,Version,Version #,Status,Project,Plan Type', 'ERP', 'Y', 'Project budget lines - the budget version they belong to, by PlanVersionId = FUSION_BUDGET_VERSION_ID. Verified live on the demo pod 2026-10-08.', NULL, NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Team Members' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/fscmRestApi/resources/11.13.18.05/projects',
  t."QUERY_FILTER" = 'ProjectTeamMembers.TeamMemberId={KEY}',
  t."KEY_COLUMN" = 'FUSION_PROJECT_PARTY_ID',
  t."DISPLAY_FIELDS" = 'ProjectId,ProjectNumber,ProjectName,ProjectStatusCode,OrganizationName,StartDate',
  t."DISPLAY_LABELS" = 'Project ID,Number,Name,Status,Org,Start',
  t."AUTH_TYPE" = 'ERP',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Project team members - the project read with a child filter ProjectTeamMembers.TeamMemberId = the Fusion team member id (REST-Framework-Version 4). Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = '4',
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Team Members', '/fscmRestApi/resources/11.13.18.05/projects', 'ProjectTeamMembers.TeamMemberId={KEY}', 'FUSION_PROJECT_PARTY_ID', 'ProjectId,ProjectNumber,ProjectName,ProjectStatusCode,OrganizationName,StartDate', 'Project ID,Number,Name,Status,Org,Start', 'ERP', 'Y', 'Project team members - the project read with a child filter ProjectTeamMembers.TeamMemberId = the Fusion team member id (REST-Framework-Version 4). Verified live on the demo pod 2026-10-08.', '4', NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'TalentProfiles' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/hcmRestApi/resources/11.13.18.05/talentPersonProfiles',
  t."QUERY_FILTER" = 'ProfileId={KEY}',
  t."KEY_COLUMN" = 'FUSION_PROFILE_ID',
  t."DISPLAY_FIELDS" = 'ProfileId,ProfileCode,PersonNumber,DisplayName,LastUpdateDate',
  t."DISPLAY_LABELS" = 'Profile ID,Code,Person,Name,Updated',
  t."AUTH_TYPE" = 'HCM',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Talent profiles - talentPersonProfiles by ProfileId = the Fusion profile id (talentProfiles does not exist: HTTP 404). Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('TalentProfiles', '/hcmRestApi/resources/11.13.18.05/talentPersonProfiles', 'ProfileId={KEY}', 'FUSION_PROFILE_ID', 'ProfileId,ProfileCode,PersonNumber,DisplayName,LastUpdateDate', 'Profile ID,Code,Person,Name,Updated', 'HCM', 'Y', 'Talent profiles - talentPersonProfiles by ProfileId = the Fusion profile id (talentProfiles does not exist: HTTP 404). Verified live on the demo pod 2026-10-08.', NULL, NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Talent Profiles' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/hcmRestApi/resources/11.13.18.05/talentPersonProfiles',
  t."QUERY_FILTER" = 'ProfileId={KEY}',
  t."KEY_COLUMN" = 'FUSION_PROFILE_ID',
  t."DISPLAY_FIELDS" = 'ProfileId,ProfileCode,PersonNumber,DisplayName,LastUpdateDate',
  t."DISPLAY_LABELS" = 'Profile ID,Code,Person,Name,Updated',
  t."AUTH_TYPE" = 'HCM',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Same as the TalentProfiles row (talentPersonProfiles by ProfileId). Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = NULL,
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Talent Profiles', '/hcmRestApi/resources/11.13.18.05/talentPersonProfiles', 'ProfileId={KEY}', 'FUSION_PROFILE_ID', 'ProfileId,ProfileCode,PersonNumber,DisplayName,LastUpdateDate', 'Profile ID,Code,Person,Name,Updated', 'HCM', 'Y', 'Same as the TalentProfiles row (talentPersonProfiles by ProfileId). Verified live on the demo pod 2026-10-08.', NULL, NULL, NULL, NULL);
merge into "DMT_REST_LOOKUP_TBL" t
using (select 'Profile Items' as "OBJECT_TYPE" from dual) s
on (t."OBJECT_TYPE" = s."OBJECT_TYPE")
when matched then update set
  t."REST_ENDPOINT" = '/hcmRestApi/resources/11.13.18.05/talentPersonProfiles',
  t."QUERY_FILTER" = 'languageSections.languageItems.LanguageId={KEY} or competencySections.competencyItems.CompetencyId={KEY}',
  t."KEY_COLUMN" = 'FUSION_PROFILE_ITEM_ID',
  t."DISPLAY_FIELDS" = 'ProfileId,ProfileCode,PersonNumber,DisplayName,LastUpdateDate',
  t."DISPLAY_LABELS" = 'Profile ID,Code,Person,Name,Updated',
  t."AUTH_TYPE" = 'HCM',
  t."ENABLED" = 'Y',
  t."NOTES" = 'Profile items - the owning profile read with a child filter on the item id (language items: LanguageId, verified; competency items: CompetencyId, attribute accepted by the pod, no LOADED competency item yet to prove). REST-Framework-Version 4. Verified live on the demo pod 2026-10-08.',
  t."REST_FRAMEWORK_VERSION" = '4',
  t."ABSENT_FIELD" = NULL,
  t."ABSENT_VALUE" = NULL,
  t."NOT_APPLICABLE_REASON" = NULL
when not matched then insert ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES","REST_FRAMEWORK_VERSION","ABSENT_FIELD","ABSENT_VALUE","NOT_APPLICABLE_REASON")
  values ('Profile Items', '/hcmRestApi/resources/11.13.18.05/talentPersonProfiles', 'languageSections.languageItems.LanguageId={KEY} or competencySections.competencyItems.CompetencyId={KEY}', 'FUSION_PROFILE_ITEM_ID', 'ProfileId,ProfileCode,PersonNumber,DisplayName,LastUpdateDate', 'Profile ID,Code,Person,Name,Updated', 'HCM', 'Y', 'Profile items - the owning profile read with a child filter on the item id (language items: LanguageId, verified; competency items: CompetencyId, attribute accepted by the pod, no LOADED competency item yet to prove). REST-Framework-Version 4. Verified live on the demo pod 2026-10-08.', '4', NULL, NULL, NULL);
commit;

-- Backlog #430: the HCM registry rows whose OBJECT_TYPE is not in the object display
-- catalog name their object code, so the verify resolves their Fusion user (hcm_impl)
-- through DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS like every other object. Re-runnable.
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
