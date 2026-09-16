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
  insert into "DMT_BIP_REPORT_TBL" ("BIP_REPORT_ID","CEMLI_CODE","OBJECT_TYPE","DM_CATALOG_PATH","REPORT_CATALOG_PATH","INTERFACE_TABLE","CREATED_DATE","NOTES","DEEP_LINK_OBJ_TYPE","DEEP_LINK_KEY_TEMPLATE") values (100000016,'GLBalances','GL Balance','/Custom/DMT2/GLBalances/GL_BAL_DM.xdm','/Custom/DMT2/GLBalances/GL_BAL_RPT.xdo','GL_INTERFACE',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'GL journal import reconciliation',NULL,NULL);
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
           '/Custom/DMT2/GLBalances/GL_BAL_DM.xdm',
           '/Custom/DMT2/GLBalances/GL_BAL_RPT.xdo',
           'GL_INTERFACE',
           'GL journal import reconciliation (Contract v1)' from dual
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
