-- Seed data for DMT_PIPELINE_DEF_TBL -- the decided seed content from
-- DMT_DESIGN.html section 6 "Pipeline definitions -- the seed content
-- (decided 2026-07-07)": complete membership + dependency graph for every
-- in-scope object (45 rows; every object has exactly one pipeline home).
-- MERGE on the business key (CEMLI_CODE -- unique per the one-home rule) so
-- re-running the seed converges an existing database to the committed values.
-- DEPENDS_ON: comma-separated canonical CEMLI codes (queue engine format).
-- POSTRUN_JOB: only Assets has one (per-book Prepare + Post; the post step is
-- the ESS job path the queue worker submits today). Every other object is
-- explicitly none (NULL).
-- ARReceipts is seeded per the design table ("ARReceipts (future)") even
-- though the object is not built yet -- deliberately last, section 1 #46.

merge into "DMT_PIPELINE_DEF_TBL" t
using (
    select 'P2P' pipeline_code, 10 sort_order, 'Items' cemli_code, null depends_on, null postrun_job from dual
    union all select 'P2P', 20, 'Suppliers', null, null from dual
    union all select 'P2P', 30, 'SupplierAddresses', 'Suppliers', null from dual
    union all select 'P2P', 40, 'SupplierSites', 'Suppliers,SupplierAddresses', null from dual
    union all select 'P2P', 50, 'SupplierSiteAssignments', 'SupplierSites', null from dual
    union all select 'P2P', 60, 'SupplierContacts', 'Suppliers', null from dual
    union all select 'P2P', 70, 'Requisitions', 'Items,SupplierSiteAssignments', null from dual
    union all select 'P2P', 80, 'PurchaseOrders', 'Items,Requisitions,SupplierSiteAssignments,SupplierContacts', null from dual
    union all select 'P2P', 90, 'BlanketPOs', 'Items,SupplierSiteAssignments', null from dual
    union all select 'P2P', 100, 'Contracts', 'SupplierSiteAssignments', null from dual
    union all select 'P2P', 110, 'APInvoices', 'SupplierSiteAssignments', null from dual
    union all select 'P2P', 120, '1099Invoices', 'SupplierSiteAssignments', null from dual
    union all select 'P2P', 130, 'MiscReceipts', 'Items', null from dual
    union all select 'O2C', 10, 'Customers', null, null from dual
    union all select 'O2C', 20, 'ARInvoices', 'Customers', null from dual
    union all select 'O2C', 30, 'ARReceipts', 'Customers,ARInvoices', null from dual
    union all select 'PROJECTS', 10, 'Projects', null, null from dual
    union all select 'PROJECTS', 20, 'BillingEvents', 'Projects', null from dual
    union all select 'PROJECTS', 30, 'Expenditures', 'Projects', null from dual
    union all select 'PROJECTS', 40, 'Grants', 'Projects', null from dual
    union all select 'PROJECTS', 50, 'ProjectBudgets', 'Projects', null from dual
    union all select 'FINANCIALS', 10, 'GLBalances', null, null from dual
    union all select 'FINANCIALS', 20, 'GLBudgets', null, null from dual
    union all select 'FINANCIALS', 30, 'Assets', null,
        '/oracle/apps/ess/financials/assets/additions;PostMassAdditions' from dual
    union all select 'HCM', 10, 'Workers', null, null from dual
    union all select 'HCM', 20, 'Assignments', 'Workers', null from dual
    union all select 'HCM', 30, 'Salaries', 'Workers,Assignments', null from dual
    union all select 'HCM', 40, 'SalaryBases', 'Salaries', null from dual
    union all select 'HCM', 50, 'PayrollRelationships', 'Workers', null from dual
    union all select 'HCM', 60, 'TaxCards', 'Workers', null from dual
    union all select 'HCM', 70, 'W2Balances', null, null from dual
    union all select 'HCM', 80, 'BenParticipant', 'Workers', null from dual
    union all select 'HCM', 90, 'BenDependent', 'Workers', null from dual
    union all select 'HCM', 100, 'BenBeneficiary', 'Workers', null from dual
    union all select 'HCM', 110, 'Absences', 'Workers', null from dual
    union all select 'HCM', 120, 'TalentProfiles', 'Workers', null from dual
    union all select 'HCM', 130, 'PerfEvaluations', 'Workers', null from dual
    union all select 'HCM', 140, 'WorkSchedules', null, null from dual
    union all select 'CONFIGURATION', 10, 'GLCalendar', null, null from dual
    union all select 'CONFIGURATION', 20, 'ValueSets', null, null from dual
    union all select 'CONFIGURATION', 30, 'Lookups', null, null from dual
    union all select 'CONFIGURATION', 40, 'UnitsOfMeasure', null, null from dual
    union all select 'CONFIGURATION', 50, 'PaymentTerms', null, null from dual
    union all select 'CONFIGURATION', 60, 'TaxConfig', null, null from dual
    union all select 'CONFIGURATION', 70, 'Banks', null, null from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."PIPELINE_CODE" = s.pipeline_code,
    t."SORT_ORDER"    = s.sort_order,
    t."DEPENDS_ON"    = s.depends_on,
    t."POSTRUN_JOB"   = s.postrun_job
when not matched then insert
    ("PIPELINE_CODE","CEMLI_CODE","SORT_ORDER","DEPENDS_ON","POSTRUN_JOB")
    values (s.pipeline_code, s.cemli_code, s.sort_order, s.depends_on, s.postrun_job);

commit;
