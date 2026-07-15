-- DMT_V_CEMLI_TFM_TABLES
CREATE OR REPLACE EDITIONABLE VIEW "DMT_V_CEMLI_TFM_TABLES" ("CEMLI_CODE", "TFM_TABLE", "DISPLAY_NAME", "SORT_ORDER", "STATUS_COLUMN", "ROW_FILTER")  AS 
  SELECT 'Suppliers'              AS CEMLI_CODE, 'DMT_POZ_SUPPLIERS_TFM_TBL'       AS TFM_TABLE, 'Suppliers'                AS DISPLAY_NAME, 1 AS SORT_ORDER, 'TFM_STATUS' AS STATUS_COLUMN, NULL AS ROW_FILTER FROM DUAL
UNION ALL SELECT 'SupplierAddresses',    'DMT_POZ_SUP_ADDR_TFM_TBL',       'Supplier Addresses',       1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'SupplierSites',        'DMT_POZ_SUP_SITE_TFM_TBL',       'Supplier Sites',           1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'SupplierSiteAssignments','DMT_POZ_SUP_SITE_ASSN_TFM_TBL','Site Assignments',         1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'SupplierContacts',     'DMT_POZ_SUP_CONTACTS_TFM_TBL',   'Supplier Contacts',        1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'PurchaseOrders',       'DMT_PO_HEADERS_INT_TFM_TBL',     'PO Headers',               1, 'TFM_STATUS', 'STYLE_DISPLAY_NAME = ''Purchase Order''' FROM DUAL
UNION ALL SELECT 'PurchaseOrders',       'DMT_PO_LINES_INT_TFM_TBL',       'PO Lines',                 2, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'PurchaseOrders',       'DMT_PO_LINE_LOCS_INT_TFM_TBL',   'PO Line Locations',        3, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'PurchaseOrders',       'DMT_PO_DISTS_INT_TFM_TBL',       'PO Distributions',         4, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'BlanketPOs',           'DMT_PO_HEADERS_INT_TFM_TBL',     'Blanket PO Headers',       1, 'TFM_STATUS', 'STYLE_DISPLAY_NAME = ''Blanket Purchase Agreement''' FROM DUAL
UNION ALL SELECT 'BlanketPOs',           'DMT_PO_LINES_INT_TFM_TBL',       'Blanket PO Lines',         2, 'TFM_STATUS', 'INTERFACE_HEADER_KEY IN (SELECT INTERFACE_HEADER_KEY FROM DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL WHERE STYLE_DISPLAY_NAME = ''Blanket Purchase Agreement'')' FROM DUAL
UNION ALL SELECT 'Contracts',            'DMT_PO_HEADERS_INT_TFM_TBL',     'Contract Headers',         1, 'TFM_STATUS', 'STYLE_DISPLAY_NAME = ''Contract Purchase Agreement''' FROM DUAL
UNION ALL SELECT 'APInvoices',           'DMT_AP_INVOICES_INT_TFM_TBL',    'AP Invoice Headers',       1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'APInvoices',           'DMT_AP_INVOICE_LINES_INT_TFM_TBL','AP Invoice Lines',        2, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Customers',            'DMT_HZ_PARTIES_TFM_TBL',         'Parties',                  1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Customers',            'DMT_HZ_LOCATIONS_TFM_TBL',       'Locations',                2, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Customers',            'DMT_HZ_PARTY_SITES_TFM_TBL',     'Party Sites',              3, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Customers',            'DMT_HZ_PARTY_SITE_USES_TFM_TBL', 'Party Site Uses',          4, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Customers',            'DMT_HZ_ACCOUNTS_TFM_TBL',        'Accounts',                 5, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Customers',            'DMT_HZ_ACCT_SITES_TFM_TBL',      'Account Sites',            6, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Customers',            'DMT_HZ_ACCT_SITE_USES_TFM_TBL',  'Account Site Uses',        7, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'ARInvoices',           'DMT_RA_LINES_TFM_TBL',           'AR Lines',                 1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'ARInvoices',           'DMT_RA_DISTS_TFM_TBL',           'AR Distributions',         2, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Projects',             'DMT_PJF_PROJECTS_TFM_TBL',       'Projects',                 1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Projects',             'DMT_PJF_TASKS_TFM_TBL',          'Project Tasks',            2, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Projects',             'DMT_PJF_TEAM_MEMBERS_TFM_TBL',   'Team Members',             3, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Projects',             'DMT_PJC_TXN_CONTROLS_TFM_TBL',   'Txn Controls',            4, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'BillingEvents',        'DMT_PJB_BILL_EVENTS_TFM_TBL',    'Billing Events',           1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Expenditures',         'DMT_PJC_EXPENDITURES_TFM_TBL',   'Project Expenditures',     1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Grants',               'DMT_GMS_AWD_HEADERS_TFM_TBL',    'Award Headers',            1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'ProjectBudgets',       'DMT_PRJ_BUDGET_TFM_TBL',         'Project Budget Lines',     1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'GLBalances',           'DMT_GL_INTERFACE_TFM_TBL',       'GL Journals',              1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'GLBudgets',            'DMT_GL_BUDGET_INT_TFM_TBL',      'GL Budget Balances',       1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'PlanningBudgets',      'DMT_PLAN_BUDGET_TFM_TBL',        'Planning Budgets',         1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Assets',               'DMT_FA_ASSET_HDR_TFM_TBL',       'Asset Headers',            1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Assets',               'DMT_FA_ASSET_BOOK_TFM_TBL',      'Asset Books',              2, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Assets',               'DMT_FA_ASSET_ASSIGN_TFM_TBL',    'Asset Assignments',        3, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Requisitions',         'DMT_POR_REQ_HEADERS_TFM_TBL',    'Req Headers',              1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Requisitions',         'DMT_POR_REQ_LINES_TFM_TBL',      'Req Lines',                2, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Requisitions',         'DMT_POR_REQ_DISTS_TFM_TBL',      'Req Distributions',        3, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'MiscReceipts',         'DMT_RCV_HEADERS_TFM_TBL',        'Receipt Headers',          1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'MiscReceipts',         'DMT_RCV_TRANSACTIONS_TFM_TBL',   'Receipt Transactions',     2, 'TFM_STATUS', NULL FROM DUAL
-- Items: item master + bundled item categories ship in one FBDI ZIP under the 'Items' CEMLI,
-- so both TFM tables surface as sub-objects of the single Items card. Both use TFM_STATUS.
UNION ALL SELECT 'Items',                'DMT_EGP_ITEM_TFM_TBL',           'Item Master',              1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Items',                'DMT_EGP_ITEM_CAT_TFM_TBL',       'Item Categories',          2, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Workers',              'DMT_WORKER_TFM_TBL',             'Workers',                  1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Workers',              'DMT_PERSON_NAME_TFM_TBL',        'Person Names',             2, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Workers',              'DMT_PERSON_EMAIL_TFM_TBL',       'Person Emails',            3, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Workers',              'DMT_PERSON_PHONE_TFM_TBL',       'Person Phones',            4, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Workers',              'DMT_PERSON_ADDR_TFM_TBL',        'Person Addresses',         5, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Workers',              'DMT_PERSON_NID_TFM_TBL',         'Person NIDs',              6, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Workers',              'DMT_PERSON_LEGISL_TFM_TBL',      'Person Legislation',       7, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Workers',              'DMT_WORK_REL_TFM_TBL',           'Work Relationships',       8, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Assignments',          'DMT_ASSIGNMENT_TFM_TBL',         'Assignments',              1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Salaries',             'DMT_SALARY_TFM_TBL',             'Salaries',                 1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'SalaryBases',          'DMT_SAL_BASIS_TFM_TBL',          'Salary Bases',             1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'PayrollRels',          'DMT_PAY_REL_TFM_TBL',            'Payroll Relationships',    1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'TaxCards',             'DMT_TAX_CARD_TFM_TBL',           'Tax Cards',                1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'TaxCards',             'DMT_TAX_CARD_COMP_TFM_TBL',      'Tax Card Components',      2, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'W2Balances',           'DMT_W2_BAL_TFM_TBL',             'W2 Balances',              1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'W2Balances',           'DMT_W2_BAL_DTL_TFM_TBL',         'W2 Balance Details',       2, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'BenParticipant',       'DMT_BEN_PARTIC_TFM_TBL',         'Participant Enrollment',   1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'BenDependent',         'DMT_BEN_DEPEND_TFM_TBL',         'Dependent Enrollment',     1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'BenBeneficiary',       'DMT_BEN_BENFY_TFM_TBL',          'Beneficiary Enrollment',   1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'Absences',             'DMT_ABSENCE_TFM_TBL',            'Absences',                 1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'TalentProfiles',       'DMT_TALENT_PROF_TFM_TBL',        'Talent Profiles',          1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'TalentProfiles',       'DMT_TALENT_PROF_ITEM_TFM_TBL',   'Profile Items',            2, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'PerfEvaluations',      'DMT_PERF_EVAL_TFM_TBL',          'Performance Docs',         1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'PerfEvaluations',      'DMT_PERF_EVAL_RATING_TFM_TBL',   'Performance Ratings',      2, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'WorkSchedules',        'DMT_WORK_SCHED_TFM_TBL',         'Work Schedules',           1, 'TFM_STATUS', NULL FROM DUAL
UNION ALL SELECT 'WorkSchedules',        'DMT_WORK_SCHED_DTL_TFM_TBL',     'Schedule Details',         2, 'TFM_STATUS', NULL FROM DUAL;
