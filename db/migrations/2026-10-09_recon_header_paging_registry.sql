-- Reconciliation reports page on header boundaries: registry repoint (backlog #680).
--
-- Owner decision 2026-10-09 (design section 5, "Reconciliation fetches page on
-- header boundaries"): each report below has a new version that pages by header,
-- returning the next BIP_CHUNK_SIZE headers plus every line and child row of them,
-- with the header key in the tenth column PAGE_KEY. Row selection (job ids only),
-- RECORD_KEYs, FUSION_IDs and error text are unchanged. Each new version is deployed
-- ALONGSIDE the old one (BIP objects are never overwritten).
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an existing
-- database converges without re-running the whole seed. Idempotent: each UPDATE
-- matches only rows still on the old path (the object's row and any per-tier auditor
-- row naming the same report), so a re-run changes nothing. No DDL.

prompt == APInvoices: DMT_AP_RECON_V2_DM -> DMT_AP_RECON_V3_DM (backlog #681) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/APInvoices/DMT_AP_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/APInvoices/DMT_AP_RECON_V3_RPT.xdo'
where  DM_CATALOG_PATH     = '/Custom/DMT2/APInvoices/DMT_AP_RECON_V2_DM.xdm';

prompt == Assets: DMT_FA_ASSET_RECON_V2_DM -> DMT_FA_ASSET_RECON_V3_DM (backlog #682) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Assets/DMT_FA_ASSET_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Assets/DMT_FA_ASSET_RECON_V3_RPT.xdo'
where  DM_CATALOG_PATH     = '/Custom/DMT2/Assets/DMT_FA_ASSET_RECON_V2_DM.xdm';

prompt == BlanketPOs: DMT_BLANKET_PO_RECON_V2_DM -> DMT_BLANKET_PO_RECON_V3_DM (backlog #683) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/BlanketPOs/DMT_BLANKET_PO_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/BlanketPOs/DMT_BLANKET_PO_RECON_V3_RPT.xdo'
where  DM_CATALOG_PATH     = '/Custom/DMT2/BlanketPOs/DMT_BLANKET_PO_RECON_V2_DM.xdm';

prompt == Customers: DMT_CUST_RECON_V6_DM -> DMT_CUST_RECON_V7_DM (backlog #684) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Customers/DMT_CUST_RECON_V7_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Customers/DMT_CUST_RECON_V7_RPT.xdo'
where  DM_CATALOG_PATH     = '/Custom/DMT2/Customers/DMT_CUST_RECON_V6_DM.xdm';

prompt == Expenditures: DMT_EXP_RECON_V2_DM -> DMT_EXP_RECON_V3_DM (backlog #685) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Expenditures/DMT_EXP_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Expenditures/DMT_EXP_RECON_V3_RPT.xdo'
where  DM_CATALOG_PATH     = '/Custom/DMT2/Expenditures/DMT_EXP_RECON_V2_DM.xdm';

prompt == GLBalances: DMT_GL_BAL_RECON_V4_DM -> DMT_GL_BAL_RECON_V5_DM (backlog #686) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_V5_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_V5_RPT.xdo'
where  DM_CATALOG_PATH     = '/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_V4_DM.xdm';

prompt == GLBudgets: GL_BUDGET_DM -> DMT_GL_BUDGET_RECON_V2_DM (backlog #687) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/GLBudgets/DMT_GL_BUDGET_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/GLBudgets/DMT_GL_BUDGET_RECON_V2_RPT.xdo'
where  DM_CATALOG_PATH     = '/Custom/DMT2/GLBudgets/GL_BUDGET_DM.xdm';

prompt == Items: DMT_ITEM_RECON_V3_DM -> DMT_ITEM_RECON_V4_DM (backlog #688) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Items/DMT_ITEM_RECON_V4_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Items/DMT_ITEM_RECON_V4_RPT.xdo'
where  DM_CATALOG_PATH     = '/Custom/DMT2/Items/DMT_ITEM_RECON_V3_DM.xdm';

prompt == MiscReceipts: DMT_INV_TRX_RECON_V2_DM -> DMT_INV_TRX_RECON_V3_DM (backlog #689) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/MiscReceipts/DMT_INV_TRX_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/MiscReceipts/DMT_INV_TRX_RECON_V3_RPT.xdo'
where  DM_CATALOG_PATH     = '/Custom/DMT2/MiscReceipts/DMT_INV_TRX_RECON_V2_DM.xdm';

prompt == ProjectBudgets: DMT_PRJ_BUDGET_RECON_V3_DM -> DMT_PRJ_BUDGET_RECON_V4_DM (backlog #691) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V4_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V4_RPT.xdo'
where  DM_CATALOG_PATH     = '/Custom/DMT2/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V3_DM.xdm';

prompt == Projects: DMT_PROJECT_RECON_V2_DM -> DMT_PROJECT_RECON_V3_DM (backlog #692) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Projects/DMT_PROJECT_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Projects/DMT_PROJECT_RECON_V3_RPT.xdo'
where  DM_CATALOG_PATH     = '/Custom/DMT2/Projects/DMT_PROJECT_RECON_V2_DM.xdm';

prompt == PurchaseOrders: DMT_PO_RECON_V2_DM -> DMT_PO_RECON_V3_DM (backlog #693) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/PurchaseOrders/DMT_PO_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/PurchaseOrders/DMT_PO_RECON_V3_RPT.xdo'
where  DM_CATALOG_PATH     = '/Custom/DMT2/PurchaseOrders/DMT_PO_RECON_V2_DM.xdm';

prompt == Requisitions: DMT_REQ_RECON_V3_DM -> DMT_REQ_RECON_V4_DM (backlog #694) ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Requisitions/DMT_REQ_RECON_V4_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Requisitions/DMT_REQ_RECON_V4_RPT.xdo'
where  DM_CATALOG_PATH     = '/Custom/DMT2/Requisitions/DMT_REQ_RECON_V3_DM.xdm';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-09_recon_header_paging_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'reconhdrpage', USER);

commit;
