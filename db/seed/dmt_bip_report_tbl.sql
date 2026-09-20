-- Seed data for DMT_BIP_REPORT_TBL (26 rows, snapshot 2026-07-03)
-- Idempotent: duplicate-key inserts are skipped.
-- Supplier-family rows (Stage D, 2026-07-08): maintained by the MERGE at
-- the end of this file so re-running the seed CONVERGES them to this
-- stack's own BIP catalog under /Custom/DMT2/ (never /Custom/DMT/ -- the
-- frozen stack's catalog).
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000001,'ARInvoices','AR Invoice','/Custom/DMT2/ARInvoices/AR_DM.xdm','/Custom/DMT2/ARInvoices/AR_RPT.xdo','RA_INTERFACE_LINES_ALL',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'AR AutoInvoice import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000002,'Projects','Project','/Custom/DMT2/Projects/PROJECT_DM.xdm','/Custom/DMT2/Projects/PROJECT_RPT.xdo','PJF_PROJECTS_ALL_XFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Project import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000003,'PurchaseOrders','Purchase Order','/Custom/DMT2/PurchaseOrders/PO_DM.xdm','/Custom/DMT2/PurchaseOrders/PO_RPT.xdo','PO_HEADERS_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Purchase order header import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000004,'Assets','Asset','/Custom/DMT2/Assets/FA_ASSET_DM.xdm','/Custom/DMT2/Assets/FA_ASSET_RPT.xdo','FA_MASS_ADDITIONS',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Fixed asset mass additions import reconciliation',NULL,NULL);
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
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000007,'Grants','Grant/Award','/Custom/DMT2/Grants/GRANTS_DM.xdm','/Custom/DMT2/Grants/GRANTS_RPT.xdo','GMS_AWARD_HEADERS_INT',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Grants/awards import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000008,'MiscReceipts','Misc Receipt (Items on Hand)','/Custom/DMT2/MiscReceipts/MISC_RECEIPT_DM.xdm','/Custom/DMT2/MiscReceipts/MISC_RECEIPT_RPT.xdo','RCV_HEADERS_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Miscellaneous receiving receipt import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000009,'Requisitions','Requisition','/Custom/DMT2/Requisitions/REQ_DM.xdm','/Custom/DMT2/Requisitions/REQ_RPT.xdo','POR_REQ_HEADERS_INTERFACE_ALL',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Requisition import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000011,'BillingEvents','Billing Event','/Custom/DMT2/BillingEvents/BILLING_EVENT_DM.xdm','/Custom/DMT2/BillingEvents/BILLING_EVENT_RPT.xdo','PJB_BILLING_EVENTS_INT',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Project billing event import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
-- Customers (100000012): moved out of this idempotent-insert block and into
-- the MERGE-converging block at the end of this file (2026-07-09 Stage E) so
-- re-running the seed repoints the Customers reconciliation report from the
-- frozen stack's /Custom/DMT/ to THIS stack's /Custom/DMT2/Customers/ with the
-- Contract v1 _RECON_ artifact names.
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000013,'PlanningBudgets','Planning Budget','/Custom/DMT2/PlanningBudgets/PLAN_BUDGET_DM.xdm','/Custom/DMT2/PlanningBudgets/PLAN_BUDGET_RPT.xdo','N/A (EPBCS internal)',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Planning budget import reconciliation - no BIP-accessible interface table; uses absence=LOADED pattern (EPBCS - dormant)',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000016,'GLBalances','GL Balance','/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_DM.xdm','/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_RPT.xdo','GL_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'GL journal import reconciliation (Contract v1)',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000017,'Contracts','Contract Purchase Agreement','/Custom/DMT2/Contracts/CONTRACT_DM.xdm','/Custom/DMT2/Contracts/CONTRACT_RPT.xdo','PO_HEADERS_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Contract purchase agreement import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000018,'Expenditures','Expenditure','/Custom/DMT2/Expenditures/EXPENDITURE_DM.xdm','/Custom/DMT2/Expenditures/EXPENDITURE_RPT.xdo','PJC_TXN_XFACE_STAGE_ALL',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Project expenditure cost import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000019,'ProjectBudgets','Project Budget','/Custom/DMT2/ProjectBudgets/PRJ_BUDGET_DM.xdm','/Custom/DMT2/ProjectBudgets/PRJ_BUDGET_RPT.xdo','PJO_PLAN_VERSIONS_XFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'Project budget import reconciliation - PjoPlanVersionsXface.csv via prj/projectControl/import',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000023,'GLBudgets','GL Budget Balance','/Custom/DMT2/GLBudgets/GL_BUDGET_DM.xdm','/Custom/DMT2/GLBudgets/GL_BUDGET_RPT.xdo','GL_BUDGET_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'GL budget import reconciliation',NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000024,'COMMON_LOOKUPS','Business Unit Lookups','/Custom/DMT2/common/DMT_FBDI_LOOKUPS_DM.xdm','/Custom/DMT2/common/DMT_FBDI_LOOKUPS_RPT.xdo','FUN_ALL_BUSINESS_UNITS_V',to_date('2026-04-24 17:22:31','YYYY-MM-DD HH24:MI:SS'),'Auto-refresh BU IDs at pipeline start',NULL,NULL);
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
begin
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000029,'SalaryBases','Salary Basis','/Custom/DMT2/SalaryBases/DMT_SALARYBASES_RECON_DM.xdm','/Custom/DMT2/SalaryBases/DMT_SALARYBASES_RECON_RPT.xdo','N/A (HDL)',to_date('2026-09-16 00:00:00','YYYY-MM-DD HH24:MI:SS'),'Salary basis HDL base-table reconciliation (Contract v1)',NULL,NULL);
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
           '/Custom/DMT2/Customers/DMT_CUST_RECON_V2_DM.xdm',
           '/Custom/DMT2/Customers/DMT_CUST_RECON_V2_RPT.xdo',
           'HZ_IMP_PARTIES_T',
           'Customer party import reconciliation (Contract v1). V2 (Fix A): adds NOT-LOADED error-tier blocks for all child interface tables (Locations, PartySites, PartySiteUses, AccountSites, AccountSiteUses) so held/rejected child records report their real interface status instead of the generic reconcile sweep. Deployed additively alongside the v1 DMT_CUST_RECON_* artifacts.' from dual
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
           '/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_DM.xdm',
           '/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_RPT.xdo',
           'GL_INTERFACE',
           'GL journal import reconciliation (Contract v1 -- nine columns, keyset)' from dual
    -- Issue 8 (2026-07-20): repoint the remaining reconciliation reports from the
    -- frozen stack's /Custom/DMT/ to THIS stack's /Custom/DMT2/. Their data models
    -- + reports were additively deployed to /Custom/DMT2/{CEMLI}/ and each report
    -- verified to resolve (runReport HTTP 200) BEFORE this repoint. /Custom/DMT/
    -- is retained untouched (additive/dual-folder). Placed in the MERGE (not the
    -- idempotent-insert block above) so re-running the seed CONVERGES existing rows.
    union all select 100000002, 'Projects', 'Project',
           '/Custom/DMT2/Projects/PROJECT_DM.xdm',
           '/Custom/DMT2/Projects/PROJECT_RPT.xdo',
           'PJF_PROJECTS_ALL_XFACE',
           'Project import reconciliation' from dual
    union all select 100000004, 'Assets', 'Asset',
           '/Custom/DMT2/Assets/FA_ASSET_DM.xdm',
           '/Custom/DMT2/Assets/FA_ASSET_RPT.xdo',
           'FA_MASS_ADDITIONS',
           'Fixed asset mass additions import reconciliation' from dual
    union all select 100000007, 'Grants', 'Grant/Award',
           '/Custom/DMT2/Grants/GRANTS_DM.xdm',
           '/Custom/DMT2/Grants/GRANTS_RPT.xdo',
           'GMS_AWARD_HEADERS_INT',
           'Grants/awards import reconciliation' from dual
    union all select 100000008, 'MiscReceipts', 'Misc Receipt (Items on Hand)',
           '/Custom/DMT2/MiscReceipts/MISC_RECEIPT_DM.xdm',
           '/Custom/DMT2/MiscReceipts/MISC_RECEIPT_RPT.xdo',
           'RCV_HEADERS_INTERFACE',
           'Miscellaneous receiving receipt import reconciliation' from dual
    union all select 100000009, 'Requisitions', 'Requisition',
           '/Custom/DMT2/Requisitions/REQ_DM.xdm',
           '/Custom/DMT2/Requisitions/REQ_RPT.xdo',
           'POR_REQ_HEADERS_INTERFACE_ALL',
           'Requisition import reconciliation' from dual
    union all select 100000011, 'BillingEvents', 'Billing Event',
           '/Custom/DMT2/BillingEvents/BILLING_EVENT_DM.xdm',
           '/Custom/DMT2/BillingEvents/BILLING_EVENT_RPT.xdo',
           'PJB_BILLING_EVENTS_INT',
           'Project billing event import reconciliation' from dual
    union all select 100000013, 'PlanningBudgets', 'Planning Budget',
           '/Custom/DMT2/PlanningBudgets/PLAN_BUDGET_DM.xdm',
           '/Custom/DMT2/PlanningBudgets/PLAN_BUDGET_RPT.xdo',
           'N/A (EPBCS internal)',
           'Planning budget import reconciliation - no BIP-accessible interface table; uses absence=LOADED pattern (EPBCS - dormant)' from dual
    union all select 100000018, 'Expenditures', 'Expenditure',
           '/Custom/DMT2/Expenditures/EXPENDITURE_DM.xdm',
           '/Custom/DMT2/Expenditures/EXPENDITURE_RPT.xdo',
           'PJC_TXN_XFACE_STAGE_ALL',
           'Project expenditure cost import reconciliation' from dual
    union all select 100000019, 'ProjectBudgets', 'Project Budget',
           '/Custom/DMT2/ProjectBudgets/PRJ_BUDGET_DM.xdm',
           '/Custom/DMT2/ProjectBudgets/PRJ_BUDGET_RPT.xdo',
           'PJO_PLAN_VERSIONS_XFACE',
           'Project budget import reconciliation - PjoPlanVersionsXface.csv via prj/projectControl/import' from dual
    union all select 100000024, 'COMMON_LOOKUPS', 'Business Unit Lookups',
           '/Custom/DMT2/common/DMT_FBDI_LOOKUPS_DM.xdm',
           '/Custom/DMT2/common/DMT_FBDI_LOOKUPS_RPT.xdo',
           'FUN_ALL_BUSINESS_UNITS_V',
           'Auto-refresh BU IDs at pipeline start' from dual
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

-- ---------------------------------------------------------------------------
-- Workers — Contract v1 registration (design section 5). The FIRST object
-- registered with the four Contract v1 columns (CONTRACT_VERSION, TFM_TABLE,
-- FUSION_ID_COLUMN, RECON_KEY_SQL) that drive the shared parser
-- DMT_RECON_CONTRACT_PKG.FETCH_ROWS. Kept in its own MERGE so this block also
-- converges the Contract v1 columns on an existing row. HDL load = no interface
-- table (INTERFACE_TABLE = 'N/A (HDL)'); reconciliation is base-tier only from
-- PER_ALL_PEOPLE_F. RECON_KEY = the prefixed PERSON_NUMBER (also the .dat
-- SourceSystemId and the report RECORD_KEY).
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000027                                            bip_report_id,
           'Workers'                                            cemli_code,
           'Worker'                                             object_type,
           '/Custom/DMT2/Workers/DMT_WORKERS_RECON_DM.xdm'      dm_catalog_path,
           '/Custom/DMT2/Workers/DMT_WORKERS_RECON_RPT.xdo'     report_catalog_path,
           'N/A (HDL)'                                          interface_table,
           'Worker HDL base-table reconciliation (Contract v1)' notes,
           1                                                    contract_version,
           'DMT_WORKER_TFM_TBL'                                 tfm_table,
           'FUSION_PERSON_ID'                                   fusion_id_column,
           'DMT_UTIL_PKG.PREFIXED(run_prefix, PERSON_NUMBER, 30) -- prefixed person number' recon_key_sql
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."OBJECT_TYPE"         = s.object_type,
    t."DM_CATALOG_PATH"     = s.dm_catalog_path,
    t."REPORT_CATALOG_PATH" = s.report_catalog_path,
    t."INTERFACE_TABLE"     = s.interface_table,
    t."NOTES"               = s.notes,
    t."CONTRACT_VERSION"    = s.contract_version,
    t."TFM_TABLE"           = s.tfm_table,
    t."FUSION_ID_COLUMN"    = s.fusion_id_column,
    t."RECON_KEY_SQL"       = s.recon_key_sql
when not matched then insert
    ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH",
     "REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES",
     "DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE",
     "CONTRACT_VERSION","TFM_TABLE","FUSION_ID_COLUMN","RECON_KEY_SQL")
    values (s.bip_report_id, s.cemli_code, s.object_type, s.dm_catalog_path,
            s.report_catalog_path, s.interface_table, sysdate, s.notes,
            null, null,
            s.contract_version, s.tfm_table, s.fusion_id_column, s.recon_key_sql);

commit;

-- ---------------------------------------------------------------------------
-- SalaryBases — Contract v1 registration (design section 5). Follows the
-- Workers template exactly: the four Contract v1 columns (CONTRACT_VERSION,
-- TFM_TABLE, FUSION_ID_COLUMN, RECON_KEY_SQL) drive the shared parser
-- DMT_RECON_CONTRACT_PKG.FETCH_ROWS. Kept in its own MERGE so this block also
-- converges the Contract v1 columns on an existing row. HDL load = no interface
-- table (INTERFACE_TABLE = 'N/A (HDL)'); reconciliation is base-tier only from
-- CMP_SALARY_BASES. RECON_KEY = the prefixed SALARY_BASIS_NAME (also the .dat
-- SourceSystemId and the report RECORD_KEY).
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000029                                                  bip_report_id,
           'SalaryBases'                                              cemli_code,
           'Salary Basis'                                             object_type,
           '/Custom/DMT2/SalaryBases/DMT_SALARYBASES_RECON_DM.xdm'    dm_catalog_path,
           '/Custom/DMT2/SalaryBases/DMT_SALARYBASES_RECON_RPT.xdo'   report_catalog_path,
           'N/A (HDL)'                                                interface_table,
           'Salary basis HDL base-table reconciliation (Contract v1)' notes,
           1                                                          contract_version,
           'DMT_SAL_BASIS_TFM_TBL'                                    tfm_table,
           'FUSION_SALARY_BASIS_ID'                                   fusion_id_column,
           'DMT_UTIL_PKG.PREFIXED(run_prefix, SALARY_BASIS_NAME, 240) -- prefixed salary basis name' recon_key_sql
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."OBJECT_TYPE"         = s.object_type,
    t."DM_CATALOG_PATH"     = s.dm_catalog_path,
    t."REPORT_CATALOG_PATH" = s.report_catalog_path,
    t."INTERFACE_TABLE"     = s.interface_table,
    t."NOTES"               = s.notes,
    t."CONTRACT_VERSION"    = s.contract_version,
    t."TFM_TABLE"           = s.tfm_table,
    t."FUSION_ID_COLUMN"    = s.fusion_id_column,
    t."RECON_KEY_SQL"       = s.recon_key_sql
when not matched then insert
    ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH",
     "REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES",
     "DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE",
     "CONTRACT_VERSION","TFM_TABLE","FUSION_ID_COLUMN","RECON_KEY_SQL")
    values (s.bip_report_id, s.cemli_code, s.object_type, s.dm_catalog_path,
            s.report_catalog_path, s.interface_table, sysdate, s.notes,
            null, null,
            s.contract_version, s.tfm_table, s.fusion_id_column, s.recon_key_sql);

commit;

-- ---------------------------------------------------------------------------
-- Salaries (100000028) — Contract v1 registration (design section 5). HDL load
-- = no interface table; base-tier only from CMP_SALARY via HRC_INTEGRATION_KEY_MAP.
-- RECON_KEY = prefixed PERSON_NUMBER || '_SAL' (also the .dat SourceSystemId and
-- the report RECORD_KEY). The when-not-matched insert makes this self-contained.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000028                                            bip_report_id,
           'Salaries'                                           cemli_code,
           'Salary'                                             object_type,
           '/Custom/DMT2/Salaries/DMT_SALARIES_RECON_DM.xdm'    dm_catalog_path,
           '/Custom/DMT2/Salaries/DMT_SALARIES_RECON_RPT.xdo'   report_catalog_path,
           'N/A (HDL)'                                          interface_table,
           'Salary HDL base-table reconciliation (Contract v1)' notes,
           1                                                    contract_version,
           'DMT_SALARY_TFM_TBL'                                 tfm_table,
           'FUSION_SALARY_ID'                                   fusion_id_column,
           'DMT_UTIL_PKG.PREFIXED(run_prefix, PERSON_NUMBER, 30) || ''_SAL''' recon_key_sql
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."OBJECT_TYPE"         = s.object_type,
    t."DM_CATALOG_PATH"     = s.dm_catalog_path,
    t."REPORT_CATALOG_PATH" = s.report_catalog_path,
    t."INTERFACE_TABLE"     = s.interface_table,
    t."NOTES"               = s.notes,
    t."CONTRACT_VERSION"    = s.contract_version,
    t."TFM_TABLE"           = s.tfm_table,
    t."FUSION_ID_COLUMN"    = s.fusion_id_column,
    t."RECON_KEY_SQL"       = s.recon_key_sql
when not matched then insert
    ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH",
     "REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES",
     "DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE",
     "CONTRACT_VERSION","TFM_TABLE","FUSION_ID_COLUMN","RECON_KEY_SQL")
    values (s.bip_report_id, s.cemli_code, s.object_type, s.dm_catalog_path,
            s.report_catalog_path, s.interface_table, sysdate, s.notes,
            null, null,
            s.contract_version, s.tfm_table, s.fusion_id_column, s.recon_key_sql);

commit;

-- ---------------------------------------------------------------------------
-- Absences (100000030) — Contract v1 registration (design section 5). HDL load
-- = no interface table; base-tier only from ANC_PER_ABS_ENTRIES via
-- HRC_INTEGRATION_KEY_MAP. RECON_KEY = prefixed PERSON_NUMBER || '_ABS'.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000030                                            bip_report_id,
           'Absences'                                           cemli_code,
           'Absence Entry'                                      object_type,
           '/Custom/DMT2/Absences/DMT_ABSENCES_RECON_DM.xdm'    dm_catalog_path,
           '/Custom/DMT2/Absences/DMT_ABSENCES_RECON_RPT.xdo'   report_catalog_path,
           'N/A (HDL)'                                          interface_table,
           'Absence HDL base-table reconciliation (Contract v1)' notes,
           1                                                    contract_version,
           'DMT_ABSENCE_TFM_TBL'                                tfm_table,
           'FUSION_ABSENCE_ENTRY_ID'                            fusion_id_column,
           'DMT_UTIL_PKG.PREFIXED(run_prefix, PERSON_NUMBER, 30) || ''_ABS''' recon_key_sql
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."OBJECT_TYPE"         = s.object_type,
    t."DM_CATALOG_PATH"     = s.dm_catalog_path,
    t."REPORT_CATALOG_PATH" = s.report_catalog_path,
    t."INTERFACE_TABLE"     = s.interface_table,
    t."NOTES"               = s.notes,
    t."CONTRACT_VERSION"    = s.contract_version,
    t."TFM_TABLE"           = s.tfm_table,
    t."FUSION_ID_COLUMN"    = s.fusion_id_column,
    t."RECON_KEY_SQL"       = s.recon_key_sql
when not matched then insert
    ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH",
     "REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES",
     "DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE",
     "CONTRACT_VERSION","TFM_TABLE","FUSION_ID_COLUMN","RECON_KEY_SQL")
    values (s.bip_report_id, s.cemli_code, s.object_type, s.dm_catalog_path,
            s.report_catalog_path, s.interface_table, sysdate, s.notes,
            null, null,
            s.contract_version, s.tfm_table, s.fusion_id_column, s.recon_key_sql);

commit;

-- ---------------------------------------------------------------------------
-- WorkSchedules (100000031) — Contract v1 registration (design section 5).
-- Loads via HDL as WorkPattern; base tier HTS_WORK_PATTERNS_VL (WORK_PATTERN_ID)
-- via HRC_INTEGRATION_KEY_MAP. RECON_KEY = prefixed WORK_SCHEDULE_NAME.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000031                                                   bip_report_id,
           'WorkSchedules'                                             cemli_code,
           'Work Schedule'                                             object_type,
           '/Custom/DMT2/WorkSchedules/DMT_WORKSCHEDULES_RECON_DM.xdm' dm_catalog_path,
           '/Custom/DMT2/WorkSchedules/DMT_WORKSCHEDULES_RECON_RPT.xdo' report_catalog_path,
           'N/A (HDL)'                                                 interface_table,
           'Work Schedule HDL base-table reconciliation (Contract v1)' notes,
           1                                                           contract_version,
           'DMT_WORK_SCHED_TFM_TBL'                                    tfm_table,
           'FUSION_SCHEDULE_ID'                                        fusion_id_column,
           'DMT_UTIL_PKG.PREFIXED(run_prefix, WORK_SCHEDULE_NAME, 240)' recon_key_sql
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."OBJECT_TYPE"         = s.object_type,
    t."DM_CATALOG_PATH"     = s.dm_catalog_path,
    t."REPORT_CATALOG_PATH" = s.report_catalog_path,
    t."INTERFACE_TABLE"     = s.interface_table,
    t."NOTES"               = s.notes,
    t."CONTRACT_VERSION"    = s.contract_version,
    t."TFM_TABLE"           = s.tfm_table,
    t."FUSION_ID_COLUMN"    = s.fusion_id_column,
    t."RECON_KEY_SQL"       = s.recon_key_sql
when not matched then insert
    ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH",
     "REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES",
     "DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE",
     "CONTRACT_VERSION","TFM_TABLE","FUSION_ID_COLUMN","RECON_KEY_SQL")
    values (s.bip_report_id, s.cemli_code, s.object_type, s.dm_catalog_path,
            s.report_catalog_path, s.interface_table, sysdate, s.notes,
            null, null,
            s.contract_version, s.tfm_table, s.fusion_id_column, s.recon_key_sql);

commit;

-- ---------------------------------------------------------------------------
-- PayrollRelationships (100000033) — Contract v1 registration (design section 5).
-- HDL load = no interface table; base-tier only from PAY_PAY_RELATIONSHIPS_F via
-- HRC_INTEGRATION_KEY_MAP (OBJECT_NAME='PayrollRelationship'). RECON_KEY = prefixed
-- PERSON_NUMBER || '_PAYREL' (also the .dat SourceSystemId and the report
-- RECORD_KEY). The when-not-matched insert makes this block self-contained;
-- appended at EOF so the union merge stays append-safe.
-- Verified live 2026-09-16 (fin_impl): HRC_INTEGRATION_KEY_MAP.SURROGATE_ID ==
-- PAY_PAY_RELATIONSHIPS_F.PAYROLL_RELATIONSHIP_ID (a real base-table id).
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000033                                                                  bip_report_id,
           'PayrollRelationships'                                                     cemli_code,
           'Payroll Relationship'                                                     object_type,
           '/Custom/DMT2/PayrollRelationships/DMT_PAYROLLRELATIONSHIPS_RECON_DM.xdm'  dm_catalog_path,
           '/Custom/DMT2/PayrollRelationships/DMT_PAYROLLRELATIONSHIPS_RECON_RPT.xdo' report_catalog_path,
           'N/A (HDL)'                                                                interface_table,
           'Payroll Relationship base-table VERIFIER (Contract v1). 2026-09-17: '
             || 'PayrollRelationships retired as a standalone HDL load (the payroll '
             || 'relationship is auto-created at hire by the Worker load). This report '
             || 'is kept read-only to verify a loaded worker gets an auto-created row '
             || 'in PAY_PAY_RELATIONSHIPS_F; no HDL load is submitted for it.'         notes,
           1                                                                          contract_version,
           'DMT_PAY_REL_TFM_TBL'                                                      tfm_table,
           'FUSION_PAYROLL_RELATIONSHIP_ID'                                           fusion_id_column,
           'DMT_UTIL_PKG.PREFIXED(run_prefix, PERSON_NUMBER, 30) || ''_PAYREL''' recon_key_sql
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."OBJECT_TYPE"         = s.object_type,
    t."DM_CATALOG_PATH"     = s.dm_catalog_path,
    t."REPORT_CATALOG_PATH" = s.report_catalog_path,
    t."INTERFACE_TABLE"     = s.interface_table,
    t."NOTES"               = s.notes,
    t."CONTRACT_VERSION"    = s.contract_version,
    t."TFM_TABLE"           = s.tfm_table,
    t."FUSION_ID_COLUMN"    = s.fusion_id_column,
    t."RECON_KEY_SQL"       = s.recon_key_sql
when not matched then insert
    ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH",
     "REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES",
     "DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE",
     "CONTRACT_VERSION","TFM_TABLE","FUSION_ID_COLUMN","RECON_KEY_SQL")
    values (s.bip_report_id, s.cemli_code, s.object_type, s.dm_catalog_path,
            s.report_catalog_path, s.interface_table, sysdate, s.notes,
            null, null,
            s.contract_version, s.tfm_table, s.fusion_id_column, s.recon_key_sql);

commit;

-- ---------------------------------------------------------------------------
-- Assignments (100000032) — Contract v1 registration (design section 5).
-- RE-HOMED 2026-09-17: Assignments is no longer a standalone pipeline object.
-- WorkTerms + Assignment are components of the Worker business object, loaded in
-- the ONE Worker.dat. This report row is RETAINED (still keyed CEMLI_CODE
-- 'Assignments') as the assignment-component recon report: the Worker reconcile
-- path now invokes DMT_ASSIGNMENT_RESULTS_PKG, which looks this report up by the
-- 'Assignments' key and applies the two base tiers to DMT_WORK_REL_TFM_TBL /
-- DMT_ASSIGNMENT_TFM_TBL. It is kept as its own row (rather than merged into the
-- Workers report 100000027) so the shared parser DMT_RECON_CONTRACT_PKG.FETCH_ROWS
-- resolves exactly one report per CEMLI key. The row is no longer a queue object
-- (its pipeline_def membership + dispatch rows were retired); it is a report
-- definition only. HDL load = no interface table. The report returns two base
-- tiers (OBJECT_TYPE discriminator), applied to the matching TFM table statically:
--   OBJECT_TYPE='WorkRelationship' -> DMT_WORK_REL_TFM_TBL, base tier
--       PER_PERIODS_OF_SERVICE, FUSION_PERSON_ID = PERSON_ID, RECON_KEY
--       '<prefixed PERSON_NUMBER>_POS'.
--   OBJECT_TYPE='Assignment'       -> DMT_ASSIGNMENT_TFM_TBL, base tier
--       PER_ALL_ASSIGNMENTS_M, FUSION_ASSIGNMENT_ID = ASSIGNMENT_ID, RECON_KEY
--       '<ASSIGNMENT_NUMBER>_ASG'.
-- Both tie to their base row through HRC_INTEGRATION_KEY_MAP (verified live
-- 2026-09-16). The single-valued TFM_TABLE/FUSION_ID_COLUMN/RECON_KEY_SQL
-- registry columns carry the primary Assignment tier (the shared parser
-- DMT_RECON_CONTRACT_PKG.FETCH_ROWS reads only CONTRACT_VERSION + the run PREFIX;
-- the static APPLY in the reconciler handles both TFM tables). The
-- when-not-matched insert makes this self-contained.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000032                                                    bip_report_id,
           'Assignments'                                                cemli_code,
           'Assignment'                                                 object_type,
           '/Custom/DMT2/Assignments/DMT_ASSIGNMENTS_RECON_DM.xdm'      dm_catalog_path,
           '/Custom/DMT2/Assignments/DMT_ASSIGNMENTS_RECON_RPT.xdo'     report_catalog_path,
           'N/A (HDL)'                                                  interface_table,
           'Assignment HDL base-table reconciliation (Contract v1). ONE report, '
             || 'two base tiers via OBJECT_TYPE: WorkRelationship '
             || '(DMT_WORK_REL_TFM_TBL <- PER_PERIODS_OF_SERVICE) and Assignment '
             || '(DMT_ASSIGNMENT_TFM_TBL <- PER_ALL_ASSIGNMENTS_M).'    notes,
           1                                                            contract_version,
           'DMT_ASSIGNMENT_TFM_TBL'                                     tfm_table,
           'FUSION_ASSIGNMENT_ID'                                       fusion_id_column,
           'ASSIGNMENT_NUMBER || ''_ASG'' -- assignment: unprefixed source number + suffix (prefix already in source); WorkRelationship tier uses DMT_UTIL_PKG.PREFIXED(run_prefix, PERSON_NUMBER, 30) || ''_POS''' recon_key_sql
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."OBJECT_TYPE"         = s.object_type,
    t."DM_CATALOG_PATH"     = s.dm_catalog_path,
    t."REPORT_CATALOG_PATH" = s.report_catalog_path,
    t."INTERFACE_TABLE"     = s.interface_table,
    t."NOTES"               = s.notes,
    t."CONTRACT_VERSION"    = s.contract_version,
    t."TFM_TABLE"           = s.tfm_table,
    t."FUSION_ID_COLUMN"    = s.fusion_id_column,
    t."RECON_KEY_SQL"       = s.recon_key_sql
when not matched then insert
    ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH",
     "REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES",
     "DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE",
     "CONTRACT_VERSION","TFM_TABLE","FUSION_ID_COLUMN","RECON_KEY_SQL")
    values (s.bip_report_id, s.cemli_code, s.object_type, s.dm_catalog_path,
            s.report_catalog_path, s.interface_table, sysdate, s.notes,
            null, null,
            s.contract_version, s.tfm_table, s.fusion_id_column, s.recon_key_sql);

commit;

-- ---------------------------------------------------------------------------
-- BenParticipant (100000038) — Contract v1 registration (design section 5).
-- Follows the Workers template exactly: the four Contract v1 columns
-- (CONTRACT_VERSION, TFM_TABLE, FUSION_ID_COLUMN, RECON_KEY_SQL) drive the
-- shared parser DMT_RECON_CONTRACT_PKG.FETCH_ROWS. Kept in its own MERGE so this
-- block also converges the Contract v1 columns on an existing row. BenParticipant
-- loads via HDL as the PersonBenefitBalance business object, so there is no
-- interface table (INTERFACE_TABLE = 'N/A (HDL)'); reconciliation is base-tier
-- only, confirming each record in HRC_INTEGRATION_KEY_MAP
-- (OBJECT_NAME='PersonBenefitBalance'). RECON_KEY = the prefixed PERSON_NUMBER
-- concatenated with '_BENENRL' (also the .dat SourceSystemId and the report
-- RECORD_KEY). The when-not-matched insert makes this self-contained.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000038                                                        bip_report_id,
           'BenParticipant'                                                 cemli_code,
           'Participant Enrollment'                                         object_type,
           '/Custom/DMT2/BenParticipant/DMT_BENPARTICIPANT_RECON_DM.xdm'    dm_catalog_path,
           '/Custom/DMT2/BenParticipant/DMT_BENPARTICIPANT_RECON_RPT.xdo'   report_catalog_path,
           'N/A (HDL)'                                                      interface_table,
           'BenParticipant HDL base-table reconciliation (Contract v1)'     notes,
           1                                                                contract_version,
           'DMT_BEN_PARTIC_TFM_TBL'                                         tfm_table,
           'FUSION_PARTICIPANT_ID'                                          fusion_id_column,
           'DMT_UTIL_PKG.PREFIXED(run_prefix, PERSON_NUMBER, 30) || ''_BENENRL''' recon_key_sql
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."OBJECT_TYPE"         = s.object_type,
    t."DM_CATALOG_PATH"     = s.dm_catalog_path,
    t."REPORT_CATALOG_PATH" = s.report_catalog_path,
    t."INTERFACE_TABLE"     = s.interface_table,
    t."NOTES"               = s.notes,
    t."CONTRACT_VERSION"    = s.contract_version,
    t."TFM_TABLE"           = s.tfm_table,
    t."FUSION_ID_COLUMN"    = s.fusion_id_column,
    t."RECON_KEY_SQL"       = s.recon_key_sql
when not matched then insert
    ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH",
     "REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES",
     "DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE",
     "CONTRACT_VERSION","TFM_TABLE","FUSION_ID_COLUMN","RECON_KEY_SQL")
    values (s.bip_report_id, s.cemli_code, s.object_type, s.dm_catalog_path,
            s.report_catalog_path, s.interface_table, sysdate, s.notes,
            null, null,
            s.contract_version, s.tfm_table, s.fusion_id_column, s.recon_key_sql);

commit;
-- WORKSCHEDULES_ANCHOR (do not remove) — new Contract v1 HDL registrations
-- are appended AFTER this WorkSchedules block (union-merge, append-only at EOF).

-- ---------------------------------------------------------------------------
-- BenDependent (100000039) — Contract v1 registration (design section 5).
-- Loads via HDL as the PersonBenefitBalance object (PersonBenefitBalance.dat —
-- the shared discriminator for all three benefit sub-objects; DependentBenefitBalance
-- is NOT a valid discriminator, see DMT_BEN_DEPEND_HDL_GEN_PKG). No interface table
-- (INTERFACE_TABLE = 'N/A (HDL)'); base tier only from the HCM Benefits base table
-- BEN_PER_BNFTS_BAL_F (PER_BNFTS_BAL_ID) reached via HRC_INTEGRATION_KEY_MAP
-- (OBJECT_NAME='PersonBenefitBalance', SURROGATE_ID == PER_BNFTS_BAL_ID; join proven
-- live 2026-09-16 with --cred fin_impl). RECON_KEY = prefixed PERSON_NUMBER ||
-- '_BENDEP' (also the .dat SourceSystemId and the report RECORD_KEY). The
-- when-not-matched insert makes this block self-contained. Appended after the
-- WorkSchedules block (union-merge, append-only at EOF).
-- Blocker: employee benefit enrollment is not configured on the demo instance, so
-- our '_BENDEP' records are rejected upstream and none reach the base table yet
-- (documented BLOCKER, objects/Benefits/README.md); the report is correct and its
-- shape is proven live.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000039                                                       bip_report_id,
           'BenDependent'                                                  cemli_code,
           'Dependent Enrollment'                                          object_type,
           '/Custom/DMT2/BenDependent/DMT_BENDEPENDENT_RECON_DM.xdm'       dm_catalog_path,
           '/Custom/DMT2/BenDependent/DMT_BENDEPENDENT_RECON_RPT.xdo'      report_catalog_path,
           'N/A (HDL)'                                                     interface_table,
           'BenDependent HDL base-table reconciliation (Contract v1)'      notes,
           1                                                               contract_version,
           'DMT_BEN_DEPEND_TFM_TBL'                                        tfm_table,
           'FUSION_DEPENDENT_ID'                                           fusion_id_column,
           'DMT_UTIL_PKG.PREFIXED(run_prefix, PERSON_NUMBER, 30) || ''_BENDEP''' recon_key_sql
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."OBJECT_TYPE"         = s.object_type,
    t."DM_CATALOG_PATH"     = s.dm_catalog_path,
    t."REPORT_CATALOG_PATH" = s.report_catalog_path,
    t."INTERFACE_TABLE"     = s.interface_table,
    t."NOTES"               = s.notes,
    t."CONTRACT_VERSION"    = s.contract_version,
    t."TFM_TABLE"           = s.tfm_table,
    t."FUSION_ID_COLUMN"    = s.fusion_id_column,
    t."RECON_KEY_SQL"       = s.recon_key_sql
when not matched then insert
    ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH",
     "REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES",
     "DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE",
     "CONTRACT_VERSION","TFM_TABLE","FUSION_ID_COLUMN","RECON_KEY_SQL")
    values (s.bip_report_id, s.cemli_code, s.object_type, s.dm_catalog_path,
            s.report_catalog_path, s.interface_table, sysdate, s.notes,
            null, null,
            s.contract_version, s.tfm_table, s.fusion_id_column, s.recon_key_sql);

commit;

-- ---------------------------------------------------------------------------
-- BenBeneficiary (100000040) — Contract v1 registration (design section 5).
-- Follows the Workers/Salaries template exactly: the four Contract v1 columns
-- (CONTRACT_VERSION, TFM_TABLE, FUSION_ID_COLUMN, RECON_KEY_SQL) drive the shared
-- parser DMT_RECON_CONTRACT_PKG.FETCH_ROWS. Kept in its own MERGE so this block
-- also converges the Contract v1 columns on an existing row. HDL load = no
-- interface table (INTERFACE_TABLE = 'N/A (HDL)'). The object loads via HDL under
-- the discriminator PersonBenefitBalance (DMT_BEN_BENFY_HDL_GEN_PKG); base-tier
-- proof reads the HRC_INTEGRATION_KEY_MAP row (OBJECT_NAME='PersonBenefitBalance')
-- whose SURROGATE_ID is the Fusion base-table id. RECON_KEY = the prefixed
-- PERSON_NUMBER || '_BENBNFY' (also the .dat SourceSystemId and the report
-- RECORD_KEY). Verified live 2026-09-16: HRC_INTEGRATION_KEY_MAP holds
-- HRC_SQLLOADER-owned '<prefix>...\_BENBNFY' rows whose SURROGATE_ID is a real
-- Fusion id (e.g. 67936DMTBNFY001_BENBNFY -> 300000331552758). The
-- when-not-matched insert makes this self-contained.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000040                                                        bip_report_id,
           'BenBeneficiary'                                                 cemli_code,
           'Beneficiary Enrollment'                                         object_type,
           '/Custom/DMT2/BenBeneficiary/DMT_BENBENEFICIARY_RECON_DM.xdm'    dm_catalog_path,
           '/Custom/DMT2/BenBeneficiary/DMT_BENBENEFICIARY_RECON_RPT.xdo'   report_catalog_path,
           'N/A (HDL)'                                                      interface_table,
           'BenBeneficiary HDL base-table reconciliation (Contract v1)'     notes,
           1                                                                contract_version,
           'DMT_BEN_BENFY_TFM_TBL'                                          tfm_table,
           'FUSION_BENEFICIARY_ID'                                          fusion_id_column,
           'DMT_UTIL_PKG.PREFIXED(run_prefix, PERSON_NUMBER, 30) || ''_BENBNFY''' recon_key_sql
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."OBJECT_TYPE"         = s.object_type,
    t."DM_CATALOG_PATH"     = s.dm_catalog_path,
    t."REPORT_CATALOG_PATH" = s.report_catalog_path,
    t."INTERFACE_TABLE"     = s.interface_table,
    t."NOTES"               = s.notes,
    t."CONTRACT_VERSION"    = s.contract_version,
    t."TFM_TABLE"           = s.tfm_table,
    t."FUSION_ID_COLUMN"    = s.fusion_id_column,
    t."RECON_KEY_SQL"       = s.recon_key_sql
when not matched then insert
    ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH",
     "REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES",
     "DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE",
     "CONTRACT_VERSION","TFM_TABLE","FUSION_ID_COLUMN","RECON_KEY_SQL")
    values (s.bip_report_id, s.cemli_code, s.object_type, s.dm_catalog_path,
            s.report_catalog_path, s.interface_table, sysdate, s.notes,
            null, null,
            s.contract_version, s.tfm_table, s.fusion_id_column, s.recon_key_sql);

commit;

-- ---------------------------------------------------------------------------
-- W2Balances (100000035) — Contract v1 registration (design section 5).
-- Loads via HDL as PayrollBalanceInitialization; base tier PAY_BAL_BATCH_HEADERS
-- (BATCH_ID) matched through HRC_INTEGRATION_KEY_MAP (object InitializeBalanceBatch-
-- Header, SOURCE_SYSTEM_OWNER='HRC_SQLLOADER', SURROGATE_ID=BATCH_ID).
-- RECON_KEY = prefixed PERSON_NUMBER || '_BAL' (the .dat SourceSystemId).
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000035                                                    bip_report_id,
           'W2Balances'                                                 cemli_code,
           'Balance Initialization'                                     object_type,
           '/Custom/DMT2/W2Balances/DMT_W2BALANCES_RECON_DM.xdm'        dm_catalog_path,
           '/Custom/DMT2/W2Balances/DMT_W2BALANCES_RECON_RPT.xdo'       report_catalog_path,
           'N/A (HDL)'                                                  interface_table,
           'W2Balances HDL base-table reconciliation (Contract v1)'     notes,
           1                                                            contract_version,
           'DMT_W2_BAL_TFM_TBL'                                         tfm_table,
           'FUSION_BALANCE_ID'                                          fusion_id_column,
           'DMT_UTIL_PKG.PREFIXED(run_prefix, PERSON_NUMBER, 30) || ''_BAL''' recon_key_sql
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."OBJECT_TYPE"         = s.object_type,
    t."DM_CATALOG_PATH"     = s.dm_catalog_path,
    t."REPORT_CATALOG_PATH" = s.report_catalog_path,
    t."INTERFACE_TABLE"     = s.interface_table,
    t."NOTES"               = s.notes,
    t."CONTRACT_VERSION"    = s.contract_version,
    t."TFM_TABLE"           = s.tfm_table,
    t."FUSION_ID_COLUMN"    = s.fusion_id_column,
    t."RECON_KEY_SQL"       = s.recon_key_sql
when not matched then insert
    ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH",
     "REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES",
     "DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE",
     "CONTRACT_VERSION","TFM_TABLE","FUSION_ID_COLUMN","RECON_KEY_SQL")
    values (s.bip_report_id, s.cemli_code, s.object_type, s.dm_catalog_path,
            s.report_catalog_path, s.interface_table, sysdate, s.notes,
            null, null,
            s.contract_version, s.tfm_table, s.fusion_id_column, s.recon_key_sql);

commit;

-- ---------------------------------------------------------------------------
-- TalentProfiles (100000036) — Contract v1 registration (design section 5).
-- Follows the Salaries template: HDL load = no interface table
-- (INTERFACE_TABLE = 'N/A (HDL)'); base tier only from HRT_PROFILES_B via
-- HRC_INTEGRATION_KEY_MAP. The four Contract v1 columns (CONTRACT_VERSION,
-- TFM_TABLE, FUSION_ID_COLUMN, RECON_KEY_SQL) drive the shared parser
-- DMT_RECON_CONTRACT_PKG.FETCH_ROWS. TFM_TABLE / FUSION_ID_COLUMN register the
-- PARENT TalentProfile record (its primary TFM table), exactly as Workers
-- registers only its primary DMT_WORKER_TFM_TBL; the child ProfileItem keeps
-- its per-record HDL error path.
--
-- Verified live 2026-09-16 (fin_impl):
--   HRC_INTEGRATION_KEY_MAP.OBJECT_NAME='Profile'  (parent profile; children are
--     'ProfileItem') — our HDL writes SourceSystemId = prefixed PERSON_NUMBER ||
--     '_TPROF' for the parent.
--   HRC_INTEGRATION_KEY_MAP.SURROGATE_ID == HRT_PROFILES_B.PROFILE_ID (base-table id).
-- RECON_KEY = prefixed PERSON_NUMBER || '_TPROF' (also the .dat SourceSystemId and
-- the report RECORD_KEY). The when-not-matched insert makes this self-contained.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000036                                                        bip_report_id,
           'TalentProfiles'                                                 cemli_code,
           'Talent Profile'                                                 object_type,
           '/Custom/DMT2/TalentProfiles/DMT_TALENTPROFILES_RECON_DM.xdm'    dm_catalog_path,
           '/Custom/DMT2/TalentProfiles/DMT_TALENTPROFILES_RECON_RPT.xdo'   report_catalog_path,
           'N/A (HDL)'                                                      interface_table,
           'Talent profile HDL base-table reconciliation (Contract v1)'     notes,
           1                                                                contract_version,
           'DMT_TALENT_PROF_TFM_TBL'                                        tfm_table,
           'FUSION_PROFILE_ID'                                              fusion_id_column,
           'DMT_UTIL_PKG.PREFIXED(run_prefix, PERSON_NUMBER, 30) || ''_TPROF''' recon_key_sql
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."OBJECT_TYPE"         = s.object_type,
    t."DM_CATALOG_PATH"     = s.dm_catalog_path,
    t."REPORT_CATALOG_PATH" = s.report_catalog_path,
    t."INTERFACE_TABLE"     = s.interface_table,
    t."NOTES"               = s.notes,
    t."CONTRACT_VERSION"    = s.contract_version,
    t."TFM_TABLE"           = s.tfm_table,
    t."FUSION_ID_COLUMN"    = s.fusion_id_column,
    t."RECON_KEY_SQL"       = s.recon_key_sql
when not matched then insert
    ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH",
     "REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES",
     "DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE",
     "CONTRACT_VERSION","TFM_TABLE","FUSION_ID_COLUMN","RECON_KEY_SQL")
    values (s.bip_report_id, s.cemli_code, s.object_type, s.dm_catalog_path,
            s.report_catalog_path, s.interface_table, sysdate, s.notes,
            null, null,
            s.contract_version, s.tfm_table, s.fusion_id_column, s.recon_key_sql);

commit;

-- ---------------------------------------------------------------------------
-- PerfEvaluations (100000037) — Contract v1 registration (design section 5).
-- Loads via HDL as the GoalPlan object (GoalPlan.dat — see
-- db/packages/dmt_perf_eval_hdl_gen_pkg.pkb.sql); a loaded performance evaluation
-- lives in Fusion as a goal plan definition. Base tier HRG_GOAL_PLANS_VL
-- (GOAL_PLAN_ID as FUSION_ID), matched by the run prefix against GOAL_PLAN_NAME.
-- Verified live 2026-09-16 (--cred fin_impl): object_name 'GoalPlan' exists in
-- HRC_INTEGRATION_KEY_MAP; HRG_GOAL_PLANS_VL exposes GOAL_PLAN_ID + GOAL_PLAN_NAME;
-- migrated DMT goal plans carry the run prefix in GOAL_PLAN_NAME (e.g.
-- 300000331553042 '43426 DMT Goal Plan A'); no HRC_SQLLOADER / '_GOAL'
-- source_system_id rows exist, so base matching is by prefix, not SourceSystemId.
-- RECON_KEY = the prefixed DOCUMENT_NAME (= the goal plan name = report RECORD_KEY).
-- FUSION_ID_COLUMN = FUSION_EVALUATION_ID on DMT_PERF_EVAL_TFM_TBL. The
-- when-not-matched insert makes this block self-contained.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000037                                                        bip_report_id,
           'PerfEvaluations'                                                cemli_code,
           'Performance Evaluation'                                         object_type,
           '/Custom/DMT2/PerfEvaluations/DMT_PERFEVALUATIONS_RECON_DM.xdm'  dm_catalog_path,
           '/Custom/DMT2/PerfEvaluations/DMT_PERFEVALUATIONS_RECON_RPT.xdo' report_catalog_path,
           'N/A (HDL)'                                                      interface_table,
           'Performance evaluation HDL base-table reconciliation (Contract v1)' notes,
           1                                                                contract_version,
           'DMT_PERF_EVAL_TFM_TBL'                                          tfm_table,
           'FUSION_EVALUATION_ID'                                           fusion_id_column,
           'DMT_UTIL_PKG.PREFIXED(run_prefix, DOCUMENT_NAME, 240) -- prefixed goal plan name' recon_key_sql
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."OBJECT_TYPE"         = s.object_type,
    t."DM_CATALOG_PATH"     = s.dm_catalog_path,
    t."REPORT_CATALOG_PATH" = s.report_catalog_path,
    t."INTERFACE_TABLE"     = s.interface_table,
    t."NOTES"               = s.notes,
    t."CONTRACT_VERSION"    = s.contract_version,
    t."TFM_TABLE"           = s.tfm_table,
    t."FUSION_ID_COLUMN"    = s.fusion_id_column,
    t."RECON_KEY_SQL"       = s.recon_key_sql
when not matched then insert
    ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH",
     "REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES",
     "DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE",
     "CONTRACT_VERSION","TFM_TABLE","FUSION_ID_COLUMN","RECON_KEY_SQL")
    values (s.bip_report_id, s.cemli_code, s.object_type, s.dm_catalog_path,
            s.report_catalog_path, s.interface_table, sysdate, s.notes,
            null, null,
            s.contract_version, s.tfm_table, s.fusion_id_column, s.recon_key_sql);

commit;

-- ---------------------------------------------------------------------------
-- UnitsOfMeasure (100000041) — NEW reconciliation standard (DMT_DESIGN.html,
-- PROPOSED 2026-09): reconciliation is a BIP report over the Fusion BASE table
-- that returns the base-table surrogate id. UOM loads via REST POST to the
-- unitsOfMeasure resource, but LOADED is now driven by a positive hit in the
-- base table INV_UNITS_OF_MEASURE_B: DMT_INV_UOM_RESULTS_PKG runs the report
-- DMT_UOM_RECON_RPT over the run's UOM codes and, for each code found, marks the
-- TFM row LOADED with FUSION_UOM_ID = UNIT_OF_MEASURE_ID (== the REST UOMId).
-- INTERFACE_TABLE = 'N/A (REST)' — there is no interface table; the report reads
-- the base table directly. The report is keyed by CEMLI_CODE 'UnitsOfMeasure'
-- (the reconciler passes p_cemli_code => 'UnitsOfMeasure' to RUN_BIP_REPORT).
-- Config UOM codes are 3 characters and are NOT run-prefixed (a numeric prefix
-- would not fit UOM_CODE VARCHAR2(3)); the single parameter P_UOM_CODES carries
-- the exact comma-delimited code list. This reconciler uses its own RECORD_KEY/
-- BASE parser (not the shared Contract v1 parser), so the Contract v1 columns
-- are left NULL. The when-not-matched insert makes this block self-contained.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000041                                                     bip_report_id,
           'UnitsOfMeasure'                                              cemli_code,
           'Unit of Measure'                                             object_type,
           '/Custom/DMT2/UnitsOfMeasure/DMT_UOM_RECON_DM.xdm'            dm_catalog_path,
           '/Custom/DMT2/UnitsOfMeasure/DMT_UOM_RECON_RPT.xdo'           report_catalog_path,
           'N/A (REST)'                                                  interface_table,
           'Units of Measure base-table reconciliation (new recon standard). '
             || 'REST POST loads the UOM; LOADED is confirmed by a hit in '
             || 'INV_UNITS_OF_MEASURE_B, capturing FUSION_UOM_ID = UNIT_OF_MEASURE_ID.' notes
    from dual
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

-- ---------------------------------------------------------------------------
-- UnitsOfMeasure — Contract v1 registration + generic recon engine wiring.
-- The deployed report DMT_UOM_RECON_RPT already emits the nine standard
-- Contract v1 columns (single group G_1, see bip/UnitsOfMeasure/DMT_UOM_RECON_DM.xdm),
-- so the generic engine (DMT_RECON_ENGINE_PKG) can page + parse + stage it, then
-- dispatch this object's own thin static apply, DMT_INV_UOM_RESULTS_PKG.APPLY_UOM,
-- through the sanctioned invoke_registered site. APPLY_UOM MERGEs from
-- DMT_RECON_STAGE_GTT into the literally-named DMT_INV_UOM_TFM_TBL with STATIC SQL.
-- RECON_KEY = UOM_CODE (the report RECORD_KEY matched to TFM.UOM_CODE).
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 'UnitsOfMeasure'                                       cemli_code,
           1                                                      contract_version,
           'DMT_INV_UOM_TFM_TBL'                                  tfm_table,
           'FUSION_UOM_ID'                                        fusion_id_column,
           'UOM code reconciliation key (report RECORD_KEY matched to TFM.UOM_CODE)' recon_key_sql,
           'DMT_INV_UOM_RESULTS_PKG.APPLY_UOM'                    apply_proc
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."CONTRACT_VERSION" = s.contract_version,
    t."TFM_TABLE"        = s.tfm_table,
    t."FUSION_ID_COLUMN" = s.fusion_id_column,
    t."RECON_KEY_SQL"    = s.recon_key_sql,
    t."APPLY_PROC"       = s.apply_proc;

commit;

-- ---------------------------------------------------------------------------
-- ValueSets (100000042) — NEW reconciliation standard (DMT_DESIGN.html,
-- PROPOSED 2026-09): reconciliation is a BIP report over the Fusion BASE tables
-- that returns the base-table surrogate id. ValueSets is a two-object load — a
-- value set, then its child values — so its report reads BOTH base tables in a
-- single call and returns one flat row list keyed by SOURCE_TYPE:
--   * SET   rows  from FND_VS_VALUE_SETS: RECORD_KEY = VALUE_SET_CODE,
--                 FUSION_ID = VALUE_SET_ID (-> DMT_FND_VS_SET_TFM_TBL.FUSION_VALUE_SET_ID).
--   * VALUE rows  from FND_VS_VALUES_B joined to FND_VS_VALUE_SETS on VALUE_SET_ID:
--                 RECORD_KEY = VALUE_SET_CODE || '^' || VALUE, FUSION_ID = VALUE_ID
--                 (-> DMT_FND_VS_VALUE_TFM_TBL.FUSION_VALUE_ID).
-- DMT_FND_VS_RESULTS_PKG runs DMT_VS_RECON_RPT and, for each row found, marks the
-- matching TFM row LOADED with the real surrogate id. INTERFACE_TABLE = 'N/A (REST)'
-- — there is no interface table; the report reads the base tables directly. The
-- report is keyed by CEMLI_CODE 'ValueSets' (the reconciler passes
-- p_cemli_code => 'ValueSets' to RUN_BIP_REPORT). Config codes are NOT run-prefixed;
-- the two parameters P_SET_CODES and P_VALUE_KEYS carry the exact code / composite-key
-- lists for this run. This reconciler uses its own RECORD_KEY/SOURCE_TYPE parser
-- (not the shared Contract v1 parser), so the Contract v1 columns are left NULL.
-- The when-not-matched insert makes this block self-contained.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000042                                                     bip_report_id,
           'ValueSets'                                                   cemli_code,
           'Value Set'                                                   object_type,
           '/Custom/DMT2/ValueSets/DMT_VS_RECON_DM.xdm'                  dm_catalog_path,
           '/Custom/DMT2/ValueSets/DMT_VS_RECON_RPT.xdo'                 report_catalog_path,
           'N/A (REST)'                                                  interface_table,
           'Value Sets base-table reconciliation (new recon standard). '
             || 'REST POST loads each set then its child values; LOADED is confirmed '
             || 'by a hit in FND_VS_VALUE_SETS (FUSION_VALUE_SET_ID = VALUE_SET_ID) '
             || 'and FND_VS_VALUES_B (FUSION_VALUE_ID = VALUE_ID). One report, two '
             || 'params: P_SET_CODES and P_VALUE_KEYS.' notes
    from dual
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

-- ---------------------------------------------------------------------------
-- CashBanks (100000046) — NEW reconciliation standard (DMT_DESIGN.html,
-- PROPOSED 2026-09): reconciliation is a BIP report over the Fusion BASE tables
-- that returns the base-table surrogate id. Cash Management banks/branches/
-- accounts load via REST POST to cashBanks/cashBankBranches/cashBankAccounts,
-- but LOADED is now driven by a positive hit in the base tables:
-- DMT_CE_BANK_RESULTS_PKG runs the report DMT_CEBANK_RECON_RPT and, for each
-- bank name found in CE_BANKS_V, marks the bank TFM row LOADED with
-- FUSION_BANK_PARTY_ID = BANK_PARTY_ID; for each branch found in
-- CE_BANK_BRANCHES_V (matched by branch name + parent bank name), marks the
-- branch LOADED with FUSION_BRANCH_PARTY_ID = BRANCH_PARTY_ID; for each account
-- found in CE_BANK_ACCOUNTS, marks the account LOADED with FUSION_BANK_ACCOUNT_ID
-- = BANK_ACCOUNT_ID. INTERFACE_TABLE = 'N/A (REST)' — there is no interface
-- table; the report reads the base views/table directly. Keyed by CEMLI_CODE
-- 'CashBanks' (the reconciler passes p_cemli_code => 'CashBanks' to
-- RUN_BIP_REPORT). Natural keys are NOT run-prefixed; three parameters
-- P_BANK_NAMES / P_BRANCH_NAMES / P_ACCT_NAMES carry the exact lists per tier.
-- This reconciler uses its own RECORD_KEY/SOURCE_TYPE parser (not the shared
-- Contract v1 parser), so the Contract v1 columns are left NULL. The
-- when-not-matched insert makes this block self-contained.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000046                                                     bip_report_id,
           'CashBanks'                                                   cemli_code,
           'Cash Management Banks'                                       object_type,
           '/Custom/DMT2/CashBanks/DMT_CEBANK_RECON_DM.xdm'             dm_catalog_path,
           '/Custom/DMT2/CashBanks/DMT_CEBANK_RECON_RPT.xdo'            report_catalog_path,
           'N/A (REST)'                                                  interface_table,
           'Cash Management banks/branches/accounts base-table reconciliation '
             || '(new recon standard). REST POST loads each tier; LOADED is '
             || 'confirmed by a hit in CE_BANKS_V (FUSION_BANK_PARTY_ID), '
             || 'CE_BANK_BRANCHES_V (FUSION_BRANCH_PARTY_ID) and CE_BANK_ACCOUNTS '
             || '(FUSION_BANK_ACCOUNT_ID). One report, three params: P_BANK_NAMES, '
             || 'P_BRANCH_NAMES, P_ACCT_NAMES.' notes
    from dual
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

-- ---------------------------------------------------------------------------
-- PaymentTerms (100000043) — NEW reconciliation standard (DMT_DESIGN.html,
-- PROPOSED 2026-09): reconciliation is a BIP report over the Fusion BASE tables
-- that returns the base-table surrogate id. AP Payment Terms load via REST POST
-- to the standardTerms resource, but LOADED is now driven by a positive hit in
-- the base tables: DMT_AP_PAY_TERM_RESULTS_PKG runs the report
-- DMT_APTERMS_RECON_RPT and, for each header name found in AP_TERMS, marks the
-- header TFM row LOADED with FUSION_TERM_ID = TERM_ID (== the REST TermId); for
-- each installment line found in AP_TERMS_LINES under a confirmed TERM_ID, marks
-- the line TFM row LOADED. INTERFACE_TABLE = 'N/A (REST)' — there is no interface
-- table; the report reads the base tables directly. The report is keyed by
-- CEMLI_CODE 'PaymentTerms' (the reconciler passes p_cemli_code => 'PaymentTerms'
-- to RUN_BIP_REPORT). Term names are NOT run-prefixed; the two parameters
-- P_TERM_NAMES (header names) and P_TERM_IDS (confirmed header TERM_IDs for the
-- line pass) carry the exact lists for this run. This reconciler uses its own
-- RECORD_KEY/SOURCE_TYPE parser (not the shared Contract v1 parser), so the
-- Contract v1 columns are left NULL. The when-not-matched insert makes this
-- block self-contained.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000043                                                     bip_report_id,
           'PaymentTerms'                                                cemli_code,
           'AP Payment Terms'                                            object_type,
           '/Custom/DMT2/APPaymentTerms/DMT_APTERMS_RECON_DM.xdm'        dm_catalog_path,
           '/Custom/DMT2/APPaymentTerms/DMT_APTERMS_RECON_RPT.xdo'       report_catalog_path,
           'N/A (REST)'                                                  interface_table,
           'AP Payment Terms base-table reconciliation (new recon standard). '
             || 'REST POST loads the term then its installment lines; LOADED is '
             || 'confirmed by a hit in AP_TERMS (FUSION_TERM_ID = TERM_ID) and '
             || 'AP_TERMS_LINES. One report, two params: P_TERM_NAMES and P_TERM_IDS.' notes
    from dual
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

-- ---------------------------------------------------------------------------
-- PaymentTerms — Contract v1 registration + generic recon engine wiring.
-- The deployed report DMT_APTERMS_RECON_RPT already emits the nine standard
-- Contract v1 columns (single group G_1, two tiers folded by SOURCE_TYPE
-- BASE/BASE_LINE via UNION ALL — see bip/APPaymentTerms/DMT_APTERMS_RECON_DM.xdm),
-- so the generic engine can page + parse + stage it, then dispatch
-- DMT_AP_PAY_TERM_RESULTS_PKG.APPLY_PAY_TERM. The header/line REST dependency
-- (lines need the confirmed TERM_ID as the child URL key) is handled in the LOAD
-- phase (LOAD_TERMS -> confirm headers -> POST_LINES); the engine's single final
-- reconcile then settles both tiers via APPLY_PAY_TERM. RECON_KEY = term NAME
-- (header) / TERM_ID-SEQUENCE_NUM (line); FUSION_ID = TERM_ID.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 'PaymentTerms'                                         cemli_code,
           1                                                      contract_version,
           'DMT_AP_PAY_TERM_HDR_TFM_TBL,DMT_AP_PAY_TERM_LINE_TFM_TBL' tfm_table,
           'FUSION_TERM_ID'                                       fusion_id_column,
           'term NAME (header) / TERM_ID-SEQUENCE_NUM (line)'     recon_key_sql,
           'DMT_AP_PAY_TERM_RESULTS_PKG.APPLY_PAY_TERM'           apply_proc
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."CONTRACT_VERSION" = s.contract_version,
    t."TFM_TABLE"        = s.tfm_table,
    t."FUSION_ID_COLUMN" = s.fusion_id_column,
    t."RECON_KEY_SQL"    = s.recon_key_sql,
    t."APPLY_PROC"       = s.apply_proc;

commit;

-- ---------------------------------------------------------------------------
-- Lookups (100000044) — NEW reconciliation standard (DMT_DESIGN.html, PROPOSED
-- 2026-09): reconciliation is a BIP report over the Fusion BASE tables.
--
-- SPECIAL CASE — no numeric surrogate id. FND lookups expose ONLY string keys.
-- The types base FND_LOOKUP_TYPES is keyed by LOOKUP_TYPE; the values base
-- FND_LOOKUP_VALUES_B by LOOKUP_TYPE + LOOKUP_CODE. There is NO
-- LOOKUP_TYPE_ID / LOOKUP_ID numeric column (verified live 2026-09). So the
-- report proves EXISTENCE by the string key and returns RECORD_KEY +
-- SOURCE_TYPE ONLY (no FUSION_ID column). DMT_FND_LOOKUP_RESULTS_PKG runs
-- DMT_LOOKUP_RECON_RPT and, for each row found, marks the matching TFM row
-- LOADED while leaving FUSION_LOOKUP_TYPE_ID / FUSION_LOOKUP_ID NULL (there is
-- no id to capture — never fabricated).
--   * TYPE  rows  from FND_LOOKUP_TYPES:    RECORD_KEY = LOOKUP_TYPE
--   * VALUE rows  from FND_LOOKUP_VALUES_B: RECORD_KEY = LOOKUP_TYPE || '^' || LOOKUP_CODE
-- INTERFACE_TABLE = 'N/A (REST)' — there is no interface table; the report reads
-- the base tables directly. Keyed by CEMLI_CODE 'Lookups' (the reconciler passes
-- p_cemli_code => 'Lookups' to RUN_BIP_REPORT). Config codes are NOT run-prefixed;
-- the two params P_TYPE_CODES and P_VALUE_KEYS carry the exact code / composite-key
-- lists for this run. This reconciler uses its own RECORD_KEY/SOURCE_TYPE parser
-- (not the shared Contract v1 parser), so the Contract v1 columns are left NULL.
-- The when-not-matched insert makes this block self-contained.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000044                                                     bip_report_id,
           'Lookups'                                                     cemli_code,
           'Lookup'                                                      object_type,
           '/Custom/DMT2/Lookups/DMT_LOOKUP_RECON_DM.xdm'               dm_catalog_path,
           '/Custom/DMT2/Lookups/DMT_LOOKUP_RECON_RPT.xdo'              report_catalog_path,
           'N/A (REST)'                                                  interface_table,
           'Lookups base-table reconciliation (new recon standard). REST POST '
             || 'loads each lookup type then its child codes; LOADED is confirmed '
             || 'by a hit in FND_LOOKUP_TYPES (RECORD_KEY = LOOKUP_TYPE) and '
             || 'FND_LOOKUP_VALUES_B (RECORD_KEY = LOOKUP_TYPE^LOOKUP_CODE). '
             || 'SPECIAL CASE: FND lookups have NO numeric surrogate id, so the '
             || 'report returns RECORD_KEY + SOURCE_TYPE only and the TFM '
             || 'FUSION_LOOKUP_TYPE_ID / FUSION_LOOKUP_ID columns are left NULL. '
             || 'One report, two params: P_TYPE_CODES and P_VALUE_KEYS.' notes
    from dual
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

-- ---------------------------------------------------------------------------
-- Lookups — Contract v1 registration + generic recon engine wiring.
-- The deployed report DMT_LOOKUP_RECON_RPT already emits the nine standard
-- Contract v1 columns (single group G_1, two tiers folded by OBJECT_TYPE via
-- UNION ALL — see bip/Lookups/DMT_LOOKUP_RECON_DM.xdm), so the generic engine
-- can page + parse + stage it, then dispatch DMT_FND_LOOKUP_RESULTS_PKG
-- .APPLY_LOOKUPS. FND lookups have NO numeric surrogate id, so FUSION_ID_COLUMN
-- is left NULL and APPLY_LOOKUPS marks LOADED on existence (no id captured).
-- RECON_KEY = LOOKUP_TYPE (types) / LOOKUP_TYPE^LOOKUP_CODE (values).
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 'Lookups'                                              cemli_code,
           1                                                      contract_version,
           'DMT_FND_LOOKUP_TYPE_TFM_TBL,DMT_FND_LOOKUP_VALUE_TFM_TBL' tfm_table,
           CAST(NULL AS VARCHAR2(128))                            fusion_id_column,
           'LOOKUP_TYPE (types) / LOOKUP_TYPE^LOOKUP_CODE (values); no numeric surrogate' recon_key_sql,
           'DMT_FND_LOOKUP_RESULTS_PKG.APPLY_LOOKUPS'             apply_proc
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."CONTRACT_VERSION" = s.contract_version,
    t."TFM_TABLE"        = s.tfm_table,
    t."FUSION_ID_COLUMN" = s.fusion_id_column,
    t."RECON_KEY_SQL"    = s.recon_key_sql,
    t."APPLY_PROC"       = s.apply_proc;

commit;

-- ---------------------------------------------------------------------------
-- Taxes / TaxConfig (100000045) — NEW reconciliation standard (DMT_DESIGN.html,
-- PROPOSED 2026-09): reconciliation is a BIP report over the Fusion BASE tables
-- that returns the base-table surrogate id. Taxes is a two-tier config load
-- (tax regimes + tax rates) via REST POST (taxRegimes / taxRates), but LOADED is
-- now driven by a positive hit in the base tables: DMT_ZX_RESULTS_PKG runs the
-- report DMT_ZX_RECON_RPT and, for each regime code found in ZX_REGIMES_B, marks
-- the regime TFM row LOADED with FUSION_TAX_REGIME_ID = TAX_REGIME_ID; for each
-- rate code found in ZX_RATES_B, marks the rate TFM row LOADED with
-- FUSION_TAX_RATE_ID = TAX_RATE_ID. INTERFACE_TABLE = 'N/A (REST)' — there is no
-- interface table; the report reads the base tables directly. The report is
-- keyed by CEMLI_CODE 'TaxConfig' (the reconciler passes p_cemli_code =>
-- 'TaxConfig' to RUN_BIP_REPORT — the registry CEMLI code for the Taxes object).
-- Codes are NOT run-prefixed; the two parameters P_REGIME_CODES and P_RATE_CODES
-- carry the exact lists for this run. This reconciler uses its own
-- RECORD_KEY/SOURCE_TYPE parser (not the shared Contract v1 parser), so the
-- Contract v1 columns are left NULL. The when-not-matched insert makes this
-- block self-contained.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 100000045                                                     bip_report_id,
           'TaxConfig'                                                   cemli_code,
           'Taxes (Regimes + Rates)'                                     object_type,
           '/Custom/DMT2/Taxes/DMT_ZX_RECON_DM.xdm'                      dm_catalog_path,
           '/Custom/DMT2/Taxes/DMT_ZX_RECON_RPT.xdo'                     report_catalog_path,
           'N/A (REST)'                                                  interface_table,
           'Taxes base-table reconciliation (new recon standard). REST POST '
             || 'loads tax regimes then tax rates; LOADED is confirmed by a hit '
             || 'in ZX_REGIMES_B (FUSION_TAX_REGIME_ID = TAX_REGIME_ID) and '
             || 'ZX_RATES_B (FUSION_TAX_RATE_ID = TAX_RATE_ID). One report, two '
             || 'params: P_REGIME_CODES and P_RATE_CODES.' notes
    from dual
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

-- ---------------------------------------------------------------------------
-- GLBalances — Contract v1 registration + generic recon engine wiring.
-- GLBalances is the REFERENCE object for the Option 1 recon engine: its report
-- already conforms to Contract v1 (the nine standard columns), so the generic
-- engine (DMT_RECON_ENGINE_PKG) can page + parse + stage it, then dispatch the
-- object's OWN thin static apply, DMT_GL_RESULTS_PKG.APPLY_GL, through the
-- sanctioned invoke_registered site. APPLY_GL MERGEs from DMT_RECON_STAGE_GTT
-- into the literally-named DMT_GL_INTERFACE_TFM_TBL with STATIC SQL. The four
-- documentation columns describe the object; APPLY_PROC is what the engine
-- actually dispatches. RECON_KEY = prefixed journal key. This MERGE converges
-- the columns on the GLBalances row seeded earlier in this file.
-- ---------------------------------------------------------------------------
merge into "DMT_BIP_REPORT_TBL" t
using (
    select 'GLBalances'                                          cemli_code,
           1                                                     contract_version,
           'DMT_GL_INTERFACE_TFM_TBL'                            tfm_table,
           'FUSION_JE_HEADER_ID'                                 fusion_id_column,
           'prefixed GL journal reconciliation key (report RECORD_KEY matched to TFM.RECON_KEY)' recon_key_sql,
           'DMT_GL_RESULTS_PKG.APPLY_GL'                         apply_proc
    from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."CONTRACT_VERSION" = s.contract_version,
    t."TFM_TABLE"        = s.tfm_table,
    t."FUSION_ID_COLUMN" = s.fusion_id_column,
    t."RECON_KEY_SQL"    = s.recon_key_sql,
    t."APPLY_PROC"       = s.apply_proc;

commit;
