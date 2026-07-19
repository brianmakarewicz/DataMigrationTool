-- Seed data for DMT_CONFIG_TBL (37 rows, snapshot 2026-07-03; +2 no-hardcoded-IDs keys 2026-07-12)
-- Idempotent: duplicate-key inserts are skipped.
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('AP_IMPORT_JOB_NAME','/oracle/apps/ess/financials/payables/invoices/payablesImport,PayablesImportEss',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
-- No-hardcoded-IDs standard (design section 7): the Expenditures business unit
-- is named here; its instance-specific id is resolved from the BU lookup at run time.
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('EXPENDITURE_BU_NAME','US1 Business Unit','Business unit name for the Expenditures import; id resolved via BU_NAME_TO_BU_ID lookup.',to_date('2026-07-12 00:00:00','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('WORKER_DEFAULT_BU_NAME','US1 Business Unit','Business unit short code written to the Assignment HDL line for new-hire workers; named config, not a code literal (design section 7).',to_date('2026-07-15 00:00:00','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
-- No-hardcoded-IDs standard (design section 7): the asset book code is named
-- config so other book types load without a code change.
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('ASSET_BOOK_TYPE','US CORP','Asset book type code for the Assets PostMassAdditions ESS job.',to_date('2026-07-12 00:00:00','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('AP_INTERFACE_DETAILS_ID','1',NULL,to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('AP_UCM_ACCOUNT','fin/payables/import',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('AR_IMPORT_JOB_NAME','/oracle/apps/ess/financials/receivables/transactions/autoInvoices,AutoInvoiceImportEss',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('AR_INTERFACE_DETAILS_ID','2',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('AR_UCM_ACCOUNT','fin/receivables/import',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('BIP_PASSWORD','***MASKED-SET-ME***',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('BIP_USERNAME','fin_impl',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('CUST_IMPORT_JOB_NAME','/oracle/apps/ess/cdm/foundation/bulkImport,CDMAutoBulkImportJob',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('CUST_INTERFACE_DETAILS_ID','4',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('CUST_UCM_ACCOUNT','fin/receivables/import',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('FUSION_PASSWORD','***MASKED-SET-ME***',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('FUSION_URL','https://fa-esew-dev28-saasfademo1.ds-fa.oraclepdemos.com/','Active Fusion instance base URL',to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('FUSION_USERNAME','fin_impl',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('HCM_PASSWORD','***MASKED-SET-ME***',NULL,to_date('2026-04-04 13:51:18','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('HCM_USERNAME','hcm_impl',NULL,to_date('2026-04-04 13:51:18','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('PO_DEFAULT_BUYER_ID','300000047340498',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('PO_DEFAULT_BUYER_NAME','Roth, Calvin',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('PO_DEFAULT_PRC_BU_ID','300000046987012',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('PO_DEFAULT_REQ_BU_ID','300000046987012',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('PO_DEFAULT_REQ_BU_NAME','US1 Business Unit',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_ADDR_IMPORT_JOB_NAME','/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierAddresses',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_ADDR_INTERFACE_DETAILS_ID','56',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_CONT_IMPORT_JOB_NAME','/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierContacts',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_CONT_INTERFACE_DETAILS_ID','26',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_IMPORT_JOB_NAME','/oracle/apps/ess/prc/poz/supplierImport,ImportSuppliers',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_INTERFACE_DETAILS_ID','24',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_RESULTS_BIP_PATH','/Custom/DMT/SUP_RESULTS_RPT.xdo',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_SITE_ASSN_IMPORT_JOB_NAME','/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierSiteAssignments',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_SITE_ASSN_INTERFACE_DETAILS_ID','27',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_SITE_IMPORT_JOB_NAME','/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierSites',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_SITE_INTERFACE_DETAILS_ID','25',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('USE_PREFIX','Y',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('WALLET_DIR','***MASKED-SET-ME***',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('WALLET_PASSWORD','***MASKED-SET-ME***',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
commit;

-- Decided admin config keys (DMT_DESIGN.html sections 2, 5, 6) — added 2026-07-07
-- after the blind infrastructure-tranche review found them missing from the seed.
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('ESS_POLL_TIMEOUT_MINUTES','30','Max minutes to poll an ESS job before marking GENERATED rows FAILED [LOAD_ERROR]; reconciliation still runs after (design section 2)',sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('BIP_CHUNK_SIZE','5000','Rows per BIP reconciliation fetch chunk (Contract v1, design section 5)',sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('RETENTION_DAYS','90','Days to retain CSV CLOBs / ZIP BLOBs / activity-log entries before the purge job clears them (design section 6)',sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('VALIDATE_UPSTREAM_DEPS','N','Master switch for cross-object upstream dependency PRE-validation (the "parent must be LOADED" checks in the object validators). N (default) = skip them: references resolve through DMT_XREF_PKG (most-recent LOADED value, or raw source if the parent is pre-existing / not migrated) and a genuinely-missing parent still fails at Fusion with a reportable error. Y = enforce the checks. Per design: the tool''s job is to move data and account for every outcome, not to pre-validate.',sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
