-- Seed data for DMT_ERP_INTERFACE_OPTIONS_TBL (180 rows, snapshot 2026-07-03)
-- Idempotent: duplicate-key inserts are skipped.
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('1','FIN','payableInvoiceBatch','fin/payables/import',NULL,'/oracle/apps/ess/financials/payables/invoices/transactions;APXIIMPT',NULL,'Y','SQLLOADER',NULL,'APInvoices','1','APXIIMPT_BIP',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('10','FIN','fixedAsset','fin/assets/import',NULL,'/oracle/apps/ess/financials/assets/retirements/massRetirements;PostMassRetirements','/oracle/apps/ess/financials/assets/additions;PrepareMassAdditions,JAVAAPI_ASYNC-oracle.apps.financials.assets.shared.EssSharedUtility.refreshInfotileCountsAfterPurge','Y','SQLLOADER',NULL,NULL,'10',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('100','FIN','Asset Transaction','fin/assets/export',NULL,'/oracle/apps/ess/financials/commonModules/shared/common/outbound;AssetRetirementsExtract',NULL,'N','BIPREPORT',NULL,NULL,'100',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('101','FIN','Asset Transaction','fin/assets/export',NULL,'/oracle/apps/ess/financials/commonModules/shared/common/outbound;AssetTransactionsHistoryExtract',NULL,'N','BIPREPORT',NULL,NULL,'101',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('102','FIN','Asset Transaction','fin/assets/export',NULL,'/oracle/apps/ess/financials/commonModules/shared/common/outbound;AssetTransfersExtract',NULL,'N','BIPREPORT',NULL,NULL,'102',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('103','FIN','Journals','fin/generalLedger/export',NULL,'/oracle/apps/ess/financials/commonModules/shared/common/outbound;JournalsExtract',NULL,'N','BIPREPORT',NULL,NULL,'103',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('104','FIN','Trail Balance','fin/generalLedger/export',NULL,'/oracle/apps/ess/financials/commonModules/shared/common/outbound;TrialBalanceExtract',NULL,'N','BIPREPORT',NULL,NULL,'104',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('105','FIN','Financials Tax','fin/tax/export',NULL,'/oracle/apps/ess/financials/commonModules/shared/common/outbound;FinancialTaxExtract',NULL,'N','BIPREPORT',NULL,NULL,'105',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('106','SCM','Inventory Balance','scm/inventoryBalance/import',NULL,'/oracle/apps/ess/scm/inventory/materialAvailability/onhandBalances;InvOnhandBalProcessJob',NULL,'Y','SQLLOADER',NULL,NULL,'106',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('107','SCM','Maintenance Asset','scm/maintenanceAsset/import','Import Maintenance Assets','/oracle/apps/ess/scm/maintenanceManagement/assets/import;ImportMaintenanceAssetsJob',NULL,'Y','SQLLOADER',NULL,NULL,'107',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('108','SCM','Customer Asset','scm/customerAsset/import','Import Customer Assets','/oracle/apps/ess/scm/installedBase/customerAssets/import;ImportCustomerAssetsJob',NULL,'Y','SQLLOADER',NULL,NULL,'108',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('109','PRJ','Project Rate Schedule','prj/projectSetup/import',NULL,'/oracle/apps/ess/projects/foundation/setup/rates;ImportRateSchedulesJob',NULL,'Y','SQLLOADER',NULL,NULL,'109',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('11','FIN','fixedAsset','fin/assets/import',NULL,'/oracle/apps/ess/financials/assets/tracking/massTransfers;PostMassTransfers','/oracle/apps/ess/financials/assets/additions;PrepareMassAdditions,JAVAAPI_ASYNC-oracle.apps.financials.assets.shared.EssSharedUtility.refreshInfotileCountsAfterPurge','Y','SQLLOADER',NULL,NULL,'11',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('110','SCM','Maintenance Work Order','scm/maintenanceWorkOrder/import','Import Maintenance Work Orders','/oracle/apps/ess/scm/maintenanceManagement/workOrders/import;ImportMaintenanceWorkOrdersJob',NULL,'Y','SQLLOADER',NULL,NULL,'110',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('111','FIN','Fiscal Document','fin/receivables/import',NULL,'/oracle/apps/ess/financials/genericLocalizations/transaction/fiscal;ImportTaxAuthorityReturn',NULL,'Y','SQLLOADER',NULL,NULL,'111',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('112','FIN','fixedAsset','fin/assets/import',NULL,'/oracle/apps/ess/financials/assets/tracking/leases;ImportAssetLeases','/oracle/apps/ess/financials/assets/additions;PrepareMassAdditions','Y','SQLLOADER',NULL,NULL,'112',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('113','FIN','creditManagement','fin/receivables/import',NULL,'/oracle/apps/ess/financials/receivables/creditManagement;ARCMICD','/oracle/apps/ess/financials/receivables/creditManagement;ARCMICD','Y','SQLLOADER',NULL,NULL,'113',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('114','FIN','fixedAsset','fin/assets/import',NULL,'/oracle/apps/ess/financials/assets/tracking/massTransfers;PostMassUpdateDescDetails','/oracle/apps/ess/financials/assets/additions;PrepareMassAdditions','Y','SQLLOADER',NULL,NULL,'114',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('115','PRC','Supplier Attachment','prc/supplier/import',NULL,'/oracle/apps/ess/prc/poz/supplierImport;ImportSupplierAttachments',NULL,'Y','SQLLOADER',NULL,NULL,'115',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('116','FIN','Tax Line','fin/tax/import',NULL,'/oracle/apps/ess/financials/tax/report;PopulatePartnerLines',NULL,'Y','SQLLOADER',NULL,NULL,'116',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('117','FIN','bankStatement','fin/cashManagement/import',NULL,'/oracle/apps/ess/financials/cashManagement/bankStatements;ImportBankStatements','/oracle/apps/ess/financials/cashManagement/bankStatements;ImportBankStatements','Y','SQLLOADER',NULL,NULL,'117',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('118','FIN','CoaMappings','fin/generalLedger/import',NULL,'/oracle/apps/ess/financials/generalLedger/programs/common;ImportCoaMappingRollupRules',NULL,'Y','SQLLOADER',NULL,NULL,'118',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('119','SCM','Change Order','scm/changeOrder/import',NULL,'/oracle/apps/ess/scm/productCatalogManagement/changeObjects;ChangeOrderImportJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'119',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('12','FIN','fixedAsset','fin/assets/import',NULL,'/oracle/apps/ess/financials/assets/adjustments/workArea;PostMassFinTransactions','/oracle/apps/ess/financials/assets/additions;PrepareMassAdditions,JAVAAPI_ASYNC-oracle.apps.financials.assets.shared.EssSharedUtility.refreshInfotileCountsAfterPurge','Y','SQLLOADER',NULL,NULL,'12',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('120','FIN','payableInvoiceBatch','fin/payables/import',NULL,'/oracle/apps/ess/financials/payables/invoices/transactions;APXPRIMPT',NULL,'Y','SQLLOADER',NULL,NULL,'120',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('121','PRJ','Grants Sponsor','prj/grantsManagement/import',NULL,'/oracle/apps/ess/projects/grantsManagement/setup;ImportSponsorsJob',NULL,'Y','SQLLOADER',NULL,NULL,'121',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('122','PRJ','Grants Keyword','prj/grantsManagement/import',NULL,'/oracle/apps/ess/projects/grantsManagement/setup;ImportKeywordsJob',NULL,'Y','SQLLOADER',NULL,NULL,'122',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('123','PRJ','Grants Personnel','prj/grantsManagement/import',NULL,'/oracle/apps/ess/projects/grantsManagement/setup;ImportGrantsPersonnelJob',NULL,'Y','SQLLOADER',NULL,NULL,'123',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('124','PRJ','Grants Funding Source','prj/grantsManagement/import',NULL,'/oracle/apps/ess/projects/grantsManagement/setup;ImportInternalFundingSourcesJob',NULL,'Y','SQLLOADER',NULL,NULL,'124',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('125','SCM','Collaboration Order Forecast','scm/collaborationOrderForecast/import',NULL,'/oracle/apps/ess/scm/supplyCollaboration/collaboration;VcsSupplyCollaborationOrderForecastImportJob','/oracle/apps/ess/scm/supplyCollaboration/collaboration;VcsSupplyCollaborationOrderForecastImportJob','Y','SQLLOADER',NULL,NULL,'125',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('126','SCM','Product Genealogy','scm/productGenealogy/import','Import Product Genealogy','/oracle/apps/ess/scm/assetTracking/productGenealogy/import;ImportProductGenealogyJob',NULL,'Y','SQLLOADER',NULL,NULL,'126',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('127','SCM','Source Sales Order','scm/sourceSalesOrder/import',NULL,'/oracle/apps/ess/scm/fom/importOrders/hvop;HighVolumeImportSalesOrdersJob',NULL,'Y','SQLLOADER',NULL,NULL,'127',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('128','FIN','Tax Line','fin/tax/import',NULL,'/oracle/apps/ess/financials/apacLocalizations/financialReports;IndiaGSTInboundReport',NULL,'Y','SQLLOADER',NULL,NULL,'128',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('129','FIN','Fiscal Document','fin/tax/import',NULL,'/oracle/apps/ess/financials/genericLocalizations/transaction/fiscal;ImportFiscalSalesDocuments',NULL,'Y','SQLLOADER',NULL,NULL,'129',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('13','FIN','fixedAsset','fin/assets/import',NULL,'/oracle/apps/ess/financials/assets/depreciation/production;UploadProduction','/oracle/apps/ess/financials/assets/additions;PrepareMassAdditions','Y','SQLLOADER',NULL,NULL,'13',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('130','FIN','TaxPointDateAdjustment','fin/tax/import',NULL,'/oracle/apps/ess/financials/genericLocalizations/financialReports;ProcessTPDAdjustment',NULL,'Y','SQLLOADER',NULL,NULL,'130',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('131','FIN','Subledger Mapping Set Value','fin/fusionAccountingHub/import',NULL,'/oracle/apps/ess/financials/subledgerAccounting/shared;XLASETUPIMPORT','/oracle/apps/ess/financials/subledgerAccounting/shared;XLASETUPIMPORT','Y','SQLLOADER',NULL,NULL,'131',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('132','FIN','BeTransactionImport','fin/federal/import',NULL,'/oracle/apps/ess/financials/federal/budgetExecution/integration/beImport;ImportBeTransactions',NULL,'Y','SQLLOADER',NULL,NULL,'132',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('133','SCM','Work Definition','scm/workDefinition/import',NULL,'/oracle/apps/ess/scm/commonWorkSetup/workDefinitions/massImport;ImportWorkDefinitionJob',NULL,'Y','SQLLOADER',NULL,NULL,'133',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('134','FIN','General Ledger Account Combination','fin/generalLedger/import',NULL,'/oracle/apps/ess/financials/generalLedger/programs/common;GlImportBulkAccountCombination',NULL,'Y','SQLLOADER',NULL,NULL,'134',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('135','SCM','Msc Common','scm/planningDataLoader/import',NULL,'/oracle/apps/ess/scm/advancedPlanning/collection/configuration;CSVController','/oracle/apps/ess/scm/advancedPlanning/collection/configuration;CSVController','Y','SQLLOADER',NULL,NULL,'135',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('136','PRJ','Project Resource Breakdown Structure','prj/projectSetup/import',NULL,'/oracle/apps/ess/projects/foundation/resources;ImportPrbsJob',NULL,'Y','SQLLOADER',NULL,NULL,'136',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('137','SCM','Catalogs','scm/item/import',NULL,'/oracle/apps/ess/scm/productModel/items;CatalogImportJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'137',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('138','SCM','Revenue Lines Import','scm/cstCogs/import',NULL,'/oracle/apps/ess/scm/costing/costAccounting/runControl;CstCostProcess',NULL,'Y','SQLLOADER',NULL,NULL,'138',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('139','PRJ','projectAssets','prj/projectCosting/import',NULL,'/oracle/apps/ess/projects/costing/capitalization;ImportAssetProcessingJob',NULL,'Y','SQLLOADER',NULL,NULL,'139',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('14','FIN','intercompanyTransaction','fin/intercompany/import',NULL,'/oracle/apps/ess/financials/commonModules/intercompanyTransactions;TransactionsImport',NULL,'Y','SQLLOADER',NULL,NULL,'14',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('140','SCM','Maintenance Work Definition','scm/maintenanceWorkDefinition/import','Import Maintenance Work Definitions','oracle/apps/ess/scm/maintenanceManagement/workDefinitions/import;ImportMaintenanceWorkDefinitionsJob',NULL,'Y','SQLLOADER',NULL,NULL,'140',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('141','PSC','Address Parcel Owner','psc/commoncomponents/import',NULL,'/oracle/apps/ess/psc/commonComponents/addressParcelOwner;ImportAddressParcelOwner','/oracle/apps/ess/psc/commonComponents/addressParcelOwner;ImportAddressParcelOwner','Y','SQLLOADER',NULL,NULL,'141',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('142','SCM','Orchestration Order','scm/orderFulfillmentResponse/import',NULL,'/oracle/apps/ess/scm/doo/taskLayer/common;ImportOrderFulfillmentResponseJob',NULL,'Y','SQLLOADER',NULL,NULL,'142',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('143','FIN','Netting Agreement','fin/payables/import',NULL,'/oracle/apps/ess/financials/europeanLocalizations/netting;ImportNettingAgreements',NULL,'Y','SQLLOADER',NULL,NULL,'143',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('144','PSC','Agency Staff','psc/commoncomponents/import',NULL,'/oracle/apps/ess/psc/commonComponents/employeeProfiles;ImportAgencyStaff','/oracle/apps/ess/psc/commonComponents/employeeProfiles;ImportAgencyStaff','Y','SQLLOADER',NULL,NULL,'144',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('145','HED','Admissions Application','hed/admissions/import',NULL,'/oracle/apps/ess/hed/campusCommunity/dataLoader/common;HedHeyImportHigherEducationDataEss','/oracle/apps/ess/hed/campusCommunity/dataLoader/common;HedHeyImportHigherEducationDataEss','Y','SQLLOADER',NULL,NULL,'145',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('146','SCM','Vendor-Managed Inventory Relationship','scm/vmiRelationship/import',NULL,'/oracle/apps/ess/scm/supplyCollaboration/collaboration;VcsVMIRelationshipImportJob','/oracle/apps/ess/scm/supplyCollaboration/collaboration;VcsVMIRelationshipImportJob','Y','SQLLOADER',NULL,NULL,'146',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('147','SCM','Installed Base Asset','scm/installedBaseAsset/import','Import Installed Base Assets','oracle/apps/ess/scm/assetTracking/assetCore/import;ImportInstalledBaseAssetsJob',NULL,'Y','SQLLOADER',NULL,NULL,'147',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('148','SCM','Discount List','scm/discountLists/import',NULL,'/oracle/apps/ess/scm/pricing/pricingAdmin/discountLists;QpDiscountListsImportJob',NULL,'Y','SQLLOADER',NULL,NULL,'148',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('149','PRJ','Project Labor Distributions','prj/projectCosting/import',NULL,'/oracle/apps/ess/projects/costing/laborDistributions;ImportPayrollCostsJob',NULL,'Y','SQLLOADER',NULL,NULL,'149',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('15','FIN','journal','fin/generalLedger/import',NULL,'/oracle/apps/ess/financials/generalLedger/programs/common;JournalImportLauncher',NULL,'Y','SQLLOADER',NULL,'GLBalances','15',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('150','SCM','Price List','scm/priceLists/import',NULL,'/oracle/apps/ess/scm/pricing/pricingAdmin/priceLists;QpPriceListsNewImportJob',NULL,'Y','SQLLOADER',NULL,NULL,'150',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('151','PRJ','Project Setup Labor Distributions','prj/projectCosting/import',NULL,'/oracle/apps/ess/projects/costing/setup/laborDistributions;ImportAssignmentLaborSchedulesJob',NULL,'Y','SQLLOADER',NULL,NULL,'151',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('152','FIN','Withholding Tax Registrations and Exemptions','fin/tax/import',NULL,'/oracle/apps/ess/financials/europeanLocalizations/financialReporting;JeIsraelShaamProcessFile',NULL,'Y','SQLLOADER',NULL,NULL,'152',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('153','FIN','Unified Budget Import','fin/budgetaryControl/import',NULL,'/oracle/apps/ess/financials/commitmentControl/integration/budgetImport;UnifiedBudgetImport',NULL,'Y','SQLLOADER',NULL,NULL,'153',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('154','PRJ','Project Progress','prj/projectControl/import',NULL,'/oracle/apps/ess/projects/control/progress;ImportProjectProgressJob',NULL,'Y','SQLLOADER',NULL,NULL,'154',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('155','SCM','Recall Notice','scm/RecallNotice/import',NULL,'oracle/apps/ess/scm/sch/recallManagement;ImportRecallNoticeJob',NULL,'N','SQLLOADER',NULL,NULL,'155',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('156','FIN','General Ledger Account Combination','fin/generalLedger/import',NULL,'/oracle/apps/ess/financials/generalLedger/programs/common;ImportChartofAccountsValidationRules',NULL,'Y','SQLLOADER',NULL,NULL,'156',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('157','PRJ','Project Assets','prj/projectCosting/import',NULL,'/oracle/apps/ess/projects/costing/capitalization;ImportUnassignedAssetLinesJob',NULL,'Y','SQLLOADER',NULL,NULL,'157',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('158','PRJ','exceptions','prj/projectFoundation/import',NULL,'oracle/apps/ess/projects/performanceReporting/trackAndManage;PjsImportProjectKPIJobDef','oracle/apps/ess/projects/performanceReporting/trackAndManage;PjsImportProjectKPIJobDef','Y','SQLLOADER',NULL,NULL,'158',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('159','PRC','Supplier Negotiation','prc/supplierNegotiation/import',NULL,'/oracle/apps/ess/prc/pon/negotiationImport;ImportNegotiationLinesSuppliersJob',NULL,'Y','SQLLOADER',NULL,NULL,'159',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('16','FIN','chartOfAccounts','fin/generalLedger/import',NULL,'/oracle/apps/ess/financials/generalLedger/programs/masterData;LoadSegValAndHierData','/oracle/apps/ess/financials/generalLedger/programs/masterData;ProcessInterfaceData','Y','SQLLOADER',NULL,NULL,'16',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('160','FIN','Lease Contract','fin/leaseAccounting/import',NULL,'/oracle/apps/ess/financials/fla/finFla/finLeaseShared;GenerateSchedules',NULL,'Y','SQLLOADER',NULL,NULL,'160',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('161','SCM','External Purchase Prices','prc/externalpurchaseprices/import',NULL,'oracle/apps/ess/scm/sch/externalPurchasePrice;MassImportExternalPurchasePriceJob',NULL,'Y','SQLLOADER',NULL,NULL,'161',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('162','PRC','Classification','prc/classification/import',NULL,'/oracle/apps/ess/prc/poi/classification;DatasetImport','/oracle/apps/ess/prc/poi/classification;DatasetImport','Y','SQLLOADER',NULL,NULL,'162',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('163','SCM','Meter Reading','scm/meterReading/import','Import Meter Readings','oracle/apps/ess/scm/assetTracking/meterReadings/import;ImportMeterReadingsJob',NULL,'Y','SQLLOADER',NULL,NULL,'163',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('164','FIN','Conversion Rate','fin/generalLedger/import',NULL,'/oracle/apps/ess/financials/generalLedger/programs/common;AssignHistoricalRates',NULL,'Y','SQLLOADER',NULL,NULL,'164',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('165','FIN','Fiscal Document','fin/tax/import',NULL,'/oracle/apps/ess/financials/genericLocalizations/transaction/fiscal;PrintFiscalDocuments',NULL,'Y','SQLLOADER',NULL,NULL,'165',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('166','FIN','bankStatement','fin/cashManagement/import',NULL,'/oracle/apps/ess/financials/cashManagement/bankStatements;AutoReconciliation','/oracle/apps/ess/financials/cashManagement/bankStatements;AutoReconciliation','Y','SQLLOADER',NULL,NULL,'166',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('167','FIN','fedSAMTradingPartnerDetails','fin/federal/import',NULL,'/oracle/apps/ess/financials/federal/payments/transactions/samRegistrations;ImportSAMTradingPartnerDetails',NULL,'Y','SQLLOADER',NULL,NULL,'167',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('168','SCM','Msc Common','scm/planningDataLoader/import',NULL,'/oracle/apps/ess/scm/advancedPlanning/collection/configuration;CSVController','/oracle/apps/ess/scm/advancedPlanning/collection/configuration;CSVController','Y','SQLLOADER',NULL,NULL,'168',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('169','SCM','Maintenance Program','scm/maintenanceProgram/import','Import Maintenance Programs','oracle/apps/ess/scm/maintenanceManagement/maintProgram/import;ImportMaintenanceProgramsJob',NULL,'Y','SQLLOADER',NULL,NULL,'169',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('17','FIN','generalLedgerBudgetBalance','fin/budgetBalance/import',NULL,'/oracle/apps/ess/financials/generalLedger/ledgers/ledgerDefinitions;ValidateAndLoadBudgets',NULL,'Y','SQLLOADER',NULL,'GLBudgets','17',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('170','FIN','Lease Properties','fin/leaseAccounting/import',NULL,'/oracle/apps/ess/financials/fla/finFla/finLeaseShared;GenerateRevenue',NULL,'Y','SQLLOADER',NULL,NULL,'170',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('171','SCM','Cost List','scm/costLists/import',NULL,'oracle/apps/ess/scm/pricing/pricingAdmin/costLists;QpCostListsImportJob',NULL,'Y','SQLLOADER',NULL,NULL,'171',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('172','SCM','Interfaced Pick Transactions','scm/interfacedPickTransactions/import',NULL,'/oracle/apps/ess/scm/inventory/picking/pickConfirm;InvPickTxnsProcessJob',NULL,'Y','SQLLOADER',NULL,NULL,'172',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('173','SCM','Supplier Warranty Coverage','scm/supplierWarrantyCoverage/import','Import Supplier Warranty Coverages','oracle/apps/ess/scm/assetTracking/supplierWarranty/import;ImportWarrantyCoverageJob',NULL,'Y','SQLLOADER',NULL,NULL,'173',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('174','FIN','fixedAsset','fin/assets/import',NULL,'/oracle/apps/ess/financials/assets/shared;FARCUPG','/oracle/apps/ess/financials/assets/additions;PrepareMassAdditions','Y','SQLLOADER',NULL,NULL,'174',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('175','PRC','Sustainability Activity','prc/sustainability/import',NULL,'/oracle/apps/ess/prc/sus/activities;ImportActivities',NULL,'Y','SQLLOADER',NULL,NULL,'175',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('176','FIN','fedIPACTransactionData','fin/federal/import',NULL,'/oracle/apps/ess/financials/federal/payments;ImportIPACTransactionInformation',NULL,'Y','SQLLOADER',NULL,NULL,'176',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('177','SCM','Attachments','scm/common/import',NULL,'/oracle/apps/ess/scm/rcs/integrations;AttachmentsImport','/oracle/apps/ess/scm/rcs/integrations;AttachmentsImport','Y','SQLLOADER',NULL,NULL,'177',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('178','PRJ','Project Contract Bill Transactions','prj/projectBilling/import',NULL,'/oracle/apps/ess/projects/billing/transactions;ImportProjectContractBillTransactionsJob',NULL,'Y','SQLLOADER',NULL,NULL,'178',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('18','FIN','bankAccount','fin/payables/import',NULL,'/oracle/apps/ess/financials/payments/fundsDisbursement/payments;ImportSuppBankAccounts',NULL,'Y','SQLLOADER',NULL,NULL,'18',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('180','SCM','Reference Organization Items','scm/item/import',NULL,'/oracle/apps/ess/scm/productModel/items;ItemImportRefOrgBulkImportJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'180',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('181','PRC','Blanket Purchase Agreement','prc/blanketPurchaseAgreement/import',NULL,'/oracle/apps/ess/prc/po/pdoi;ImportBPAJob',NULL,'Y','SQLLOADER',NULL,'BlanketPOs','23',NULL,'calvin.roth','***MASKED-SET-ME***');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('182','PRC','Contract Purchase Agreement','prc/contractPurchaseAgreement/import',NULL,'/oracle/apps/ess/prc/po/pdoi;ImportCPAJob',NULL,'Y','SQLLOADER',NULL,'Contracts','22',NULL,'calvin.roth','***MASKED-SET-ME***');
exception when dup_val_on_index then null;
end;
/
begin
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('19','FIN','taxRate','fin/tax/import',NULL,'/oracle/apps/ess/financials/tax/report;LaunchTaxConfigContentUpload',NULL,'Y','SQLLOADER',NULL,NULL,'19',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('2','FIN','receivablesInvoice','fin/receivables/import',NULL,'/oracle/apps/ess/financials/receivables/transactions/autoInvoices;AutoInvoiceImportEss',NULL,'Y','SQLLOADER',NULL,'ARInvoices','2',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('20','PRJ','projectUnprocessedExpenditureItem','prj/projectCosting/import',NULL,'/oracle/apps/ess/projects/costing/transactions/onestop;ImportProcessParallelEssJob',NULL,'Y','SQLLOADER',NULL,'Expenditures','20',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('21','PRC','Purchase Order','prc/purchaseOrder/import',NULL,'/oracle/apps/ess/prc/po/pdoi;ImportSPOJob',NULL,'Y','SQLLOADER',NULL,'PurchaseOrders','21',NULL,'calvin.roth','***MASKED-SET-ME***');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('22','PRC','Contract Purchase Agreement','prc/contractPurchaseAgreement/import',NULL,'/oracle/apps/ess/prc/po/pdoi;ImportCPAJob',NULL,'Y','SQLLOADER',NULL,NULL,'22',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('23','PRC','Blanket Purchase Agreement','prc/blanketPurchaseAgreement/import',NULL,'/oracle/apps/ess/prc/po/pdoi;ImportBPAJob',NULL,'Y','SQLLOADER',NULL,NULL,'23',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('24','PRC','Supplier','prc/supplier/import',NULL,'/oracle/apps/ess/prc/poz/supplierImport;ImportSuppliers',NULL,'Y','SQLLOADER',NULL,'Suppliers','24',NULL,'calvin.roth','***MASKED-SET-ME***');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('25','PRC','Supplier Site','prc/supplier/import',NULL,'/oracle/apps/ess/prc/poz/supplierImport;ImportSupplierSites',NULL,'Y','SQLLOADER',NULL,'SupplierSites','25',NULL,'calvin.roth','***MASKED-SET-ME***');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('26','PRC','Supplier Contact','prc/supplier/import',NULL,'/oracle/apps/ess/prc/poz/supplierImport;ImportSupplierContacts',NULL,'Y','SQLLOADER',NULL,'SupplierContacts','26',NULL,'calvin.roth','***MASKED-SET-ME***');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('27','PRC','Supplier Site Assignment','prc/supplier/import',NULL,'/oracle/apps/ess/prc/poz/supplierImport;ImportSupplierSiteAssignments',NULL,'Y','SQLLOADER',NULL,'SupplierSiteAssignments','27',NULL,'calvin.roth','***MASKED-SET-ME***');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('28','PRC','Requisition','prc/requisition/import',NULL,'/oracle/apps/ess/prc/por/createReq/reqImport;RequisitionImportJob',NULL,'Y','SQLLOADER',NULL,'Requisitions','28',NULL,'calvin.roth','***MASKED-SET-ME***');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('29','SCM','item','scm/item/import',NULL,'/oracle/apps/ess/scm/productModel/items;ItemImportJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'29',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('3','FIN','receivablesLockbox','fin/receivables/import',NULL,'/oracle/apps/ess/financials/receivables/receipts/lockboxes;ProcessLockboxesMasterEss',NULL,'Y','SQLLOADER',NULL,NULL,'3',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('30','SCM','Shipment','scm/shipmentRequest/import',NULL,'/oracle/apps/ess/scm/shipping/shipConfirm/deliveries;WshReceiveShipmentRequestsSRSJob',NULL,'Y','SQLLOADER',NULL,NULL,'30',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('300',NULL,NULL,'scm/item/import',NULL,'/oracle/apps/ess/scm/productModel/items;ItemImportJobDef',NULL,NULL,'SQLLOADER',NULL,'Items','29',NULL,'SCM_IMPL','***MASKED-SET-ME***');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('301',NULL,NULL,'scm/item/import',NULL,'/oracle/apps/ess/scm/productModel/items;ItemImportJobDef',NULL,NULL,'SQLLOADER',NULL,'ItemCategories','29',NULL,'SCM_IMPL','***MASKED-SET-ME***');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('31','SCM','Inventory Reservation','scm/inventoryReservation/import',NULL,'/oracle/apps/ess/scm/inventory/materialTransactions/txnManager;ReservationsMgr',NULL,'Y','SQLLOADER',NULL,NULL,'31',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('32','SCM','Receiving Receipt','scm/receivingReceipt/import',NULL,'/oracle/apps/ess/scm/receiving/receiptsInterface/transactions/processor;RcvTxnProcessorJob',NULL,'Y','SQLLOADER',NULL,NULL,'32',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('33','SCM','Inventory Transaction','scm/inventoryTransaction/import',NULL,'/oracle/apps/ess/scm/inventory/materialTransactions/txnManager;SingleTMEssJob',NULL,'Y','SQLLOADER',NULL,'MiscReceipts','33',NULL,'scm_impl','***MASKED-SET-ME***');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('34','SCM','Standard Cost','scm/standardCost/import',NULL,'/oracle/apps/ess/scm/costing/standardCosts/stdCostInterface;cstStdCostInterfaceJob',NULL,'Y','SQLLOADER',NULL,NULL,'34',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('35','SCM','Cycle Count','scm/cycleCount/import',NULL,'/oracle/apps/ess/scm/inventory/counting/desktopCycleCountInterface;InvCcIntrfRecordsProcessJob',NULL,'Y','SQLLOADER',NULL,NULL,'35',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('36','PRJ','ProjectEnterpriseResource','prj/projectManagement/import',NULL,'/oracle/apps/ess/projects/projectManagement/resources;PjtLoadEnterpriseResourceDataJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'36',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('37','FIN','chinaGoldenTaxTransaction','fin/receivables/import',NULL,'/oracle/apps/ess/financials/apacLocalizations/transaction/goldenTax;VatInvoiceImportForCloud','/oracle/apps/ess/financials/apacLocalizations/transaction/goldenTax;VatInvoiceImportForCloud','Y','SQLLOADER',NULL,NULL,'37',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('38','PRJ','Project Task','prj/projectFoundation/import',NULL,'/oracle/apps/ess/projects/foundation/projectDefinition;ImportTasksInterfaceDataJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'38',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('39','PRJ','Project Budget','prj/projectControl/import',NULL,'/oracle/apps/ess/projects/control/budgetsAndForecasts;ImportBudgetsInterfaceData',NULL,'Y','SQLLOADER',NULL,'ProjectBudgets','39',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('4','FIN','customer','fin/receivables/import',NULL,'/oracle/apps/ess/cdm/foundation/bulkImport;CDMAutoBulkImportJob',NULL,'Y','SQLLOADER',NULL,'Customers','4',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('40','PRJ','PjtProjectPlan','prj/projectManagement/import',NULL,'/oracle/apps/ess/projects/projectManagement/projectPlan;PjtLoadProjectPlanDataJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'40',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('41','PRJ','Project Progress','prj/projectResourceManagement/import',NULL,'/oracle/apps/ess/projects/resourceManagement/reporting;PjrReportingLoadActualHoursDataJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'41',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('42','PRJ','Project Resource Request','prj/projectResourceManagement/import',NULL,'/oracle/apps/ess/projects/resourceManagement/request;PjrRequestLoadRequestDataJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'42',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('43','FIN','taxRate','fin/tax/import',NULL,'/oracle/apps/ess/financials/tax/report;FinancialTaxPartyImport',NULL,'Y','SQLLOADER',NULL,NULL,'43',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('44','FIN','taxRate','fin/tax/import',NULL,'/oracle/apps/ess/financials/tax/report;FinancialTaxEntryRepo',NULL,'Y','SQLLOADER',NULL,NULL,'44',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('45','PRJ','projectExpenditureItem','prj/projectFoundation/import',NULL,'/oracle/apps/ess/projects/costing/setup;ImportTransactionControlsJob',NULL,'Y','SQLLOADER',NULL,NULL,'45',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('46','PRJ','Project','prj/projectFoundation/import',NULL,'/oracle/apps/ess/projects/foundation/projectDefinition;ImportProjectJobDef',NULL,'Y','SQLLOADER',NULL,'Projects','46','ImportProjectReportJob',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('47','FIN','Payables Collection Document','fin/payables/import',NULL,'/oracle/apps/ess/financials/latinLocalizations/transaction/payables/bankTransfer;ValidateAndImportColDocs',NULL,'Y','SQLLOADER',NULL,NULL,'47',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('48','FIN','Payables Bank Return','fin/payables/import',NULL,'/oracle/apps/ess/financials/latinLocalizations/transaction/payables/bankTransfer;ValidateAndImportBankReturns',NULL,'Y','SQLLOADER',NULL,NULL,'48',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('49','FIN','Receivables Bank Return','fin/receivables/import',NULL,'/oracle/apps/ess/financials/latinLocalizations/transaction/receivables/bankTransfer;ImportBankReturns',NULL,'Y','SQLLOADER',NULL,NULL,'49',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('5','FIN','bankStatement','fin/cashManagement/import','/oracle/apps/ess/financials/cashManagement/bankStatements;BAI2BankStatements','/oracle/apps/ess/financials/cashManagement/bankStatements;BAI2BankStatements',NULL,'N','ESSJOB',NULL,NULL,'5',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('50','FIN','bankStatement','fin/cashManagement/import',NULL,'/oracle/apps/ess/financials/cashManagement/bankStatements;ImportExternalTransactions','/oracle/apps/ess/financials/cashManagement/bankStatements;ImportExternalTransactions','Y','SQLLOADER',NULL,NULL,'50',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('51','FIN','Budget Interface','fin/budgetaryControl/import',NULL,'/oracle/apps/ess/financials/commitmentControl/integration/budgetImport;BudgetImport',NULL,'Y','SQLLOADER',NULL,NULL,'51',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('52','PRC','Supplier Products and Services Category','prc/supplier/import',NULL,'/oracle/apps/ess/prc/poz/supplierImport;ImportSupplierProductsandServicesCategory',NULL,'Y','SQLLOADER',NULL,NULL,'52',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('53','PRC','Supplier Business Classifications','prc/supplier/import',NULL,'/oracle/apps/ess/prc/poz/supplierImport;ImportSupplierBusinessClassifications',NULL,'Y','SQLLOADER',NULL,NULL,'53',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('54','FIN','revenueBasisLine','fin/revenueManagement/import',NULL,'/oracle/apps/ess/financials/revenueManagement/shared;VRMIRBD',NULL,'Y','SQLLOADER',NULL,NULL,'54',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('55','FIN','receivablesInvoice','fin/revenueManagement/import',NULL,'/oracle/apps/ess/financials/revenueManagement/shared;VRMIBDP','/oracle/apps/ess/financials/revenueManagement/shared;VRMIBDP','Y','SQLLOADER',NULL,NULL,'55',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('56','PRC','Supplier Address','prc/supplier/import',NULL,'/oracle/apps/ess/prc/poz/supplierImport;ImportSupplierAddresses',NULL,'Y','SQLLOADER',NULL,'SupplierAddresses','56',NULL,'calvin.roth','***MASKED-SET-ME***');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('57','PRJ','Award','prj/grantsManagement/import',NULL,'/oracle/apps/ess/projects/grantsManagement/award;AwardMassImportJob',NULL,'Y','SQLLOADER',NULL,'Grants','57',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('59','FIN','customers','fin/receivables/import',NULL,'/oracle/apps/ess/financials/receivables/customerSetup/customerProfileClasses;UploadCustomerEss',NULL,'Y','SQLLOADER',NULL,NULL,'59',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('6','FIN','bankStatement','fin/cashManagement/import','/oracle/apps/ess/financials/cashManagement/bankStatements;SWIFT940BankStatements','/oracle/apps/ess/financials/cashManagement/bankStatements;SWIFT940BankStatements',NULL,'N','ESSJOB',NULL,NULL,'6',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('60','FIN','transaction','fin/receivables/import','/oracle/apps/ess/financials/payments/fundsCapture/transactions;FetchSettlementACK','/oracle/apps/ess/financials/payments/fundsCapture/transactions;FetchSettlementACK',NULL,'N','ESSJOB',NULL,NULL,'60',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('61','FIN','Fiscal Document','fin/receivables/import',NULL,'/oracle/apps/ess/financials/genericLocalizations/transaction/fiscal;AutoInvoiceImportWithFiscalAttributesEss',NULL,'Y','SQLLOADER',NULL,NULL,'61',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('63','SCM','Work Order','scm/workOrder/import',NULL,'/oracle/apps/ess/scm/commonWorkExecution/massImport/workOrders;ImportWorkOrdersJob',NULL,'Y','SQLLOADER',NULL,NULL,'63',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('64','SCM','Work Order Material Transaction','scm/workOrderMaterialTransaction/import',NULL,'/oracle/apps/ess/scm/commonWorkExecution/massImport/materialTransactions;ImportMaterialTransactionJob',NULL,'Y','SQLLOADER',NULL,NULL,'64',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('65','SCM','Work Order Resource Transaction','scm/workOrderResourceTransaction/import',NULL,'/oracle/apps/ess/scm/commonWorkExecution/massImport/resourceTransactions;ImportResourceTransactionJob',NULL,'Y','SQLLOADER',NULL,NULL,'65',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('66','SCM','Work Order Operation Transaction','scm/workOrderOperationTransaction/import',NULL,'/oracle/apps/ess/scm/commonWorkExecution/massImport/operationTransactions;ImportOperationTransactionsJob',NULL,'Y','SQLLOADER',NULL,NULL,'66',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('67','PRJ','Project Resource Assignment','prj/projectResourceManagement/import',NULL,'/oracle/apps/ess/projects/resourceManagement/assignment;PjrAssignmentLoadAssignmentDataJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'67',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('68','PRJ','Project Billing Event','prj/projectBilling/import',NULL,'/oracle/apps/ess/projects/billing/transactions;ImportBillingEventJob',NULL,'Y','SQLLOADER',NULL,'BillingEvents','68','ImportBillingEventReportJob',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('7','FIN','bankStatement','fin/cashManagement/import','/oracle/apps/ess/financials/cashManagement/bankStatements;EDIFACTBankStatements','/oracle/apps/ess/financials/cashManagement/bankStatements;EDIFACTBankStatements',NULL,'N','ESSJOB',NULL,NULL,'7',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('71','FIN','dailyRates','fin/generalLedger/import',NULL,'/oracle/apps/ess/financials/generalLedger/programs/common;DailyRatesImport','oracle/apps/ess/financials/generalLedger/programs/common;DailyRatesImport','Y','SQLLOADER',NULL,NULL,'71',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('72','SCM','Source Sales Order','scm/sourceSalesOrder/import',NULL,'/oracle/apps/ess/scm/doo/decomposition/receiveTransform/receiveSalesOrder;ImportOrdersJob',NULL,'Y','SQLLOADER',NULL,NULL,'72',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('73','SCM','Shipment','scm/performShippingTransaction/import',NULL,'/oracle/apps/ess/scm/shipping/shipConfirm/deliveries;WshPerformShippingTxnJob',NULL,'Y','SQLLOADER',NULL,NULL,'73',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('74','SCM','Price List','scm/priceLists/import',NULL,'/oracle/apps/ess/scm/pricing/pricingAdmin/priceLists;QpPriceListsImportJob',NULL,'Y','SQLLOADER',NULL,NULL,'74',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('75','SCM','Supply Order','scm/supplyOrder/import',NULL,'/oracle/apps/ess/scm/dos/supplyRequestDecomposition/supplyRequestInterface/createSupplyOrders;ProcessSupplyOrderInterface',NULL,'Y','SQLLOADER',NULL,NULL,'75',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('76','FIN','EBSGL Reconciliation Data','fin/revenueManagement/import',NULL,'/oracle/apps/ess/financials/revenueManagement/shared;VRMIRA',NULL,'Y','SQLLOADER',NULL,NULL,'76',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('77','FIN','taxRate','fin/tax/import',NULL,'/oracle/apps/ess/financials/tax/report;FinancialsTaxMultiFileUpload',NULL,'Y','SQLLOADER',NULL,NULL,'77',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('78','PRJ','Project Forecast','prj/projectControl/import',NULL,'/oracle/apps/ess/projects/control/budgetsAndForecasts;ImportForecastsInterfaceData',NULL,'Y','SQLLOADER',NULL,NULL,'78',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('79','PRJ','Project Plan','prj/projectControl/import',NULL,'/oracle/apps/ess/projects/control/budgetsAndForecasts;ImportProjectPlansInterfaceData',NULL,'Y','SQLLOADER',NULL,NULL,'79',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('8','FIN','bankStatement','fin/cashManagement/import','/oracle/apps/ess/financials/cashManagement/bankStatements;ISO20022BankStatements','/oracle/apps/ess/financials/cashManagement/bankStatements;ISO20022BankStatements',NULL,'N','ESSJOB',NULL,NULL,'8',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('80','FIN','fixedAsset','fin/assets/import',NULL,'/oracle/apps/ess/financials/assets/shared;JapaneseDepreciableAssetsTaxSummaryReport','/oracle/apps/ess/financials/assets/additions;PrepareMassAdditions','Y','SQLLOADER',NULL,NULL,'80',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('81','FIN','Fiscal Document','fin/payables/import',NULL,'/oracle/apps/ess/financials/genericLocalizations/transaction/fiscal;ImportInboundFiscalDocAttributesEss',NULL,'Y','SQLLOADER',NULL,NULL,'81',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('82','FIN','fixedAsset','fin/assets/import',NULL,'/oracle/apps/ess/financials/assets/shared;FACOMP','/oracle/apps/ess/financials/assets/additions;PrepareMassAdditions','Y','SQLLOADER',NULL,NULL,'82',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('83','SCM','Requirements','scm/requirement/import',NULL,'/oracle/apps/ess/scm/customerNeedsManagement;AcnReqAndLineItemImportJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'83',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('84','SCM','Ideas','scm/idea/import',NULL,'/oracle/apps/ess/scm/customerNeedsManagement;AcnIdeaImportJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'84',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('85','SCM','Concept','scm/productConcept/import',NULL,'/oracle/apps/ess/scm/productConceptDesign;AcdConceptImportJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'85',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('86','SCM','Proposal','scm/productProposal/import',NULL,'/oracle/apps/ess/scm/productConceptDesign;AcdProposalImportJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'86',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('87','SCM','Proposal Cost','scm/productProposal/import',NULL,'/oracle/apps/ess/scm/productConceptDesign;AcdProCostImportJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'87',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('88','SCM','Proposal Resource ','scm/productProposal/import',NULL,'/oracle/apps/ess/scm/productConceptDesign;AcdProResImportJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'88',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('89','SCM','Proposal Revenue','scm/productProposal/import',NULL,'/oracle/apps/ess/scm/productConceptDesign;AcdProRevImportJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'89',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('9','FIN','fixedAsset','fin/assets/import',NULL,'/oracle/apps/ess/financials/assets/additions;PrepareMassAdditions','/oracle/apps/ess/financials/assets/additions;PostMassAdditions','Y','SQLLOADER',NULL,'Assets','9',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('90','PRJ','Project Resource Pool','prj/projectResourceManagement/import',NULL,'/oracle/apps/ess/projects/resourceManagement/resources;PjrResourcesLoadResourcePoolDataJobDef',NULL,'Y','SQLLOADER',NULL,NULL,'90',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('91','FIN','bankStatement','fin/cashManagement/import',NULL,'/oracle/apps/ess/financials/cashManagement/cashPosition/integration;CashPositionDataTransfer','oracle/apps/ess/financials/cashManagement/cashPosition/integration;CashPositionDataTransfer','Y','SQLLOADER',NULL,NULL,'91',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('92','FIN','Payables Transactions','fin/payables/export',NULL,'/oracle/apps/ess/financials/commonModules/shared/common/outbound;PayablesTransactionsExtract',NULL,'N','BIPREPORT',NULL,NULL,'92',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('93','FIN','Payments','fin/payments/export',NULL,'/oracle/apps/ess/financials/commonModules/shared/common/outbound;PaymentsExtract',NULL,'N','BIPREPORT',NULL,NULL,'93',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('94','FIN','Receivables Transactions','fin/receivables/export',NULL,'/oracle/apps/ess/financials/commonModules/shared/common/outbound;ReceivablesTransactionsExtract',NULL,'N','BIPREPORT',NULL,NULL,'94',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('95','FIN','Receivables Adjustments','fin/receivables/export',NULL,'/oracle/apps/ess/financials/commonModules/shared/common/outbound;ReceivablesAdjustmentsExtract',NULL,'N','BIPREPORT',NULL,NULL,'95',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('96','FIN','Receivables Receipts','fin/receivables/export',NULL,'/oracle/apps/ess/financials/commonModules/shared/common/outbound;ReceiptsAnalysisExtract',NULL,'N','BIPREPORT',NULL,NULL,'96',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('97','FIN','Receivables Billing History','fin/receivables/export',NULL,'/oracle/apps/ess/financials/commonModules/shared/common/outbound;ReceivablesBillingHistoryExtract',NULL,'N','BIPREPORT',NULL,NULL,'97',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('98','FIN','Bank Statement','fin/cashManagement/export',NULL,'/oracle/apps/ess/financials/commonModules/shared/common/outbound;BankStatementExtract',NULL,'N','BIPREPORT',NULL,NULL,'98',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_ERP_INTERFACE_OPTIONS_TBL" ("ERP_INTERFACE_OPTIONS_ID","ERP_FAMILY","BUSINESS_OBJECT","UCM_ACCOUNT","LOAD_JOB_NAME","IMPORT_JOB_NAME","POST_LOAD_JOB_NAME","LOAD_INTERFACE_FLAG","LOADER_TYPE","SERVICE_NAME","CEMLI_CODE","SOURCE_ERP_OPTIONS_ID","REPORT_JOB_DEF","FUSION_USERNAME","FUSION_PASSWORD") values ('99','FIN','Asset','fin/assets/export',NULL,'/oracle/apps/ess/financials/commonModules/shared/common/outbound;AssetAdditionsExtract',NULL,'N','BIPREPORT',NULL,NULL,'99',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
commit;
