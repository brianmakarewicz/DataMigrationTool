-- Seed data for DMT_CONFIG_TBL (35 rows, snapshot 2026-07-03)
-- Idempotent: duplicate-key inserts are skipped.
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('AP_IMPORT_JOB_NAME','/oracle/apps/ess/financials/payables/invoices/payablesImport,PayablesImportEss',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
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
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('CUST_IMPORT_JOB_NAME','/oracle/apps/ess/cdm/foundation/bulkImport,BulkImportJob',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
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
