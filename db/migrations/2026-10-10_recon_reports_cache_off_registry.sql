-- Reconciliation reports with BIP data caching off: registry repoint (backlog #734).
--
-- Every reconciliation report was deployed with <dataModel ... cache="true"/> in its
-- report wrapper, so a runReport call that repeats an earlier call's parameters can
-- be served the cached result instead of reading Fusion again (proven 2026-10-10 with
-- a probe report: with cache="true" six calls returned the same SYSTIMESTAMP, and the
-- runReport byPassCache=true request flag did not change that; with cache="false"
-- every call returned a fresh one). Each live report is released as a new version
-- whose SQL is identical and whose wrapper has caching off; the old versions stay
-- deployed and are never overwritten.
--
-- Mirrors the committed seed change in db/seed/dmt_bip_report_tbl.sql so an existing
-- database converges without re-running the whole seed. Idempotent: each UPDATE
-- matches only rows still on the old report, so a re-run is a no-op. No DDL.

prompt == Repoint reconciliation registry rows to the cache-off report versions ==
update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/APInvoices/DMT_AP_RECON_V4_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/APInvoices/DMT_AP_RECON_V4_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/APInvoices/DMT_AP_RECON_V3_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/APPaymentTerms/DMT_APTERMS_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/APPaymentTerms/DMT_APTERMS_RECON_V2_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/APPaymentTerms/DMT_APTERMS_RECON_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/ARInvoices/DMT_AR_RECON_V6_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/ARInvoices/DMT_AR_RECON_V6_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/ARInvoices/DMT_AR_RECON_V5_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Absences/DMT_ABSENCES_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Absences/DMT_ABSENCES_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/Absences/DMT_ABSENCES_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Assets/DMT_FA_ASSET_RECON_V4_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Assets/DMT_FA_ASSET_RECON_V4_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/Assets/DMT_FA_ASSET_RECON_V3_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Assignments/DMT_ASSIGNMENTS_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Assignments/DMT_ASSIGNMENTS_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/Assignments/DMT_ASSIGNMENTS_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/BenBeneficiary/DMT_BENBENEFICIARY_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/BenBeneficiary/DMT_BENBENEFICIARY_RECON_V2_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/BenBeneficiary/DMT_BENBENEFICIARY_RECON_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/BenDependent/DMT_BENDEPENDENT_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/BenDependent/DMT_BENDEPENDENT_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/BenDependent/DMT_BENDEPENDENT_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/BenParticipant/DMT_BENPARTICIPANT_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/BenParticipant/DMT_BENPARTICIPANT_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/BenParticipant/DMT_BENPARTICIPANT_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/BillingEvents/DMT_BILLING_EVENT_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/BillingEvents/DMT_BILLING_EVENT_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/BillingEvents/DMT_BILLING_EVENT_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/BlanketPOs/DMT_BLANKET_PO_RECON_V4_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/BlanketPOs/DMT_BLANKET_PO_RECON_V4_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/BlanketPOs/DMT_BLANKET_PO_RECON_V3_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/CashBanks/DMT_CEBANK_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/CashBanks/DMT_CEBANK_RECON_V2_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/CashBanks/DMT_CEBANK_RECON_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Contracts/DMT_CONTRACT_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Contracts/DMT_CONTRACT_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/Contracts/DMT_CONTRACT_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Customers/DMT_CUST_RECON_V8_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Customers/DMT_CUST_RECON_V8_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/Customers/DMT_CUST_RECON_V7_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Expenditures/DMT_EXP_RECON_V4_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Expenditures/DMT_EXP_RECON_V4_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/Expenditures/DMT_EXP_RECON_V3_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_V6_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_V6_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/GLBalances/DMT_GL_BAL_RECON_V5_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/GLBudgets/DMT_GL_BUDGET_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/GLBudgets/DMT_GL_BUDGET_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/GLBudgets/DMT_GL_BUDGET_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Grants/DMT_GRANT_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Grants/DMT_GRANT_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/Grants/DMT_GRANT_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Items/DMT_ITEM_RECON_V5_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Items/DMT_ITEM_RECON_V5_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/Items/DMT_ITEM_RECON_V4_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Lookups/DMT_LOOKUP_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Lookups/DMT_LOOKUP_RECON_V2_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/Lookups/DMT_LOOKUP_RECON_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/MiscReceipts/DMT_INV_TRX_RECON_V4_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/MiscReceipts/DMT_INV_TRX_RECON_V4_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/MiscReceipts/DMT_INV_TRX_RECON_V3_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/PayrollRelationships/DMT_PAYROLLRELATIONSHIPS_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/PayrollRelationships/DMT_PAYROLLRELATIONSHIPS_RECON_V2_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/PayrollRelationships/DMT_PAYROLLRELATIONSHIPS_RECON_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V5_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V5_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V4_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Projects/DMT_PROJECT_RECON_V4_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Projects/DMT_PROJECT_RECON_V4_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/Projects/DMT_PROJECT_RECON_V3_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/PurchaseOrders/DMT_PO_RECON_V4_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/PurchaseOrders/DMT_PO_RECON_V4_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/PurchaseOrders/DMT_PO_RECON_V3_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/PurchaseOrders/PO_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/PurchaseOrders/PO_V2_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/PurchaseOrders/PO_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Requisitions/DMT_REQ_RECON_V5_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Requisitions/DMT_REQ_RECON_V5_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/Requisitions/DMT_REQ_RECON_V4_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Salaries/DMT_SALARIES_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Salaries/DMT_SALARIES_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/Salaries/DMT_SALARIES_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/SalaryBases/DMT_SALARYBASES_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/SalaryBases/DMT_SALARYBASES_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/SalaryBases/DMT_SALARYBASES_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/SupplierAddresses/DMT_SUP_ADDR_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/SupplierAddresses/DMT_SUP_ADDR_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/SupplierAddresses/DMT_SUP_ADDR_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/SupplierContacts/DMT_SUP_CONT_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/SupplierContacts/DMT_SUP_CONT_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/SupplierContacts/DMT_SUP_CONT_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/SupplierSiteAssignments/DMT_SUP_SITE_ASSN_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/SupplierSiteAssignments/DMT_SUP_SITE_ASSN_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/SupplierSiteAssignments/DMT_SUP_SITE_ASSN_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/SupplierSites/DMT_SUP_SITE_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/SupplierSites/DMT_SUP_SITE_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/SupplierSites/DMT_SUP_SITE_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Suppliers/DMT_SUP_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Suppliers/DMT_SUP_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/Suppliers/DMT_SUP_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/TalentProfiles/DMT_TALENTPROFILES_RECON_V4_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/TalentProfiles/DMT_TALENTPROFILES_RECON_V4_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/TalentProfiles/DMT_TALENTPROFILES_RECON_V3_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/UnitsOfMeasure/DMT_UOM_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/UnitsOfMeasure/DMT_UOM_RECON_V2_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/UnitsOfMeasure/DMT_UOM_RECON_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/W2Balances/DMT_W2_BAL_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/W2Balances/DMT_W2_BAL_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/W2Balances/DMT_W2_BAL_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/WorkSchedules/DMT_WORKSCHEDULES_RECON_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/WorkSchedules/DMT_WORKSCHEDULES_RECON_V2_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/WorkSchedules/DMT_WORKSCHEDULES_RECON_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/Workers/DMT_WORKERS_RECON_V3_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/Workers/DMT_WORKERS_RECON_V3_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/Workers/DMT_WORKERS_RECON_V2_RPT.xdo';

update DMT_BIP_REPORT_TBL
set    DM_CATALOG_PATH     = '/Custom/DMT2/common/DMT_FBDI_LOOKUPS_V2_DM.xdm',
       REPORT_CATALOG_PATH = '/Custom/DMT2/common/DMT_FBDI_LOOKUPS_V2_RPT.xdo'
where  REPORT_CATALOG_PATH = '/Custom/DMT2/common/DMT_FBDI_LOOKUPS_RPT.xdo';

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-10_recon_reports_cache_off_registry.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'reconcacheoff', USER);

commit;
