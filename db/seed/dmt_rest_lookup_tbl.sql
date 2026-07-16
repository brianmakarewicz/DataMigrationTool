-- Seed data for DMT_REST_LOOKUP_TBL (68 rows, snapshot 2026-07-03)
-- Idempotent: duplicate-key inserts are skipped.
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
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('ARInvoices','/fscmRestApi/resources/11.13.18.05/receivablesInvoices','TransactionNumber={KEY}','TRX_NUMBER','CustomerTransactionId,TransactionNumber,TransactionDate,BillToCustomerName,TransactionAmount,TransactionStatus','Trx ID,Number,Date,Customer,Amount,Status','ERP','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('GLBalances','/fscmRestApi/resources/11.13.18.05/generalLedgerJournals','JournalHeaderId={KEY}','FUSION_JE_HEADER_ID','JournalHeaderId,JournalBatchName,JournalName,LedgerName,Period,Status','Header ID,Batch,Journal,Ledger,Period,Status','ERP','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Projects','/fscmRestApi/resources/11.13.18.05/projects','ProjectNumber={KEY}','PROJECT_NUMBER','ProjectId,ProjectNumber,ProjectName,ProjectStatusCode,OrganizationName,StartDate','Project ID,Number,Name,Status,Org,Start','ERP','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Assets','/fscmRestApi/resources/11.13.18.05/fixedAssets','AssetNumber={KEY}','ASSET_NUMBER','AssetId,AssetNumber,Description,AssetType,CurrentCost,DatePlacedInService','Asset ID,Number,Description,Type,Cost,In-Service Date','ERP','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Requisitions','/fscmRestApi/resources/11.13.18.05/purchaseRequisitions','Requisition={KEY}','REQUISITION_NUMBER','RequisitionHeaderId,RequisitionNumber,PreparerName,Status,TotalAmount,CreationDate','Req ID,Number,Preparer,Status,Amount,Created','ERP','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Expenditures','/fscmRestApi/resources/11.13.18.05/projectExpenditureItems','ExpenditureItemId={KEY}','FUSION_EXPENDITURE_ITEM_ID','ExpenditureItemId,ProjectNumber,TaskNumber,ExpenditureType,ItemDate,Quantity,Amount','Item ID,Project,Task,Type,Date,Qty,Amount','ERP','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('BillingEvents','/fscmRestApi/resources/11.13.18.05/projectBillingEvents','BillingEventId={KEY}','FUSION_BILLING_EVENT_ID','BillingEventId,EventNumber,ProjectNumber,EventDate,Amount,CurrencyCode,EventStatus','Event ID,Number,Project,Date,Amount,Currency,Status','ERP','Y',NULL);
exception when dup_val_on_index then null;
end;
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
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Salaries','/hcmRestApi/resources/11.13.18.05/salaries','AssignmentNumber={KEY}','PERSON_NUMBER','SalaryId,AssignmentNumber,SalaryAmount,SalaryBasisName,DateFrom,ActionCode','Salary ID,Assignment,Amount,Basis,From Date,Action','HCM','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('TalentProfiles','/hcmRestApi/resources/11.13.18.05/talentProfiles','PersonNumber={KEY}','PERSON_NUMBER','ProfileId,ProfileCode,PersonNumber,ProfileTypeCode,ProfileStatusCode,ProfileUsageCode','Profile ID,Code,Person,Type,Status,Usage','HCM','Y',NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('PerfEvaluations','/hcmRestApi/resources/11.13.18.05/goalPlans','PersonNumber={KEY}','PERSON_NUMBER','GoalPlanId,GoalPlanName,GoalPlanTypeCode,PersonNumber,StartDate,EndDate','Plan ID,Name,Type,Person,Start,End','HCM','Y',NULL);
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
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Grants','/fscmRestApi/resources/11.13.18.05/gmsGrants','AwardNumber={KEY}','AWARD_NUMBER','GrantId,AwardNumber,AwardName,AwardStatusCode,SponsorName,StartDate','Grant ID,Award #,Name,Status,Sponsor,Start','ERP','Y','Grants management awards');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('GLBudgets','/fscmRestApi/resources/11.13.18.05/generalLedgerJournals','JournalHeaderId={KEY}','FUSION_JE_HEADER_ID','JournalHeaderId,JournalBatchName,JournalName,LedgerName,Period,Status','Header ID,Batch,Journal,Ledger,Period,Status','ERP','Y','GL Budget Balances — same journal endpoint as GL Balances');
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
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Award Headers','/fscmRestApi/resources/11.13.18.05/gmsGrants','AwardNumber={KEY}','AWARD_NUMBER','GrantId,AwardNumber,AwardName,AwardStatusCode,SponsorName,StartDate','Grant ID,Award #,Name,Status,Sponsor,Start','ERP','Y','Grants award headers');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Billing Events','/fscmRestApi/resources/11.13.18.05/projectBillingEvents','BillingEventId={KEY}','FUSION_BILLING_EVENT_ID','BillingEventId,EventNumber,ProjectNumber,EventDate,Amount,CurrencyCode,EventStatus','Event ID,Number,Project,Date,Amount,Currency,Status','ERP','Y','Project billing events');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Req Headers','/fscmRestApi/resources/11.13.18.05/purchaseRequisitions','Requisition={KEY}','REQUISITION_NUMBER','RequisitionHeaderId,RequisitionNumber,PreparerName,Status,TotalAmount,CreationDate','Req ID,Number,Preparer,Status,Amount,Created','ERP','Y',NULL);
exception when dup_val_on_index then null;
end;
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
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Accounts','/fscmRestApi/resources/11.13.18.05/hubOrganizations','PartyName={KEY}','ACCOUNT_NAME','PartyId,PartyName,PartyNumber,Status,CreationDate','Party ID,Name,Number,Status,Created','ERP','Y','Customer accounts — queries parent org by account name');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('AR Lines','/fscmRestApi/resources/11.13.18.05/receivablesInvoices','TransactionNumber={KEY}','TRX_NUMBER','CustomerTransactionId,TransactionNumber,TransactionDate,BillToCustomerName,TransactionAmount,TransactionStatus','Trx ID,Number,Date,Customer,Amount,Status','ERP','Y','AR invoice lines — queries parent transaction by TRX_NUMBER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Tasks','/fscmRestApi/resources/11.13.18.05/projects','ProjectNumber={KEY}','PROJECT_NUMBER','ProjectId,ProjectNumber,ProjectName,ProjectStatusCode,OrganizationName,StartDate','Project ID,Number,Name,Status,Org,Start','ERP','Y','Verifies parent project (tasks are child resources)');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Asset Headers','/fscmRestApi/resources/11.13.18.05/fixedAssets','AssetNumber={KEY}','ASSET_NUMBER','AssetId,AssetNumber,Description,AssetType,CurrentCost,DatePlacedInService','Asset ID,Number,Description,Type,Cost,In-Service Date','ERP','Y','Asset headers — same config as Assets CEMLI entry');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Expenditure Items','/fscmRestApi/resources/11.13.18.05/projectExpenditureItems','OrigTransactionReference={KEY}','ORIG_TRANSACTION_REFERENCE','ExpenditureItemId,ProjectNumber,TaskNumber,ExpenditureType,ItemDate,Quantity,Amount','Item ID,Project,Task,Type,Date,Qty,Amount','ERP','Y','Expenditure items — filters by OrigTransactionReference');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Salary Bases','/hcmRestApi/resources/11.13.18.05/salaryBases','SalaryBasisName={KEY}','SALARY_BASIS_NAME','SalaryBasisId,SalaryBasisName,SalaryBasisCode,ElementName,InputValueName','Basis ID,Name,Code,Element,Input Value','HCM','Y','Same as SalaryBases CEMLI entry — SUB_OBJECT display name');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Talent Profiles','/hcmRestApi/resources/11.13.18.05/talentProfiles','PersonNumber={KEY}','PERSON_NUMBER','ProfileId,ProfileCode,PersonNumber,ProfileTypeCode,ProfileStatusCode,ProfileUsageCode','Profile ID,Code,Person,Type,Status,Usage','HCM','Y','Same as TalentProfiles CEMLI entry — SUB_OBJECT display name');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Performance Evaluations','/hcmRestApi/resources/11.13.18.05/goalPlans','PersonNumber={KEY}','PERSON_NUMBER','GoalPlanId,GoalPlanName,GoalPlanTypeCode,PersonNumber,StartDate,EndDate','Plan ID,Name,Type,Person,Start,End','HCM','Y','Same as PerfEvaluations CEMLI entry — SUB_OBJECT display name');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_REST_LOOKUP_TBL" ("OBJECT_TYPE","REST_ENDPOINT","QUERY_FILTER","KEY_COLUMN","DISPLAY_FIELDS","DISPLAY_LABELS","AUTH_TYPE","ENABLED","NOTES") values ('Work Schedules','/hcmRestApi/resources/11.13.18.05/workPatterns','PersonNumber={KEY}','PERSON_NUMBER','WorkPatternAssignmentId,PersonNumber,AssignmentNumber,WorkPatternType,DateFrom,RepeatCycle','Pattern ID,Person,Assignment,Type,From Date,Repeat','HCM','Y','Same as WorkSchedules CEMLI entry — SUB_OBJECT display name');
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
commit;
