-- Seed data for DMT_BIP_REPORT_TBL (26 rows, snapshot 2026-07-03)
-- Idempotent: duplicate-key inserts are skipped.
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000001,'ARInvoices','AR Invoice','/Custom/DMT/ARInvoices/AR_DM.xdm','/Custom/DMT/ARInvoices/AR_RPT.xdo','RA_INTERFACE_LINES_ALL',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'AR AutoInvoice import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000002,'Projects','Project','/Custom/DMT/Projects/PROJECT_DM.xdm','/Custom/DMT/Projects/PROJECT_RPT.xdo','PJF_PROJECTS_ALL_XFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Project import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000003,'PurchaseOrders','Purchase Order','/Custom/DMT/PurchaseOrders/PO_DM.xdm','/Custom/DMT/PurchaseOrders/PO_RPT.xdo','PO_HEADERS_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Purchase order header import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000004,'Assets','Asset','/Custom/DMT/Assets/FA_ASSET_DM.xdm','/Custom/DMT/Assets/FA_ASSET_RPT.xdo','FA_MASS_ADDITIONS',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Fixed asset mass additions import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000005,'APInvoices','AP Invoice','/Custom/DMT/APInvoices/AP_DM_V4.xdm','/Custom/DMT/APInvoices/AP_RPT_V4.xdo','AP_INVOICES_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'V4: NVL(rejection_message, reject_lookup_code) from ap_interface_rejections',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000006,'BlanketPOs','Blanket Purchase Agreement','/Custom/DMT/BlanketPOs/BLANKET_PO_DM.xdm','/Custom/DMT/BlanketPOs/BLANKET_PO_RPT.xdo','PO_HEADERS_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Blanket purchase agreement import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000007,'Grants','Grant/Award','/Custom/DMT/Grants/GRANTS_DM.xdm','/Custom/DMT/Grants/GRANTS_RPT.xdo','GMS_AWARD_HEADERS_INT',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Grants/awards import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000008,'MiscReceipts','Misc Receipt (Items on Hand)','/Custom/DMT/MiscReceipts/MISC_RECEIPT_DM.xdm','/Custom/DMT/MiscReceipts/MISC_RECEIPT_RPT.xdo','RCV_HEADERS_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Miscellaneous receiving receipt import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000009,'Requisitions','Requisition','/Custom/DMT/Requisitions/REQ_DM.xdm','/Custom/DMT/Requisitions/REQ_RPT.xdo','POR_REQ_HEADERS_INTERFACE_ALL',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Requisition import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000010,'SupplierSiteAssignments','Supplier Site Assignment','/Custom/DMT/SupplierSiteAssignments/SUP_SITE_ASSN_DM.xdm','/Custom/DMT/SupplierSiteAssignments/SUP_SITE_ASSN_RPT.xdo','POZ_SITE_ASSIGNMENTS_INT',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Supplier site assignment import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000011,'BillingEvents','Billing Event','/Custom/DMT/BillingEvents/BILLING_EVENT_DM.xdm','/Custom/DMT/BillingEvents/BILLING_EVENT_RPT.xdo','PJB_BILLING_EVENTS_INT',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Project billing event import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000012,'Customers','Customer','/Custom/DMT/Customers/CUST_DM.xdm','/Custom/DMT/Customers/CUST_RPT.xdo','HZ_IMP_PARTIES_T',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Customer party import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000013,'PlanningBudgets','Planning Budget','/Custom/DMT/PlanningBudgets/PLAN_BUDGET_DM.xdm','/Custom/DMT/PlanningBudgets/PLAN_BUDGET_RPT.xdo','N/A (EPBCS internal)',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Planning budget import reconciliation â€” no BIP-accessible interface table; uses absence=LOADED pattern (EPBCS â€” dormant)',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000014,'SupplierAddresses','Supplier Address','/Custom/DMT/SupplierAddresses/SUP_ADDR_DM.xdm','/Custom/DMT/SupplierAddresses/SUP_ADDR_RPT.xdo','POZ_SUP_ADDRESSES_INT',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Supplier address import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000015,'SupplierContacts','Supplier Contact','/Custom/DMT/SupplierContacts/SUP_CONT_DM.xdm','/Custom/DMT/SupplierContacts/SUP_CONT_RPT.xdo','POZ_SUP_CONTACTS_INT',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Supplier contact import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000016,'GLBalances','GL Balance','/Custom/DMT/GLBalances/GL_BAL_DM.xdm','/Custom/DMT/GLBalances/GL_BAL_RPT.xdo','GL_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'GL journal import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000017,'Contracts','Contract Purchase Agreement','/Custom/DMT/Contracts/CONTRACT_DM.xdm','/Custom/DMT/Contracts/CONTRACT_RPT.xdo','PO_HEADERS_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Contract purchase agreement import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000018,'Expenditures','Expenditure','/Custom/DMT/Expenditures/EXPENDITURE_DM.xdm','/Custom/DMT/Expenditures/EXPENDITURE_RPT.xdo','PJC_TXN_XFACE_STAGE_ALL',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Project expenditure cost import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000019,'ProjectBudgets','Project Budget','/Custom/DMT/ProjectBudgets/PRJ_BUDGET_DM.xdm','/Custom/DMT/ProjectBudgets/PRJ_BUDGET_RPT.xdo','PJO_PLAN_VERSIONS_XFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Project budget import reconciliation â€” PjoPlanVersionsXface.csv via prj/projectControl/import',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000020,'Suppliers','Supplier','/Custom/DMT/Suppliers/SUP_DM.xdm','/Custom/DMT/Suppliers/SUP_RPT.xdo','POZ_SUPPLIERS_INT',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Supplier header import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000021,'SupplierSites','Supplier Site','/Custom/DMT/SupplierSites/SUP_SITE_DM.xdm','/Custom/DMT/SupplierSites/SUP_SITE_RPT.xdo','POZ_SUPPLIER_SITES_INT',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Supplier site import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000022,'1099Invoices','1099 Invoice','/Custom/DMT/1099Invoices/AP_1099_DM.xdm','/Custom/DMT/1099Invoices/AP_1099_RPT.xdo','AP_INVOICES_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'1099 invoice import reconciliation (shares AP tables)',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000023,'GLBudgetBalances','GL Budget Balance','/Custom/DMT/GLBudgetBalances/GL_BUDGET_DM.xdm','/Custom/DMT/GLBudgetBalances/GL_BUDGET_RPT.xdo','GL_BUDGET_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'GL budget import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000024,'COMMON_LOOKUPS','Business Unit Lookups','/Custom/DMT/common/DMT_FBDI_LOOKUPS_DM.xdm','/Custom/DMT/common/DMT_FBDI_LOOKUPS_RPT.xdo','FUN_ALL_BUSINESS_UNITS_V',to_date('2026-04-24 17:22:31','YYYY-MM-DD HH24:MI:SS'),'Auto-refresh BU IDs at pipeline start',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000025,'Items','EGP_ITEM','/Custom/DMT/Items/ITEM_DM.xdm','/Custom/DMT/Items/ITEM_RPT.xdo','EGP_SYSTEM_ITEMS_INTERFACE',to_date('2026-05-23 23:44:58','YYYY-MM-DD HH24:MI:SS'),'Item Import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000026,'ItemCategories','EGP_ITEM_CATEGORY','/Custom/DMT/ItemCategories/ITEM_CAT_DM.xdm','/Custom/DMT/ItemCategories/ITEM_CAT_RPT.xdo','EGP_ITEM_CATEGORIES_INTERFACE',to_date('2026-05-23 23:44:58','YYYY-MM-DD HH24:MI:SS'),'Item Category reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
commit;
