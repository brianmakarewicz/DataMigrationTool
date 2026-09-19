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
    -- (Stage D live, 2026-07-08) SupplierContacts depended only on Suppliers,
    -- which let the contact import run CONCURRENTLY with the address/site
    -- imports. On the first live run (270) a good contact was rejected with
    -- Fusion's generic help-desk error ([CONTACT_INTERFACE_ID]) while the
    -- address import was updating the same supplier party. The frozen stack's
    -- proven sequence imports contacts strictly LAST (memory
    -- project_suppliers.md, confirmed 2026-03-06); depending on
    -- SupplierSiteAssignments restores that serialization transitively.
    union all select 'P2P', 60, 'SupplierContacts', 'SupplierSiteAssignments', null from dual
    union all select 'P2P', 70, 'Requisitions', 'Items,SupplierSiteAssignments', null from dual
    union all select 'P2P', 80, 'PurchaseOrders', 'Items,Requisitions,SupplierSiteAssignments,SupplierContacts', null from dual
    union all select 'P2P', 90, 'BlanketPOs', 'Items,SupplierSiteAssignments', null from dual
    union all select 'P2P', 100, 'Contracts', 'SupplierSiteAssignments', null from dual
    union all select 'P2P', 110, 'APInvoices', 'SupplierSiteAssignments', null from dual
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
    -- PlanningBudgets is NOT a pipeline member that runs in a FINANCIALS run
    -- (decided 2026-07-07: out of scope). It is listed here only to satisfy the
    -- NOT NULL PIPELINE_CODE so its dispatch row can carry a RECON_PROC (see the
    -- dispatch MERGE below); EXEC_PROC stays NULL so the scheduler never queues it
    -- (it queues only rows WHERE EXEC_PROC IS NOT NULL). It runs solely via a
    -- direct RUN_PLAN_BUDGETS call. SORT_ORDER 90 keeps it clear of the real
    -- FINANCIALS members.
    union all select 'FINANCIALS', 90, 'PlanningBudgets', null, null from dual
    -- The single Worker load carries the WorkRelationship/WorkTerms/Assignment
    -- components (2026-09-17 HCM object-model correction), so 'Assignments' is no
    -- longer a pipeline object. 'PayrollRelationships' is retired too: it is
    -- auto-created at hire, not a loadable standalone object. Their rows are
    -- explicitly deleted at the end of this file so an existing database converges.
    union all select 'HCM', 10, 'Workers', null, null from dual
    union all select 'HCM', 30, 'Salaries', 'Workers', null from dual
    union all select 'HCM', 40, 'SalaryBases', 'Salaries', null from dual
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

-- ----------------------------------------------------------------------
-- Dispatch registry seed (Stage C task 3 -- section-12 catalog-driven
-- queue dispatch). EXEC_PROC / RECON_PROC values are transcribed
-- character-exact from the retired hardcoded dispatch in
-- DMT_QUEUE_WORKER_PKG (the ~39-branch EXECUTE_ONE CASE and the
-- RECONCILE_ONE ELSIF chain):
--   * The five supplier-family objects share DMT_POZ_SUP_RESULTS_PKG
--     .RECONCILE_BATCH, which takes p_cemli_code (RECON_HAS_CEMLI_ARG=Y;
--     replaces the old LIKE 'Supplier%' branch with exact registry rows).
--   * MiscReceipts is the one SYNC object (the old code flipped
--     DMT_LOADER_PKG.g_async_mode to FALSE for it).
--   * HDL objects have no queue-dispatched reconciler (the old ELSIF
--     chain had no arm for them -- they complete inside their RUN_* cycle).
--   * PayrollRelationships (canonical code) maps to the loader procedure
--     RUN_PAYROLL_RELS -- the old CASE arm used the retired spelling
--     'PayrollRels'.
--   * The CONFIGURATION objects and ARReceipts have no EXEC_PROC yet:
--     the old CASE had no arm for them either (config runners are the
--     dead orchestration path, section-12 P2; ARReceipts is deliberately
--     last). Dispatch raises a clear not-registered error for them.
--   * The old CASE arms 'ItemCategories' and 'PlanBudgets' have no
--     registry row: ItemCategories is bundled into the Items token and
--     PlanBudgets (PlanningBudgets) is out of scope (both decided
--     2026-07-07) -- neither is one of the 45 canonical objects.
--   * PARTITION_KEYS_PROC (2026-07-20, work-queue-ID core): the PKG.FUNCTION
--     the queue worker calls to get a spawn-per-partition object's distinct
--     partition tokens with STATIC SQL over that object's own transform
--     table(s). Set only for the three spawn objects -- Items
--     (DMT_EGP_ITEM_RESULTS_PKG.GET_PARTITION_KEYS, which UNIONs the item and
--     item-category transform tables so a category-only batch still spawns a
--     child), Assets and Requisitions (their single transform table). NULL for
--     every other object. This replaced the retired dynamic SELECT DISTINCT in
--     EXECUTE_ONE, so there is NO EXECUTE IMMEDIATE outside the three
--     sanctioned DMT_QUEUE_WORKER_PKG dispatch/accounting sites.
-- ----------------------------------------------------------------------
merge into "DMT_PIPELINE_DEF_TBL" t
using (
    select 'Items' cemli_code, 'DMT_LOADER_PKG.RUN_ITEMS' exec_proc, 'ASYNC' exec_mode, 'DMT_EGP_ITEM_RESULTS_PKG.RECONCILE_BATCH' recon_proc, 'N' recon_has_cemli_arg, 'DMT_EGP_ITEM_RESULTS_PKG.GET_PARTITION_KEYS' partition_keys_proc from dual
    union all select 'Suppliers', 'DMT_LOADER_PKG.RUN_SUPPLIERS', 'ASYNC', 'DMT_POZ_SUP_RESULTS_PKG.RECONCILE_BATCH', 'Y', null from dual
    union all select 'SupplierAddresses', 'DMT_LOADER_PKG.RUN_SUPPLIER_ADDRESSES', 'ASYNC', 'DMT_POZ_SUP_RESULTS_PKG.RECONCILE_BATCH', 'Y', null from dual
    union all select 'SupplierSites', 'DMT_LOADER_PKG.RUN_SUPPLIER_SITES', 'ASYNC', 'DMT_POZ_SUP_RESULTS_PKG.RECONCILE_BATCH', 'Y', null from dual
    union all select 'SupplierSiteAssignments', 'DMT_LOADER_PKG.RUN_SUPPLIER_SITE_ASSIGNMENTS', 'ASYNC', 'DMT_POZ_SUP_RESULTS_PKG.RECONCILE_BATCH', 'Y', null from dual
    union all select 'SupplierContacts', 'DMT_LOADER_PKG.RUN_SUPPLIER_CONTACTS', 'ASYNC', 'DMT_POZ_SUP_RESULTS_PKG.RECONCILE_BATCH', 'Y', null from dual
    union all select 'Requisitions', 'DMT_LOADER_PKG.RUN_REQUISITIONS', 'ASYNC', 'DMT_REQ_RESULTS_PKG.RECONCILE_BATCH', 'N', 'DMT_REQ_RESULTS_PKG.GET_PARTITION_KEYS' from dual
    union all select 'PurchaseOrders', 'DMT_LOADER_PKG.RUN_PURCHASE_ORDERS', 'ASYNC', 'DMT_PO_RESULTS_PKG.RECONCILE_BATCH', 'N', null from dual
    union all select 'BlanketPOs', 'DMT_LOADER_PKG.RUN_BLANKET_POS', 'ASYNC', 'DMT_BLANKET_PO_RESULTS_PKG.RECONCILE_BATCH', 'N', null from dual
    union all select 'Contracts', 'DMT_LOADER_PKG.RUN_CONTRACTS', 'ASYNC', 'DMT_CONTRACT_RESULTS_PKG.RECONCILE_BATCH', 'N', null from dual
    union all select 'APInvoices', 'DMT_LOADER_PKG.RUN_AP_INVOICES', 'ASYNC', 'DMT_AP_RESULTS_PKG.RECONCILE_BATCH', 'N', null from dual
    union all select 'MiscReceipts', 'DMT_LOADER_PKG.RUN_MISC_RECEIPTS', 'SYNC', 'DMT_MISC_RECEIPT_RESULTS_PKG.RECONCILE_BATCH', 'N', null from dual
    union all select 'Customers', 'DMT_LOADER_PKG.RUN_CUSTOMERS', 'ASYNC', 'DMT_CUST_RESULTS_PKG.RECONCILE_BATCH', 'N', null from dual
    union all select 'ARInvoices', 'DMT_LOADER_PKG.RUN_AR_INVOICES', 'ASYNC', 'DMT_AR_RESULTS_PKG.RECONCILE_BATCH', 'N', null from dual
    union all select 'ARReceipts', null, 'ASYNC', null, 'N', null from dual
    union all select 'Projects', 'DMT_LOADER_PKG.RUN_PROJECTS', 'ASYNC', 'DMT_PROJECT_RESULTS_PKG.RECONCILE_BATCH', 'N', null from dual
    union all select 'BillingEvents', 'DMT_LOADER_PKG.RUN_BILLING_EVENTS', 'ASYNC', 'DMT_BILLING_EVENT_RESULTS_PKG.RECONCILE_BATCH', 'N', null from dual
    -- Expenditures spawns one child work item per distinct (USER_TRANSACTION_SOURCE,
    -- DOCUMENT_NAME) group: Import and Process Cost Transactions takes exactly one
    -- transaction-source id and one document per submission, so one child = one submit.
    -- GET_PARTITION_KEYS returns a TWO-column composite JSON token per group.
    union all select 'Expenditures', 'DMT_LOADER_PKG.RUN_EXPENDITURES', 'ASYNC', 'DMT_EXPENDITURE_RESULTS_PKG.RECONCILE_BATCH', 'N', 'DMT_EXPENDITURE_RESULTS_PKG.GET_PARTITION_KEYS' from dual
    union all select 'Grants', 'DMT_LOADER_PKG.RUN_GRANTS', 'ASYNC', 'DMT_GRANTS_RESULTS_PKG.RECONCILE_BATCH', 'N', null from dual
    union all select 'ProjectBudgets', 'DMT_LOADER_PKG.RUN_PROJECT_BUDGETS', 'ASYNC', 'DMT_PRJ_BUDGET_RESULTS_PKG.RECONCILE_BATCH', 'N', null from dual
    union all select 'GLBalances', 'DMT_LOADER_PKG.RUN_GL_BALANCES', 'ASYNC', 'DMT_GL_RESULTS_PKG.RECONCILE_BATCH', 'N', null from dual
    union all select 'GLBudgets', 'DMT_LOADER_PKG.RUN_GL_BUDGETS', 'ASYNC', 'DMT_GL_BUDGET_RESULTS_PKG.RECONCILE_BATCH', 'N', null from dual
    union all select 'Assets', 'DMT_LOADER_PKG.RUN_ASSETS', 'ASYNC', 'DMT_FA_ASSET_RESULTS_PKG.RECONCILE_BATCH', 'N', 'DMT_FA_ASSET_RESULTS_PKG.GET_PARTITION_KEYS' from dual
    -- PlanningBudgets: out of scope as a PIPELINE MEMBER (decided 2026-07-07) --
    -- it is never seeded into a pipeline run because EXEC_PROC is NULL (the
    -- scheduler queues only rows WHERE EXEC_PROC IS NOT NULL). But it DOES
    -- reconcile when run directly via RUN_PLAN_BUDGETS, so its RECON_PROC is
    -- registered here so the ONE reconcile dispatch (RECONCILE_VIA_REGISTRY,
    -- backlog #7) finds it instead of hitting the fail-open -20044. Its
    -- RECONCILE_BATCH now carries the uniform p_work_queue_id argument.
    -- PIPELINE_CODE is required NOT NULL; FINANCIALS is its natural home, but
    -- with EXEC_PROC NULL it is never dispatched into a FINANCIALS run.
    union all select 'PlanningBudgets', null, 'ASYNC', 'DMT_PLAN_BUDGET_RESULTS_PKG.RECONCILE_BATCH', 'N', null from dual
    -- 'Assignments' + 'PayrollRelationships' dispatch rows retired 2026-09-17
    -- (see the membership block above); explicitly deleted at EOF to converge.
    union all select 'Workers', 'DMT_LOADER_PKG.RUN_WORKERS', 'ASYNC', null, 'N', null from dual
    union all select 'Salaries', 'DMT_LOADER_PKG.RUN_SALARIES', 'ASYNC', null, 'N', null from dual
    union all select 'SalaryBases', 'DMT_LOADER_PKG.RUN_SALARY_BASES', 'ASYNC', null, 'N', null from dual
    union all select 'TaxCards', 'DMT_LOADER_PKG.RUN_TAX_CARDS', 'ASYNC', null, 'N', null from dual
    union all select 'W2Balances', 'DMT_LOADER_PKG.RUN_W2_BALANCES', 'ASYNC', null, 'N', null from dual
    union all select 'BenParticipant', 'DMT_LOADER_PKG.RUN_BEN_PARTICIPANT', 'ASYNC', null, 'N', null from dual
    union all select 'BenDependent', 'DMT_LOADER_PKG.RUN_BEN_DEPENDENT', 'ASYNC', null, 'N', null from dual
    union all select 'BenBeneficiary', 'DMT_LOADER_PKG.RUN_BEN_BENEFICIARY', 'ASYNC', null, 'N', null from dual
    union all select 'Absences', 'DMT_LOADER_PKG.RUN_ABSENCES', 'ASYNC', null, 'N', null from dual
    union all select 'TalentProfiles', 'DMT_LOADER_PKG.RUN_TALENT_PROFILES', 'ASYNC', null, 'N', null from dual
    union all select 'PerfEvaluations', 'DMT_LOADER_PKG.RUN_PERF_EVALUATIONS', 'ASYNC', null, 'N', null from dual
    union all select 'WorkSchedules', 'DMT_LOADER_PKG.RUN_WORK_SCHEDULES', 'ASYNC', null, 'N', null from dual
    union all select 'GLCalendar', null, 'ASYNC', null, 'N', null from dual
    union all select 'ValueSets', 'DMT_FND_VS_RUNNER_PKG.RUN_STANDARD', 'LOCAL', null, 'N', null from dual
    union all select 'Lookups', null, 'ASYNC', null, 'N', null from dual
    union all select 'UnitsOfMeasure', 'DMT_INV_UOM_RUNNER_PKG.RUN_STANDARD', 'LOCAL', null, 'N', null from dual
    union all select 'PaymentTerms', 'DMT_AP_PAY_TERM_RUNNER_PKG.RUN_STANDARD', 'LOCAL', null, 'N', null from dual
    union all select 'TaxConfig', null, 'ASYNC', null, 'N', null from dual
    union all select 'Banks', null, 'ASYNC', null, 'N', null from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."EXEC_PROC"            = s.exec_proc,
    t."EXEC_MODE"            = s.exec_mode,
    t."RECON_PROC"           = s.recon_proc,
    t."RECON_HAS_CEMLI_ARG"  = s.recon_has_cemli_arg,
    t."PARTITION_KEYS_PROC"  = s.partition_keys_proc;

commit;

-- ----------------------------------------------------------------------
-- Retirement converge (2026-09-17 HCM object-model correction). The two
-- MERGE blocks above are insert/update only, so on a database that already
-- carries the retired rows they would linger. Delete them explicitly (one
-- row per CEMLI_CODE, so this clears both the membership and dispatch data
-- for each). 'Assignments' folded into the single Worker load;
-- 'PayrollRelationships' is auto-created at hire (verifier-only).
delete from "DMT_PIPELINE_DEF_TBL" where "CEMLI_CODE" in ('Assignments','PayrollRelationships');

commit;
