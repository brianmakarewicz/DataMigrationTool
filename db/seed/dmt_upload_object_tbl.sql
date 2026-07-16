-- Seed data for DMT_UPLOAD_OBJECT_TBL -- the upload object registry that
-- drives the metadata-driven CSV upload (DMT_CSV_UPLOAD_PKG) and the
-- auto-generated column dictionary (DMT_UPLOAD_DICT_PKG.SEED_DICTIONARY).
--
-- WHAT THIS SEED DOES
--   One row per staging table, for every in-scope object and each of its
--   child staging tables. This lets the EXISTING upload route a single
--   multi-CSV "scenario" zip to every DMT_*_STG_TBL at full fidelity -- the
--   whole supplier family, the seven-level HZ customer hierarchy, the PO
--   header/line/location/distribution set, the fifteen-table Grants award
--   hierarchy, and so on. All business columns of each table are picked up
--   automatically by SEED_DICTIONARY from USER_TAB_COLUMNS, so no column is
--   dropped (BUSINESS_RELATIONSHIP, PARTY_ORIG_SYSTEM, SHIP_TO_LOCATION, ...).
--
-- ROUTING / ZIP CONVENTION
--   * OBJECT_CODE       = staging table name without the DMT_ prefix and the
--                         _STG_TBL suffix (e.g. POZ_SUP_ADDR). Unique key.
--   * CSV_FILENAME      = <STAGING_TABLE>.csv (e.g. DMT_POZ_SUP_ADDR_STG_TBL.csv).
--                         UPLOAD_ZIP_BUNDLE matches each CSV in the zip to this.
--   * PARENT_OBJECT_CODE= the object's header table, for child staging tables.
--   * DISPLAY_ORDER     = global parent-before-child load order. The zip
--                         loader honours this so a parent table (e.g.
--                         DMT_HZ_PARTIES_STG_TBL) loads before its children.
--   * PAGE_NUMBER       = the Data Migration Console functional page the object
--                         belongs to (2 P2P, 3 Financials, 4 O2C, 5 Projects,
--                         6 HCM, 7 Configuration).
--
-- SCOPE NOTES
--   * PurchaseOrders, BlanketPOs and Contracts share the same physical PO
--     staging tables (they differ only by STYLE_DISPLAY_NAME), so those tables
--     are registered ONCE, under PurchaseOrders.
--   * PlanningBudgets (DMT_PLAN_BUDGET_STG_TBL) is out of scope (decided
--     2026-07-07) and is deliberately NOT registered.
--   * The orphaned DMT_RCV_* staging tables are NOT registered; MiscReceipts
--     uses the DMT_INV_TRX_* tables (catalog note, section 1 correction
--     2026-07-07).
--   * ARReceipts (REST, not built) has no staging table yet and is omitted;
--     add its rows when the object is built.
--
-- Idempotent: MERGE on the OBJECT_CODE business key converges an existing
-- database to the committed values (re-runnable).

merge into "DMT_UPLOAD_OBJECT_TBL" t
using (
    -- Suppliers  (page 2 -- P2P (Procure to Pay))
    select 'POZ_SUPPLIERS' object_code, 'Suppliers' display_name, 2 page_number, 'DMT_POZ_SUPPLIERS_STG_TBL' staging_table, 'DMT_POZ_SUPPLIERS_STG_TBL.csv' csv_filename, 1 display_order, null parent_object_code, 'Y' is_active from dual
    -- SupplierAddresses  (page 2 -- P2P (Procure to Pay))
    union all select 'POZ_SUP_ADDR', 'Supplier Addresses', 2, 'DMT_POZ_SUP_ADDR_STG_TBL', 'DMT_POZ_SUP_ADDR_STG_TBL.csv', 2, null, 'Y' from dual
    -- SupplierSites  (page 2 -- P2P (Procure to Pay))
    union all select 'POZ_SUP_SITE', 'Supplier Sites', 2, 'DMT_POZ_SUP_SITE_STG_TBL', 'DMT_POZ_SUP_SITE_STG_TBL.csv', 3, null, 'Y' from dual
    -- SupplierSiteAssignments  (page 2 -- P2P (Procure to Pay))
    union all select 'POZ_SUP_SITE_ASSN', 'Site Assignments', 2, 'DMT_POZ_SUP_SITE_ASSN_STG_TBL', 'DMT_POZ_SUP_SITE_ASSN_STG_TBL.csv', 4, null, 'Y' from dual
    -- SupplierContacts  (page 2 -- P2P (Procure to Pay))
    union all select 'POZ_SUP_CONTACTS', 'Supplier Contacts', 2, 'DMT_POZ_SUP_CONTACTS_STG_TBL', 'DMT_POZ_SUP_CONTACTS_STG_TBL.csv', 5, null, 'Y' from dual
    -- PurchaseOrders  (page 2 -- P2P (Procure to Pay))
    union all select 'PO_HEADERS_INT', 'PO Headers', 2, 'DMT_PO_HEADERS_INT_STG_TBL', 'DMT_PO_HEADERS_INT_STG_TBL.csv', 6, null, 'Y' from dual
    union all select 'PO_LINES_INT', 'PO Lines', 2, 'DMT_PO_LINES_INT_STG_TBL', 'DMT_PO_LINES_INT_STG_TBL.csv', 7, 'PO_HEADERS_INT', 'Y' from dual
    union all select 'PO_LINE_LOCS_INT', 'PO Line Locations', 2, 'DMT_PO_LINE_LOCS_INT_STG_TBL', 'DMT_PO_LINE_LOCS_INT_STG_TBL.csv', 8, 'PO_HEADERS_INT', 'Y' from dual
    union all select 'PO_DISTS_INT', 'PO Distributions', 2, 'DMT_PO_DISTS_INT_STG_TBL', 'DMT_PO_DISTS_INT_STG_TBL.csv', 9, 'PO_HEADERS_INT', 'Y' from dual
    -- APInvoices  (page 2 -- P2P (Procure to Pay))
    union all select 'AP_INVOICES_INT', 'AP Invoice Headers', 2, 'DMT_AP_INVOICES_INT_STG_TBL', 'DMT_AP_INVOICES_INT_STG_TBL.csv', 10, null, 'Y' from dual
    union all select 'AP_INVOICE_LINES_INT', 'AP Invoice Lines', 2, 'DMT_AP_INVOICE_LINES_INT_STG_TBL', 'DMT_AP_INVOICE_LINES_INT_STG_TBL.csv', 11, 'AP_INVOICES_INT', 'Y' from dual
    -- ARInvoices  (page 4 -- O2C (Order to Cash))
    union all select 'RA_LINES', 'AR Lines', 4, 'DMT_RA_LINES_STG_TBL', 'DMT_RA_LINES_STG_TBL.csv', 12, null, 'Y' from dual
    union all select 'RA_DISTS', 'AR Distributions', 4, 'DMT_RA_DISTS_STG_TBL', 'DMT_RA_DISTS_STG_TBL.csv', 13, 'RA_LINES', 'Y' from dual
    -- Requisitions  (page 2 -- P2P (Procure to Pay))
    union all select 'POR_REQ_HEADERS', 'Req Headers', 2, 'DMT_POR_REQ_HEADERS_STG_TBL', 'DMT_POR_REQ_HEADERS_STG_TBL.csv', 14, null, 'Y' from dual
    union all select 'POR_REQ_LINES', 'Req Lines', 2, 'DMT_POR_REQ_LINES_STG_TBL', 'DMT_POR_REQ_LINES_STG_TBL.csv', 15, 'POR_REQ_HEADERS', 'Y' from dual
    union all select 'POR_REQ_DISTS', 'Req Distributions', 2, 'DMT_POR_REQ_DISTS_STG_TBL', 'DMT_POR_REQ_DISTS_STG_TBL.csv', 16, 'POR_REQ_HEADERS', 'Y' from dual
    -- MiscReceipts  (page 2 -- P2P (Procure to Pay))
    union all select 'INV_TRX', 'Inventory Transactions', 2, 'DMT_INV_TRX_STG_TBL', 'DMT_INV_TRX_STG_TBL.csv', 17, null, 'Y' from dual
    union all select 'INV_TRX_LOTS', 'Transaction Lots', 2, 'DMT_INV_TRX_LOTS_STG_TBL', 'DMT_INV_TRX_LOTS_STG_TBL.csv', 18, 'INV_TRX', 'Y' from dual
    union all select 'INV_TRX_SERIALS', 'Transaction Serials', 2, 'DMT_INV_TRX_SERIALS_STG_TBL', 'DMT_INV_TRX_SERIALS_STG_TBL.csv', 19, 'INV_TRX', 'Y' from dual
    -- Customers  (page 4 -- O2C (Order to Cash))
    union all select 'HZ_PARTIES', 'Parties', 4, 'DMT_HZ_PARTIES_STG_TBL', 'DMT_HZ_PARTIES_STG_TBL.csv', 20, null, 'Y' from dual
    union all select 'HZ_LOCATIONS', 'Locations', 4, 'DMT_HZ_LOCATIONS_STG_TBL', 'DMT_HZ_LOCATIONS_STG_TBL.csv', 21, 'HZ_PARTIES', 'Y' from dual
    union all select 'HZ_PARTY_SITES', 'Party Sites', 4, 'DMT_HZ_PARTY_SITES_STG_TBL', 'DMT_HZ_PARTY_SITES_STG_TBL.csv', 22, 'HZ_PARTIES', 'Y' from dual
    union all select 'HZ_PARTY_SITE_USES', 'Party Site Uses', 4, 'DMT_HZ_PARTY_SITE_USES_STG_TBL', 'DMT_HZ_PARTY_SITE_USES_STG_TBL.csv', 23, 'HZ_PARTIES', 'Y' from dual
    union all select 'HZ_ACCOUNTS', 'Accounts', 4, 'DMT_HZ_ACCOUNTS_STG_TBL', 'DMT_HZ_ACCOUNTS_STG_TBL.csv', 24, 'HZ_PARTIES', 'Y' from dual
    union all select 'HZ_ACCT_SITES', 'Account Sites', 4, 'DMT_HZ_ACCT_SITES_STG_TBL', 'DMT_HZ_ACCT_SITES_STG_TBL.csv', 25, 'HZ_PARTIES', 'Y' from dual
    union all select 'HZ_ACCT_SITE_USES', 'Account Site Uses', 4, 'DMT_HZ_ACCT_SITE_USES_STG_TBL', 'DMT_HZ_ACCT_SITE_USES_STG_TBL.csv', 26, 'HZ_PARTIES', 'Y' from dual
    -- GLBalances  (page 3 -- Financials)
    union all select 'GL_INTERFACE', 'GL Journals', 3, 'DMT_GL_INTERFACE_STG_TBL', 'DMT_GL_INTERFACE_STG_TBL.csv', 27, null, 'Y' from dual
    -- GLBudgets  (page 3 -- Financials)
    union all select 'GL_BUDGET_INT', 'GL Budget Balances', 3, 'DMT_GL_BUDGET_INT_STG_TBL', 'DMT_GL_BUDGET_INT_STG_TBL.csv', 28, null, 'Y' from dual
    -- Assets  (page 3 -- Financials)
    union all select 'FA_ASSET_HDR', 'Asset Headers', 3, 'DMT_FA_ASSET_HDR_STG_TBL', 'DMT_FA_ASSET_HDR_STG_TBL.csv', 29, null, 'Y' from dual
    union all select 'FA_ASSET_BOOK', 'Asset Books', 3, 'DMT_FA_ASSET_BOOK_STG_TBL', 'DMT_FA_ASSET_BOOK_STG_TBL.csv', 30, 'FA_ASSET_HDR', 'Y' from dual
    union all select 'FA_ASSET_ASSIGN', 'Asset Assignments', 3, 'DMT_FA_ASSET_ASSIGN_STG_TBL', 'DMT_FA_ASSET_ASSIGN_STG_TBL.csv', 31, 'FA_ASSET_HDR', 'Y' from dual
    -- Projects  (page 5 -- Projects)
    union all select 'PJF_PROJECTS', 'Projects', 5, 'DMT_PJF_PROJECTS_STG_TBL', 'DMT_PJF_PROJECTS_STG_TBL.csv', 32, null, 'Y' from dual
    union all select 'PJF_TASKS', 'Project Tasks', 5, 'DMT_PJF_TASKS_STG_TBL', 'DMT_PJF_TASKS_STG_TBL.csv', 33, 'PJF_PROJECTS', 'Y' from dual
    union all select 'PJF_TEAM_MEMBERS', 'Team Members', 5, 'DMT_PJF_TEAM_MEMBERS_STG_TBL', 'DMT_PJF_TEAM_MEMBERS_STG_TBL.csv', 34, 'PJF_PROJECTS', 'Y' from dual
    union all select 'PJC_TXN_CONTROLS', 'Txn Controls', 5, 'DMT_PJC_TXN_CONTROLS_STG_TBL', 'DMT_PJC_TXN_CONTROLS_STG_TBL.csv', 35, 'PJF_PROJECTS', 'Y' from dual
    -- Expenditures  (page 5 -- Projects)
    union all select 'PJC_EXPENDITURES', 'Project Expenditures', 5, 'DMT_PJC_EXPENDITURES_STG_TBL', 'DMT_PJC_EXPENDITURES_STG_TBL.csv', 36, null, 'Y' from dual
    -- ProjectBudgets  (page 5 -- Projects)
    union all select 'PRJ_BUDGET', 'Project Budgets', 5, 'DMT_PRJ_BUDGET_STG_TBL', 'DMT_PRJ_BUDGET_STG_TBL.csv', 37, null, 'Y' from dual
    -- BillingEvents  (page 5 -- Projects)
    union all select 'PJB_BILL_EVENTS', 'Billing Events', 5, 'DMT_PJB_BILL_EVENTS_STG_TBL', 'DMT_PJB_BILL_EVENTS_STG_TBL.csv', 38, null, 'Y' from dual
    -- Items  (page 8 -- Other)
    union all select 'EGP_ITEM', 'Item Master', 8, 'DMT_EGP_ITEM_STG_TBL', 'DMT_EGP_ITEM_STG_TBL.csv', 39, null, 'Y' from dual
    union all select 'EGP_ITEM_CAT', 'Item Categories', 8, 'DMT_EGP_ITEM_CAT_STG_TBL', 'DMT_EGP_ITEM_CAT_STG_TBL.csv', 40, 'EGP_ITEM', 'Y' from dual
    -- Workers  (page 6 -- HCM)
    union all select 'WORKER', 'Workers', 6, 'DMT_WORKER_STG_TBL', 'DMT_WORKER_STG_TBL.csv', 41, null, 'Y' from dual
    union all select 'PERSON_NAME', 'Person Names', 6, 'DMT_PERSON_NAME_STG_TBL', 'DMT_PERSON_NAME_STG_TBL.csv', 42, 'WORKER', 'Y' from dual
    union all select 'PERSON_EMAIL', 'Person Emails', 6, 'DMT_PERSON_EMAIL_STG_TBL', 'DMT_PERSON_EMAIL_STG_TBL.csv', 43, 'WORKER', 'Y' from dual
    union all select 'PERSON_PHONE', 'Person Phones', 6, 'DMT_PERSON_PHONE_STG_TBL', 'DMT_PERSON_PHONE_STG_TBL.csv', 44, 'WORKER', 'Y' from dual
    union all select 'PERSON_ADDR', 'Person Addresses', 6, 'DMT_PERSON_ADDR_STG_TBL', 'DMT_PERSON_ADDR_STG_TBL.csv', 45, 'WORKER', 'Y' from dual
    union all select 'PERSON_NID', 'Person NIDs', 6, 'DMT_PERSON_NID_STG_TBL', 'DMT_PERSON_NID_STG_TBL.csv', 46, 'WORKER', 'Y' from dual
    union all select 'PERSON_LEGISL', 'Person Legislation', 6, 'DMT_PERSON_LEGISL_STG_TBL', 'DMT_PERSON_LEGISL_STG_TBL.csv', 47, 'WORKER', 'Y' from dual
    -- Assignments  (page 6 -- HCM)
    union all select 'WORK_REL', 'Work Relationships', 6, 'DMT_WORK_REL_STG_TBL', 'DMT_WORK_REL_STG_TBL.csv', 48, null, 'Y' from dual
    union all select 'ASSIGNMENT', 'Assignments', 6, 'DMT_ASSIGNMENT_STG_TBL', 'DMT_ASSIGNMENT_STG_TBL.csv', 49, 'WORK_REL', 'Y' from dual
    -- Salaries  (page 6 -- HCM)
    union all select 'SALARY', 'Salaries', 6, 'DMT_SALARY_STG_TBL', 'DMT_SALARY_STG_TBL.csv', 50, null, 'Y' from dual
    -- SalaryBases  (page 6 -- HCM)
    union all select 'SAL_BASIS', 'Salary Bases', 6, 'DMT_SAL_BASIS_STG_TBL', 'DMT_SAL_BASIS_STG_TBL.csv', 51, null, 'Y' from dual
    -- PayrollRelationships  (page 6 -- HCM)
    union all select 'PAY_REL', 'Payroll Relationships', 6, 'DMT_PAY_REL_STG_TBL', 'DMT_PAY_REL_STG_TBL.csv', 52, null, 'Y' from dual
    -- TaxCards  (page 6 -- HCM)
    union all select 'TAX_CARD', 'Tax Cards', 6, 'DMT_TAX_CARD_STG_TBL', 'DMT_TAX_CARD_STG_TBL.csv', 53, null, 'Y' from dual
    union all select 'TAX_CARD_COMP', 'Tax Card Components', 6, 'DMT_TAX_CARD_COMP_STG_TBL', 'DMT_TAX_CARD_COMP_STG_TBL.csv', 54, 'TAX_CARD', 'Y' from dual
    -- W2Balances  (page 6 -- HCM)
    union all select 'W2_BAL', 'W2 Balances', 6, 'DMT_W2_BAL_STG_TBL', 'DMT_W2_BAL_STG_TBL.csv', 55, null, 'Y' from dual
    union all select 'W2_BAL_DTL', 'W2 Balance Details', 6, 'DMT_W2_BAL_DTL_STG_TBL', 'DMT_W2_BAL_DTL_STG_TBL.csv', 56, 'W2_BAL', 'Y' from dual
    -- BenParticipant  (page 6 -- HCM)
    union all select 'BEN_PARTIC', 'Participant Enrollment', 6, 'DMT_BEN_PARTIC_STG_TBL', 'DMT_BEN_PARTIC_STG_TBL.csv', 57, null, 'Y' from dual
    -- BenDependent  (page 6 -- HCM)
    union all select 'BEN_DEPEND', 'Dependent Enrollment', 6, 'DMT_BEN_DEPEND_STG_TBL', 'DMT_BEN_DEPEND_STG_TBL.csv', 58, null, 'Y' from dual
    -- BenBeneficiary  (page 6 -- HCM)
    union all select 'BEN_BENFY', 'Beneficiary Enrollment', 6, 'DMT_BEN_BENFY_STG_TBL', 'DMT_BEN_BENFY_STG_TBL.csv', 59, null, 'Y' from dual
    -- Absences  (page 6 -- HCM)
    union all select 'ABSENCE', 'Absences', 6, 'DMT_ABSENCE_STG_TBL', 'DMT_ABSENCE_STG_TBL.csv', 60, null, 'Y' from dual
    -- TalentProfiles  (page 6 -- HCM)
    union all select 'TALENT_PROF', 'Talent Profiles', 6, 'DMT_TALENT_PROF_STG_TBL', 'DMT_TALENT_PROF_STG_TBL.csv', 61, null, 'Y' from dual
    union all select 'TALENT_PROF_ITEM', 'Profile Items', 6, 'DMT_TALENT_PROF_ITEM_STG_TBL', 'DMT_TALENT_PROF_ITEM_STG_TBL.csv', 62, 'TALENT_PROF', 'Y' from dual
    -- PerfEvaluations  (page 6 -- HCM)
    union all select 'PERF_EVAL', 'Performance Docs', 6, 'DMT_PERF_EVAL_STG_TBL', 'DMT_PERF_EVAL_STG_TBL.csv', 63, null, 'Y' from dual
    union all select 'PERF_EVAL_RATING', 'Performance Ratings', 6, 'DMT_PERF_EVAL_RATING_STG_TBL', 'DMT_PERF_EVAL_RATING_STG_TBL.csv', 64, 'PERF_EVAL', 'Y' from dual
    -- WorkSchedules  (page 6 -- HCM)
    union all select 'WORK_SCHED', 'Work Schedules', 6, 'DMT_WORK_SCHED_STG_TBL', 'DMT_WORK_SCHED_STG_TBL.csv', 65, null, 'Y' from dual
    union all select 'WORK_SCHED_DTL', 'Schedule Details', 6, 'DMT_WORK_SCHED_DTL_STG_TBL', 'DMT_WORK_SCHED_DTL_STG_TBL.csv', 66, 'WORK_SCHED', 'Y' from dual
    -- GLCalendar  (page 7 -- Configuration)
    union all select 'GL_CALENDAR', 'GL Calendar', 7, 'DMT_GL_CALENDAR_STG_TBL', 'DMT_GL_CALENDAR_STG_TBL.csv', 67, null, 'Y' from dual
    -- UnitsOfMeasure  (page 7 -- Configuration)
    union all select 'INV_UOM', 'Units of Measure', 7, 'DMT_INV_UOM_STG_TBL', 'DMT_INV_UOM_STG_TBL.csv', 68, null, 'Y' from dual
    -- Lookups  (page 7 -- Configuration)
    union all select 'FND_LOOKUP_TYPE', 'Lookup Types', 7, 'DMT_FND_LOOKUP_TYPE_STG_TBL', 'DMT_FND_LOOKUP_TYPE_STG_TBL.csv', 69, null, 'Y' from dual
    union all select 'FND_LOOKUP_VALUE', 'Lookup Values', 7, 'DMT_FND_LOOKUP_VALUE_STG_TBL', 'DMT_FND_LOOKUP_VALUE_STG_TBL.csv', 70, 'FND_LOOKUP_TYPE', 'Y' from dual
    -- ValueSets  (page 7 -- Configuration)
    union all select 'FND_VS_SET', 'Value Sets', 7, 'DMT_FND_VS_SET_STG_TBL', 'DMT_FND_VS_SET_STG_TBL.csv', 71, null, 'Y' from dual
    union all select 'FND_VS_VALUE', 'Value Set Values', 7, 'DMT_FND_VS_VALUE_STG_TBL', 'DMT_FND_VS_VALUE_STG_TBL.csv', 72, 'FND_VS_SET', 'Y' from dual
    -- PaymentTerms  (page 7 -- Configuration)
    union all select 'AP_PAY_TERM_HDR', 'Payment Term Headers', 7, 'DMT_AP_PAY_TERM_HDR_STG_TBL', 'DMT_AP_PAY_TERM_HDR_STG_TBL.csv', 73, null, 'Y' from dual
    union all select 'AP_PAY_TERM_LINE', 'Payment Term Lines', 7, 'DMT_AP_PAY_TERM_LINE_STG_TBL', 'DMT_AP_PAY_TERM_LINE_STG_TBL.csv', 74, 'AP_PAY_TERM_HDR', 'Y' from dual
    -- TaxConfig  (page 7 -- Configuration)
    union all select 'ZX_REGIME', 'Tax Regimes', 7, 'DMT_ZX_REGIME_STG_TBL', 'DMT_ZX_REGIME_STG_TBL.csv', 75, null, 'Y' from dual
    union all select 'ZX_RATE', 'Tax Rates', 7, 'DMT_ZX_RATE_STG_TBL', 'DMT_ZX_RATE_STG_TBL.csv', 76, 'ZX_REGIME', 'Y' from dual
    -- Banks  (page 7 -- Configuration)
    union all select 'CE_BANK', 'Banks', 7, 'DMT_CE_BANK_STG_TBL', 'DMT_CE_BANK_STG_TBL.csv', 77, null, 'Y' from dual
    union all select 'CE_BRANCH', 'Bank Branches', 7, 'DMT_CE_BRANCH_STG_TBL', 'DMT_CE_BRANCH_STG_TBL.csv', 78, 'CE_BANK', 'Y' from dual
    union all select 'CE_BANK_ACCT', 'Bank Accounts', 7, 'DMT_CE_BANK_ACCT_STG_TBL', 'DMT_CE_BANK_ACCT_STG_TBL.csv', 79, 'CE_BANK', 'Y' from dual
    -- Grants  (page 5 -- Projects)
    union all select 'GMS_AWD_HEADERS', 'Award Headers', 5, 'DMT_GMS_AWD_HEADERS_STG_TBL', 'DMT_GMS_AWD_HEADERS_STG_TBL.csv', 80, null, 'Y' from dual
    union all select 'GMS_AWD_PROJECTS', 'Award Projects', 5, 'DMT_GMS_AWD_PROJECTS_STG_TBL', 'DMT_GMS_AWD_PROJECTS_STG_TBL.csv', 81, 'GMS_AWD_HEADERS', 'Y' from dual
    union all select 'GMS_AWD_PERSONNEL', 'Award Personnel', 5, 'DMT_GMS_AWD_PERSONNEL_STG_TBL', 'DMT_GMS_AWD_PERSONNEL_STG_TBL.csv', 82, 'GMS_AWD_HEADERS', 'Y' from dual
    union all select 'GMS_AWD_FUNDING', 'Award Funding', 5, 'DMT_GMS_AWD_FUNDING_STG_TBL', 'DMT_GMS_AWD_FUNDING_STG_TBL.csv', 83, 'GMS_AWD_HEADERS', 'Y' from dual
    union all select 'GMS_AWD_FUND_SRC', 'Award Funding Sources', 5, 'DMT_GMS_AWD_FUND_SRC_STG_TBL', 'DMT_GMS_AWD_FUND_SRC_STG_TBL.csv', 84, 'GMS_AWD_HEADERS', 'Y' from dual
    union all select 'GMS_AWD_FUND_ALLOC', 'Award Funding Allocations', 5, 'DMT_GMS_AWD_FUND_ALLOC_STG_TBL', 'DMT_GMS_AWD_FUND_ALLOC_STG_TBL.csv', 85, 'GMS_AWD_HEADERS', 'Y' from dual
    union all select 'GMS_AWD_PRJ_FUND_SRC', 'Award Project Funding Sources', 5, 'DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL', 'DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL.csv', 86, 'GMS_AWD_HEADERS', 'Y' from dual
    union all select 'GMS_AWD_PRJ_TSK_BRD', 'Award Project Task Breakdown', 5, 'DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL', 'DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL.csv', 87, 'GMS_AWD_HEADERS', 'Y' from dual
    union all select 'GMS_AWD_BDGT_PRDS', 'Award Budget Periods', 5, 'DMT_GMS_AWD_BDGT_PRDS_STG_TBL', 'DMT_GMS_AWD_BDGT_PRDS_STG_TBL.csv', 88, 'GMS_AWD_HEADERS', 'Y' from dual
    union all select 'GMS_AWD_CFDAS', 'Award CFDAs', 5, 'DMT_GMS_AWD_CFDAS_STG_TBL', 'DMT_GMS_AWD_CFDAS_STG_TBL.csv', 89, 'GMS_AWD_HEADERS', 'Y' from dual
    union all select 'GMS_AWD_CERTS', 'Award Certifications', 5, 'DMT_GMS_AWD_CERTS_STG_TBL', 'DMT_GMS_AWD_CERTS_STG_TBL.csv', 90, 'GMS_AWD_HEADERS', 'Y' from dual
    union all select 'GMS_AWD_KEYWORDS', 'Award Keywords', 5, 'DMT_GMS_AWD_KEYWORDS_STG_TBL', 'DMT_GMS_AWD_KEYWORDS_STG_TBL.csv', 91, 'GMS_AWD_HEADERS', 'Y' from dual
    union all select 'GMS_AWD_ORG_CREDITS', 'Award Org Credits', 5, 'DMT_GMS_AWD_ORG_CREDITS_STG_TBL', 'DMT_GMS_AWD_ORG_CREDITS_STG_TBL.csv', 92, 'GMS_AWD_HEADERS', 'Y' from dual
    union all select 'GMS_AWD_REFERENCES', 'Award References', 5, 'DMT_GMS_AWD_REFERENCES_STG_TBL', 'DMT_GMS_AWD_REFERENCES_STG_TBL.csv', 93, 'GMS_AWD_HEADERS', 'Y' from dual
    union all select 'GMS_AWD_TERMS', 'Award Terms', 5, 'DMT_GMS_AWD_TERMS_STG_TBL', 'DMT_GMS_AWD_TERMS_STG_TBL.csv', 94, 'GMS_AWD_HEADERS', 'Y' from dual
) s
on (t."OBJECT_CODE" = s.object_code)
when matched then update set
    t."DISPLAY_NAME"        = s.display_name,
    t."PAGE_NUMBER"         = s.page_number,
    t."STAGING_TABLE"       = s.staging_table,
    t."CSV_FILENAME"        = s.csv_filename,
    t."DISPLAY_ORDER"       = s.display_order,
    t."PARENT_OBJECT_CODE"  = s.parent_object_code,
    t."IS_ACTIVE"           = s.is_active
when not matched then insert
    ("OBJECT_CODE","DISPLAY_NAME","PAGE_NUMBER","STAGING_TABLE","CSV_FILENAME","DISPLAY_ORDER","PARENT_OBJECT_CODE","IS_ACTIVE")
    values (s.object_code, s.display_name, s.page_number, s.staging_table, s.csv_filename, s.display_order, s.parent_object_code, s.is_active);

commit;

-- Regenerate the column dictionary from USER_TAB_COLUMNS for every object
-- registered above. This is what makes every business column of every child
-- table uploadable at full fidelity; it also (re)marks the admin/infrastructure
-- columns so they are never taken from the CSV.
begin
    DMT_UPLOAD_DICT_PKG.SEED_DICTIONARY;
end;
/
