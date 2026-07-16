-- Seed data for DMT_CEMLI_CATALOG_TBL -- the object display catalog
-- (DMT_DESIGN.html section 11, decided 2026-07-07).
-- One row per record type per object, for every in-scope object in the
-- section-1 canonical list: 45 objects (23 FBDI + 14 HDL + 6 FBL + 2 REST),
-- 86 record-type rows. CEMLI codes are character-exact section-1 canonical
-- codes (PayrollRelationships long per the 2026-07-05 decision; GLBudgets
-- short). PlanningBudgets is out of scope (2026-07-07) and is not seeded.
-- MERGE on the business key (CEMLI_CODE + TFM_TABLE; the one NULL-table row
-- uses a sentinel) so re-running the seed converges display names, status
-- columns, row filters, and sort orders to the committed values.
--
-- Label notes (section 11 "Canonical values every layer must use"):
--   * GLBalances -> 'GL Journals', Expenditures -> 'Project Expenditures',
--     Projects/tasks -> 'Project Tasks' (user-renamed, both sides).
--   * Projects/txn -> 'Txn Controls' and PerfEvaluations -> 'Performance Docs'
--     per section 11's canonical-target table ("conform to record").
--     NOTE: the Appendix C3 entry records the opposite choice ('Transaction
--     Controls' / 'Performance Evaluations', "fuller names, user-chosen");
--     section 11 is followed here as the canonical statement.
--   * MiscReceipts reads the INV_TRX pipeline tables (section 1 correction
--     2026-07-07 -- the orphaned RCV_* tables are a sweep candidate); those
--     tables carry TFM_STATUS.
--   * Work Relationships is catalogued under Assignments, not Workers: the
--     Assignments generator emits the WorkRelationship sections (section 1
--     "move" note on the Workers catalog-view cell).
--   * STATUS_COLUMN is uniformly TFM_STATUS (conformance tranche 2026-07-08:
--     the section-7 infra-column dictionary renamed every TFM row-status
--     column to TFM_STATUS; the queue engine follows this catalog value).
--   * ARReceipts (section 1 #46, REST, not built -- deliberately last) is
--     seeded with no TFM table; its record types are added when built.

merge into "DMT_CEMLI_CATALOG_TBL" t
using (
    -- FBDI objects -------------------------------------------------------
    select 'Suppliers' cemli_code, 'Suppliers' display_name, 'DMT_POZ_SUPPLIERS_TFM_TBL' tfm_table, 'TFM_STATUS' status_column, cast(null as varchar2(4000)) row_filter, 1 sort_order from dual
    union all select 'SupplierAddresses', 'Supplier Addresses', 'DMT_POZ_SUP_ADDR_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'SupplierSites', 'Supplier Sites', 'DMT_POZ_SUP_SITE_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'SupplierSiteAssignments', 'Site Assignments', 'DMT_POZ_SUP_SITE_ASSN_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'SupplierContacts', 'Supplier Contacts', 'DMT_POZ_SUP_CONTACTS_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'PurchaseOrders', 'PO Headers', 'DMT_PO_HEADERS_INT_TFM_TBL', 'TFM_STATUS', 'STYLE_DISPLAY_NAME = ''Purchase Order''', 1 from dual
    union all select 'PurchaseOrders', 'PO Lines', 'DMT_PO_LINES_INT_TFM_TBL', 'TFM_STATUS', 'INTERFACE_HEADER_KEY IN (SELECT INTERFACE_HEADER_KEY FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL WHERE STYLE_DISPLAY_NAME = ''Purchase Order'')', 2 from dual
    union all select 'PurchaseOrders', 'PO Line Locations', 'DMT_PO_LINE_LOCS_INT_TFM_TBL', 'TFM_STATUS', 'INTERFACE_LINE_KEY IN (SELECT INTERFACE_LINE_KEY FROM DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL WHERE INTERFACE_HEADER_KEY IN (SELECT INTERFACE_HEADER_KEY FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL WHERE STYLE_DISPLAY_NAME = ''Purchase Order''))', 3 from dual
    union all select 'PurchaseOrders', 'PO Distributions', 'DMT_PO_DISTS_INT_TFM_TBL', 'TFM_STATUS', 'INTERFACE_LINE_LOCATION_KEY IN (SELECT INTERFACE_LINE_LOCATION_KEY FROM DMT_OWNER.DMT_PO_LINE_LOCS_INT_TFM_TBL WHERE INTERFACE_LINE_KEY IN (SELECT INTERFACE_LINE_KEY FROM DMT_OWNER.DMT_PO_LINES_INT_TFM_TBL WHERE INTERFACE_HEADER_KEY IN (SELECT INTERFACE_HEADER_KEY FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL WHERE STYLE_DISPLAY_NAME = ''Purchase Order'')))', 4 from dual
    union all select 'BlanketPOs', 'Blanket PO Headers', 'DMT_PO_HEADERS_INT_TFM_TBL', 'TFM_STATUS', 'STYLE_DISPLAY_NAME = ''Blanket Purchase Agreement''', 1 from dual
    union all select 'BlanketPOs', 'Blanket PO Lines', 'DMT_PO_LINES_INT_TFM_TBL', 'TFM_STATUS', 'INTERFACE_HEADER_KEY IN (SELECT INTERFACE_HEADER_KEY FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL WHERE STYLE_DISPLAY_NAME = ''Blanket Purchase Agreement'')', 2 from dual
    union all select 'Contracts', 'Contract Headers', 'DMT_PO_HEADERS_INT_TFM_TBL', 'TFM_STATUS', 'STYLE_DISPLAY_NAME = ''Contract Purchase Agreement''', 1 from dual
    union all select 'APInvoices', 'AP Invoice Headers', 'DMT_AP_INVOICES_INT_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'APInvoices', 'AP Invoice Lines', 'DMT_AP_INVOICE_LINES_INT_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'ARInvoices', 'AR Lines', 'DMT_RA_LINES_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'ARInvoices', 'AR Distributions', 'DMT_RA_DISTS_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'Requisitions', 'Req Headers', 'DMT_POR_REQ_HEADERS_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'Requisitions', 'Req Lines', 'DMT_POR_REQ_LINES_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'Requisitions', 'Req Distributions', 'DMT_POR_REQ_DISTS_TFM_TBL', 'TFM_STATUS', null, 3 from dual
    union all select 'MiscReceipts', 'Inventory Transactions', 'DMT_INV_TRX_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'MiscReceipts', 'Transaction Lots', 'DMT_INV_TRX_LOTS_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'MiscReceipts', 'Transaction Serials', 'DMT_INV_TRX_SERIALS_TFM_TBL', 'TFM_STATUS', null, 3 from dual
    union all select 'Customers', 'Parties', 'DMT_HZ_PARTIES_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'Customers', 'Locations', 'DMT_HZ_LOCATIONS_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'Customers', 'Party Sites', 'DMT_HZ_PARTY_SITES_TFM_TBL', 'TFM_STATUS', null, 3 from dual
    union all select 'Customers', 'Party Site Uses', 'DMT_HZ_PARTY_SITE_USES_TFM_TBL', 'TFM_STATUS', null, 4 from dual
    union all select 'Customers', 'Accounts', 'DMT_HZ_ACCOUNTS_TFM_TBL', 'TFM_STATUS', null, 5 from dual
    union all select 'Customers', 'Account Sites', 'DMT_HZ_ACCT_SITES_TFM_TBL', 'TFM_STATUS', null, 6 from dual
    union all select 'Customers', 'Account Site Uses', 'DMT_HZ_ACCT_SITE_USES_TFM_TBL', 'TFM_STATUS', null, 7 from dual
    union all select 'GLBalances', 'GL Journals', 'DMT_GL_INTERFACE_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'GLBudgets', 'GL Budget Balances', 'DMT_GL_BUDGET_INT_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'Assets', 'Asset Headers', 'DMT_FA_ASSET_HDR_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'Assets', 'Asset Books', 'DMT_FA_ASSET_BOOK_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'Assets', 'Asset Assignments', 'DMT_FA_ASSET_ASSIGN_TFM_TBL', 'TFM_STATUS', null, 3 from dual
    union all select 'Projects', 'Projects', 'DMT_PJF_PROJECTS_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'Projects', 'Project Tasks', 'DMT_PJF_TASKS_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'Projects', 'Team Members', 'DMT_PJF_TEAM_MEMBERS_TFM_TBL', 'TFM_STATUS', null, 3 from dual
    union all select 'Projects', 'Txn Controls', 'DMT_PJC_TXN_CONTROLS_TFM_TBL', 'TFM_STATUS', null, 4 from dual
    union all select 'Expenditures', 'Project Expenditures', 'DMT_PJC_EXPENDITURES_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'ProjectBudgets', 'Project Budgets', 'DMT_PRJ_BUDGET_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'BillingEvents', 'Billing Events', 'DMT_PJB_BILL_EVENTS_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    -- Grants: award headers + award projects (the dedicated Award Projects TFM
    -- table carries its own rows, so no row filter). Other award children remain
    -- out of the catalog view for now (section 1 #23).
    union all select 'Grants', 'Award Headers', 'DMT_GMS_AWD_HEADERS_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'Grants', 'Award Projects', 'DMT_GMS_AWD_PROJECTS_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'Items', 'Item Master', 'DMT_EGP_ITEM_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'Items', 'Item Categories', 'DMT_EGP_ITEM_CAT_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    -- HDL objects --------------------------------------------------------
    union all select 'Workers', 'Workers', 'DMT_WORKER_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'Workers', 'Person Names', 'DMT_PERSON_NAME_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'Workers', 'Person Emails', 'DMT_PERSON_EMAIL_TFM_TBL', 'TFM_STATUS', null, 3 from dual
    union all select 'Workers', 'Person Phones', 'DMT_PERSON_PHONE_TFM_TBL', 'TFM_STATUS', null, 4 from dual
    union all select 'Workers', 'Person Addresses', 'DMT_PERSON_ADDR_TFM_TBL', 'TFM_STATUS', null, 5 from dual
    union all select 'Workers', 'Person NIDs', 'DMT_PERSON_NID_TFM_TBL', 'TFM_STATUS', null, 6 from dual
    union all select 'Workers', 'Person Legislation', 'DMT_PERSON_LEGISL_TFM_TBL', 'TFM_STATUS', null, 7 from dual
    union all select 'Assignments', 'Work Relationships', 'DMT_WORK_REL_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'Assignments', 'Assignments', 'DMT_ASSIGNMENT_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'Salaries', 'Salaries', 'DMT_SALARY_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'SalaryBases', 'Salary Bases', 'DMT_SAL_BASIS_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'PayrollRelationships', 'Payroll Relationships', 'DMT_PAY_REL_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'TaxCards', 'Tax Cards', 'DMT_TAX_CARD_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'TaxCards', 'Tax Card Components', 'DMT_TAX_CARD_COMP_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'W2Balances', 'W2 Balances', 'DMT_W2_BAL_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'W2Balances', 'W2 Balance Details', 'DMT_W2_BAL_DTL_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'BenParticipant', 'Participant Enrollment', 'DMT_BEN_PARTIC_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'BenDependent', 'Dependent Enrollment', 'DMT_BEN_DEPEND_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'BenBeneficiary', 'Beneficiary Enrollment', 'DMT_BEN_BENFY_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'Absences', 'Absences', 'DMT_ABSENCE_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'TalentProfiles', 'Talent Profiles', 'DMT_TALENT_PROF_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'TalentProfiles', 'Profile Items', 'DMT_TALENT_PROF_ITEM_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'PerfEvaluations', 'Performance Docs', 'DMT_PERF_EVAL_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'PerfEvaluations', 'Performance Ratings', 'DMT_PERF_EVAL_RATING_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'WorkSchedules', 'Work Schedules', 'DMT_WORK_SCHED_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'WorkSchedules', 'Schedule Details', 'DMT_WORK_SCHED_DTL_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    -- FBL / configuration objects ----------------------------------------
    union all select 'GLCalendar', 'GL Calendar', 'DMT_GL_CALENDAR_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'UnitsOfMeasure', 'Units of Measure', 'DMT_INV_UOM_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'Lookups', 'Lookup Types', 'DMT_FND_LOOKUP_TYPE_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'Lookups', 'Lookup Values', 'DMT_FND_LOOKUP_VALUE_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'ValueSets', 'Value Sets', 'DMT_FND_VS_SET_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'ValueSets', 'Value Set Values', 'DMT_FND_VS_VALUE_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'PaymentTerms', 'Payment Term Headers', 'DMT_AP_PAY_TERM_HDR_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'PaymentTerms', 'Payment Term Lines', 'DMT_AP_PAY_TERM_LINE_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'TaxConfig', 'Tax Regimes', 'DMT_ZX_REGIME_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'TaxConfig', 'Tax Rates', 'DMT_ZX_RATE_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    -- REST-loaded objects ------------------------------------------------
    union all select 'Banks', 'Banks', 'DMT_CE_BANK_TFM_TBL', 'TFM_STATUS', null, 1 from dual
    union all select 'Banks', 'Bank Branches', 'DMT_CE_BRANCH_TFM_TBL', 'TFM_STATUS', null, 2 from dual
    union all select 'Banks', 'Bank Accounts', 'DMT_CE_BANK_ACCT_TFM_TBL', 'TFM_STATUS', null, 3 from dual
    -- STATUS_COLUMN is TFM_STATUS even before the object is built: the
    -- dictionary makes TFM_STATUS the only legal value, and a NULL here
    -- would make the engine's catalog-driven SQL malformed the day the
    -- object's TFM table lands (fixed 2026-07-09, conformance review F12).
    union all select 'ARReceipts', 'AR Receipts', null, 'TFM_STATUS', null, 1 from dual
) s
on (    t."CEMLI_CODE" = s.cemli_code
    and nvl(t."TFM_TABLE", '~NONE~') = nvl(s.tfm_table, '~NONE~'))
when matched then update set
    t."DISPLAY_NAME"  = s.display_name,
    t."STATUS_COLUMN" = s.status_column,
    t."ROW_FILTER"    = s.row_filter,
    t."SORT_ORDER"    = s.sort_order
when not matched then insert
    ("CEMLI_CODE","DISPLAY_NAME","TFM_TABLE","STATUS_COLUMN","ROW_FILTER","SORT_ORDER")
    values (s.cemli_code, s.display_name, s.tfm_table, s.status_column, s.row_filter, s.sort_order);

commit;
