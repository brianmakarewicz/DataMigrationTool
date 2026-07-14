-- Seed data for DMT_BIP_REPORT_TBL (26 rows, snapshot 2026-07-03)
-- Idempotent: duplicate-key inserts are skipped.
-- Supplier-family rows (Stage D, 2026-07-08): maintained by the MERGE at
-- the end of this file so re-running the seed CONVERGES them to this
-- stack's own BIP catalog under /Custom/DMT2/ (never /Custom/DMT/ -- the
-- frozen stack's catalog).
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
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000003,'PurchaseOrders','Purchase Order','/Custom/DMT2/PurchaseOrders/PO_DM.xdm','/Custom/DMT2/PurchaseOrders/PO_RPT.xdo','PO_HEADERS_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Purchase order header import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000004,'Assets','Asset','/Custom/DMT/Assets/FA_ASSET_DM.xdm','/Custom/DMT/Assets/FA_ASSET_RPT.xdo','FA_MASS_ADDITIONS',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Fixed asset mass additions import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000005,'APInvoices','AP Invoice','/Custom/DMT2/APInvoices/AP_DM.xdm','/Custom/DMT2/APInvoices/AP_RPT.xdo','AP_INVOICES_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'V4: NVL(rejection_message, reject_lookup_code) from ap_interface_rejections',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000006,'BlanketPOs','Blanket Purchase Agreement','/Custom/DMT2/BlanketPOs/BLANKET_PO_DM.xdm','/Custom/DMT2/BlanketPOs/BLANKET_PO_RPT.xdo','PO_HEADERS_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Blanket purchase agreement import reconciliation',NULL,NULL);
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
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000011,'BillingEvents','Billing Event','/Custom/DMT/BillingEvents/BILLING_EVENT_DM.xdm','/Custom/DMT/BillingEvents/BILLING_EVENT_RPT.xdo','PJB_BILLING_EVENTS_INT',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Project billing event import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
-- Customers (100000012): moved out of this idempotent-insert block and into
-- the MERGE-converging block at the end of this file (2026-07-09 Stage E) so
-- re-running the seed repoints the Customers reconciliation report from the
-- frozen stack's /Custom/DMT/ to THIS stack's /Custom/DMT2/Customers/ with the
-- Contract v1 _RECON_ artifact names.
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000013,'PlanningBudgets','Planning Budget','/Custom/DMT/PlanningBudgets/PLAN_BUDGET_DM.xdm','/Custom/DMT/PlanningBudgets/PLAN_BUDGET_RPT.xdo','N/A (EPBCS internal)',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Planning budget import reconciliation â€” no BIP-accessible interface table; uses absence=LOADED pattern (EPBCS â€” dormant)',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000016,'GLBalances','GL Balance','/Custom/DMT/GLBalances/GL_BAL_DM.xdm','/Custom/DMT/GLBalances/GL_BAL_RPT.xdo','GL_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'GL journal import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000017,'Contracts','Contract Purchase Agreement','/Custom/DMT2/Contracts/CONTRACT_DM.xdm','/Custom/DMT2/Contracts/CONTRACT_RPT.xdo','PO_HEADERS_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Contract purchase agreement import reconciliation',NULL,NULL);
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
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000022,'1099Invoices','1099 Invoice','/Custom/DMT2/1099Invoices/AP_1099_DM.xdm','/Custom/DMT2/1099Invoices/AP_1099_RPT.xdo','AP_INVOICES_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'1099 invoice import reconciliation (shares AP tables)',NULL,NULL);
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
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000025,'Items','EGP_ITEM','/Custom/DMT2/Items/ITEM_DM.xdm','/Custom/DMT2/Items/ITEM_RPT.xdo','EGP_SYSTEM_ITEMS_INTERFACE',to_date('2026-05-23 23:44:58','YYYY-MM-DD HH24:MI:SS'),'Item Import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000026,'ItemCategories','EGP_ITEM_CATEGORY','/Custom/DMT2/ItemCategories/ITEM_CAT_DM.xdm','/Custom/DMT2/ItemCategories/ITEM_CAT_RPT.xdo','EGP_ITEM_CATEGORIES_INTERFACE',to_date('2026-05-23 23:44:58','YYYY-MM-DD HH24:MI:SS'),'Item Category reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
commit;

-- ----------------------------------------------------------------------
-- Supplier family (Stage D live slice, 2026-07-08) + Customers (Stage E
-- live slice, 2026-07-09): the reconciliation reports are deployed to THIS
-- stack's catalog root /Custom/DMT2/{CEMLI}/ (scripts/deploy_supplier_bip_reports.py
-- + DMT_BIP_DEPLOY_PKG.DEPLOY_RECON_REPORT). MERGE on CEMLI_CODE so
-- re-running the seed converges pre-existing rows to these paths -- for
-- Customers this repoints the row from the frozen /Custom/DMT/ to
-- /Custom/DMT2/Customers/ with the Contract v1 _RECON_ artifact names.
-- ----------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000020 bip_report_id, 'Suppliers' cemli_code, 'Supplier' object_type,
           '/Custom/DMT2/Suppliers/SUP_DM.xdm' dm_catalog_path,
           '/Custom/DMT2/Suppliers/SUP_RPT.xdo' report_catalog_path,
           'POZ_SUPPLIERS_INT' interface_table,
           'Supplier header import reconciliation' notes from dual
    union all select 100000012, 'Customers', 'Customer',
           '/Custom/DMT2/Customers/DMT_CUST_RECON_DM.xdm',
           '/Custom/DMT2/Customers/DMT_CUST_RECON_RPT.xdo',
           'HZ_IMP_PARTIES_T',
           'Customer party import reconciliation (Contract v1)' from dual
    union all select 100000014, 'SupplierAddresses', 'Supplier Address',
           '/Custom/DMT2/SupplierAddresses/SUP_ADDR_DM.xdm',
           '/Custom/DMT2/SupplierAddresses/SUP_ADDR_RPT.xdo',
           'POZ_SUP_ADDRESSES_INT',
           'Supplier address import reconciliation' from dual
    union all select 100000021, 'SupplierSites', 'Supplier Site',
           '/Custom/DMT2/SupplierSites/SUP_SITE_DM.xdm',
           '/Custom/DMT2/SupplierSites/SUP_SITE_RPT.xdo',
           'POZ_SUPPLIER_SITES_INT',
           'Supplier site import reconciliation' from dual
    union all select 100000010, 'SupplierSiteAssignments', 'Supplier Site Assignment',
           '/Custom/DMT2/SupplierSiteAssignments/SUP_SITE_ASSN_DM.xdm',
           '/Custom/DMT2/SupplierSiteAssignments/SUP_SITE_ASSN_RPT.xdo',
           'POZ_SITE_ASSIGNMENTS_INT',
           'Supplier site assignment import reconciliation' from dual
    union all select 100000015, 'SupplierContacts', 'Supplier Contact',
           '/Custom/DMT2/SupplierContacts/SUP_CONT_DM.xdm',
           '/Custom/DMT2/SupplierContacts/SUP_CONT_RPT.xdo',
           'POZ_SUP_CONTACTS_INT',
           'Supplier contact import reconciliation' from dual
    union all select 100000016, 'GLBalances', 'GL Balance',
           '/Custom/DMT2/GLBalances/GL_BAL_DM.xdm',
           '/Custom/DMT2/GLBalances/GL_BAL_RPT.xdo',
           'GL_INTERFACE',
           'GL journal import reconciliation (Contract v1)' from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."OBJECT_TYPE"         = s.object_type,
    t."DM_CATALOG_PATH"     = s.dm_catalog_path,
    t."REPORT_CATALOG_PATH" = s.report_catalog_path,
    t."INTERFACE_TABLE"     = s.interface_table,
    t."NOTES"               = s.notes
when not matched then insert
    ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH",
     "REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES",
     "DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE")
    values (s.bip_report_id, s.cemli_code, s.object_type, s.dm_catalog_path,
            s.report_catalog_path, s.interface_table, sysdate, s.notes,
            null, null);

commit;
