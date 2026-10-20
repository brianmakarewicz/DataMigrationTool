# Upload verification (local) - 2026-10-19T22:08

Backlog #786. Per format one zip of every object, uploaded once through Smart Upload (page 25) in a real browser into its own scenario, then one pipeline run of that scenario on local (console http://localhost:8182/ords). Baseline data: RegressionTest261013111321 (regression run 416 gives each row's expected outcome). Code: aea47c8.

**header format:** scenario UPL-HDR-2610192208, 62 files, page OK, 0 upload error row(s); run 417, prefix 93440, COMPLETED_ERRORS.
Comparison with the baseline before the run: CLEAN.

| Staging table | Baseline rows | Uploaded rows | Matched | Missing | Extra | Columns compared | Columns excluded | Differences |
|---|---|---|---|---|---|---|---|---|
| DMT_POZ_SUPPLIERS_STG_TBL | 3 | 3 | 3 | 0 | 0 | 156 | 6 | - |
| DMT_POZ_SUP_ADDR_STG_TBL | 4 | 4 | 4 | 0 | 0 | 110 | 6 | - |
| DMT_POZ_SUP_SITE_STG_TBL | 4 | 4 | 4 | 0 | 0 | 200 | 6 | - |
| DMT_POZ_SUP_SITE_ASSN_STG_TBL | 3 | 3 | 3 | 0 | 0 | 16 | 6 | - |
| DMT_POZ_SUP_CONTACTS_STG_TBL | 4 | 4 | 4 | 0 | 0 | 90 | 6 | - |
| DMT_PO_HEADERS_INT_STG_TBL | 9 | 9 | 9 | 0 | 0 | 100 | 6 | - |
| DMT_PO_LINES_INT_STG_TBL | 9 | 9 | 9 | 0 | 0 | 99 | 6 | - |
| DMT_PO_LINE_LOCS_INT_STG_TBL | 5 | 5 | 5 | 0 | 0 | 94 | 6 | - |
| DMT_PO_DISTS_INT_STG_TBL | 5 | 5 | 5 | 0 | 0 | 125 | 6 | - |
| DMT_AP_INVOICES_INT_STG_TBL | 5 | 5 | 5 | 0 | 0 | 136 | 6 | - |
| DMT_AP_INVOICE_LINES_INT_STG_TBL | 6 | 6 | 6 | 0 | 0 | 165 | 6 | - |
| DMT_RA_LINES_STG_TBL | 11 | 11 | 11 | 0 | 0 | 171 | 6 | - |
| DMT_RA_DISTS_STG_TBL | 12 | 12 | 12 | 0 | 0 | 70 | 6 | - |
| DMT_POR_REQ_HEADERS_STG_TBL | 6 | 6 | 6 | 0 | 0 | 70 | 6 | - |
| DMT_POR_REQ_LINES_STG_TBL | 7 | 7 | 7 | 0 | 0 | 117 | 6 | - |
| DMT_POR_REQ_DISTS_STG_TBL | 7 | 7 | 7 | 0 | 0 | 117 | 6 | - |
| DMT_HZ_PARTIES_STG_TBL | 7 | 7 | 7 | 0 | 0 | 40 | 6 | - |
| DMT_HZ_LOCATIONS_STG_TBL | 7 | 7 | 7 | 0 | 0 | 51 | 6 | - |
| DMT_HZ_PARTY_SITES_STG_TBL | 7 | 7 | 7 | 0 | 0 | 39 | 6 | - |
| DMT_HZ_PARTY_SITE_USES_STG_TBL | 8 | 8 | 8 | 0 | 0 | 34 | 6 | - |
| DMT_HZ_ACCOUNTS_STG_TBL | 7 | 7 | 7 | 0 | 0 | 34 | 6 | - |
| DMT_HZ_ACCT_SITES_STG_TBL | 7 | 7 | 7 | 0 | 0 | 39 | 6 | - |
| DMT_HZ_ACCT_SITE_USES_STG_TBL | 7 | 7 | 7 | 0 | 0 | 36 | 6 | - |
| DMT_GL_INTERFACE_STG_TBL | 8 | 8 | 8 | 0 | 0 | 151 | 6 | - |
| DMT_GL_BUDGET_INT_STG_TBL | 5 | 5 | 5 | 0 | 0 | 40 | 6 | - |
| DMT_FA_ASSET_HDR_STG_TBL | 9 | 9 | 9 | 0 | 0 | 38 | 6 | - |
| DMT_FA_ASSET_BOOK_STG_TBL | 9 | 9 | 9 | 0 | 0 | 17 | 6 | - |
| DMT_FA_ASSET_ASSIGN_STG_TBL | 9 | 9 | 9 | 0 | 0 | 20 | 6 | - |
| DMT_PJF_PROJECTS_STG_TBL | 6 | 6 | 6 | 0 | 0 | 158 | 6 | - |
| DMT_PJF_TASKS_STG_TBL | 7 | 7 | 7 | 0 | 0 | 124 | 6 | - |
| DMT_PJF_TEAM_MEMBERS_STG_TBL | 6 | 6 | 6 | 0 | 0 | 16 | 6 | - |
| DMT_PJC_TXN_CONTROLS_STG_TBL | 6 | 6 | 6 | 0 | 0 | 20 | 6 | - |
| DMT_PJC_EXPENDITURES_STG_TBL | 8 | 8 | 8 | 0 | 0 | 120 | 6 | - |
| DMT_PRJ_BUDGET_STG_TBL | 6 | 6 | 6 | 0 | 0 | 62 | 6 | - |
| DMT_PJB_BILL_EVENTS_STG_TBL | 3 | 3 | 3 | 0 | 0 | 79 | 6 | - |
| DMT_EGP_ITEM_STG_TBL | 4 | 4 | 4 | 0 | 0 | 172 | 6 | - |
| DMT_EGP_ITEM_CAT_STG_TBL | 5 | 5 | 5 | 0 | 0 | 13 | 6 | - |
| DMT_WORKER_STG_TBL | 4 | 4 | 4 | 0 | 0 | 16 | 6 | - |
| DMT_PERSON_NAME_STG_TBL | 3 | 3 | 3 | 0 | 0 | 47 | 6 | - |
| DMT_PERSON_EMAIL_STG_TBL | 1 | 1 | 1 | 0 | 0 | 9 | 6 | - |
| DMT_WORK_REL_STG_TBL | 3 | 3 | 3 | 0 | 0 | 9 | 6 | - |
| DMT_ASSIGNMENT_STG_TBL | 5 | 5 | 5 | 0 | 0 | 23 | 6 | - |
| DMT_SALARY_STG_TBL | 2 | 2 | 2 | 0 | 0 | 16 | 6 | - |
| DMT_SAL_BASIS_STG_TBL | 3 | 3 | 3 | 0 | 0 | 11 | 6 | - |
| DMT_ABSENCE_STG_TBL | 3 | 3 | 3 | 0 | 0 | 18 | 6 | - |
| DMT_TALENT_PROF_STG_TBL | 2 | 2 | 2 | 0 | 0 | 7 | 6 | - |
| DMT_TALENT_PROF_ITEM_STG_TBL | 2 | 2 | 2 | 0 | 0 | 10 | 6 | - |
| DMT_GMS_AWD_HEADERS_STG_TBL | 8 | 8 | 8 | 0 | 0 | 125 | 6 | - |
| DMT_GMS_AWD_PROJECTS_STG_TBL | 5 | 5 | 5 | 0 | 0 | 57 | 6 | - |
| DMT_GMS_AWD_PERSONNEL_STG_TBL | 7 | 7 | 7 | 0 | 0 | 62 | 6 | - |
| DMT_GMS_AWD_FUNDING_STG_TBL | 5 | 5 | 5 | 0 | 0 | 11 | 6 | - |
| DMT_GMS_AWD_FUND_SRC_STG_TBL | 5 | 5 | 5 | 0 | 0 | 9 | 6 | - |
| DMT_GMS_AWD_FUND_ALLOC_STG_TBL | 5 | 5 | 5 | 0 | 0 | 5 | 6 | - |
| DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL | 5 | 5 | 5 | 0 | 0 | 6 | 6 | - |
| DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL | 1 | 1 | 1 | 0 | 0 | 6 | 6 | - |
| DMT_GMS_AWD_BDGT_PRDS_STG_TBL | 5 | 5 | 5 | 0 | 0 | 5 | 6 | - |
| DMT_GMS_AWD_CFDAS_STG_TBL | 1 | 1 | 1 | 0 | 0 | 3 | 6 | - |
| DMT_GMS_AWD_CERTS_STG_TBL | 1 | 1 | 1 | 0 | 0 | 14 | 6 | - |
| DMT_GMS_AWD_KEYWORDS_STG_TBL | 1 | 1 | 1 | 0 | 0 | 4 | 6 | - |
| DMT_GMS_AWD_ORG_CREDITS_STG_TBL | 5 | 5 | 5 | 0 | 0 | 5 | 6 | - |
| DMT_GMS_AWD_REFERENCES_STG_TBL | 1 | 1 | 1 | 0 | 0 | 6 | 6 | - |
| DMT_GMS_AWD_TERMS_STG_TBL | 1 | 1 | 1 | 0 | 0 | 7 | 6 | - |
| parent link FA_ASSET_ASSIGN -> asset | | | | | | | | clean |


**fbdi format:** scenario UPL-FBDI-2610192306, 57 files, page OK, 0 upload error row(s); run 418, prefix 93443, FAILED.
Comparison with the baseline before the run: CLEAN.

| Staging table | Baseline rows | Uploaded rows | Matched | Missing | Extra | Columns compared | Columns excluded | Differences |
|---|---|---|---|---|---|---|---|---|
| DMT_POZ_SUPPLIERS_STG_TBL | 3 | 3 | 3 | 0 | 0 | 155 | 7 | - |
| DMT_POZ_SUP_ADDR_STG_TBL | 4 | 4 | 4 | 0 | 0 | 109 | 7 | - |
| DMT_POZ_SUP_SITE_STG_TBL | 4 | 4 | 4 | 0 | 0 | 199 | 7 | - |
| DMT_POZ_SUP_SITE_ASSN_STG_TBL | 3 | 3 | 3 | 0 | 0 | 15 | 7 | - |
| DMT_POZ_SUP_CONTACTS_STG_TBL | 4 | 4 | 4 | 0 | 0 | 89 | 7 | - |
| DMT_PO_HEADERS_INT_STG_TBL | 9 | 9 | 9 | 0 | 0 | 86 | 20 | - |
| DMT_PO_LINES_INT_STG_TBL | 9 | 9 | 9 | 0 | 0 | 65 | 40 | - |
| DMT_PO_LINE_LOCS_INT_STG_TBL | 5 | 5 | 5 | 0 | 0 | 93 | 7 | - |
| DMT_PO_DISTS_INT_STG_TBL | 5 | 5 | 5 | 0 | 0 | 124 | 7 | - |
| DMT_AP_INVOICES_INT_STG_TBL | 5 | 5 | 5 | 0 | 0 | 134 | 8 | - |
| DMT_AP_INVOICE_LINES_INT_STG_TBL | 6 | 6 | 6 | 0 | 0 | 163 | 8 | - |
| DMT_RA_LINES_STG_TBL | 11 | 11 | 11 | 0 | 0 | 169 | 8 | - |
| DMT_RA_DISTS_STG_TBL | 12 | 12 | 12 | 0 | 0 | 69 | 7 | - |
| DMT_POR_REQ_HEADERS_STG_TBL | 6 | 6 | 6 | 0 | 0 | 69 | 7 | - |
| DMT_POR_REQ_LINES_STG_TBL | 7 | 7 | 7 | 0 | 0 | 116 | 7 | - |
| DMT_POR_REQ_DISTS_STG_TBL | 7 | 7 | 7 | 0 | 0 | 116 | 7 | - |
| DMT_INV_TRX_STG_TBL | 8 | 8 | 8 | 0 | 0 | 257 | 7 | - |
| DMT_INV_TRX_LOTS_STG_TBL | 3 | 3 | 3 | 0 | 0 | 10 | 139 | - |
| DMT_INV_TRX_SERIALS_STG_TBL | 3 | 3 | 3 | 0 | 0 | 3 | 110 | - |
| DMT_HZ_PARTIES_STG_TBL | 7 | 7 | 7 | 0 | 0 | 39 | 7 | - |
| DMT_HZ_LOCATIONS_STG_TBL | 7 | 7 | 7 | 0 | 0 | 50 | 7 | - |
| DMT_HZ_PARTY_SITES_STG_TBL | 7 | 7 | 7 | 0 | 0 | 38 | 7 | - |
| DMT_HZ_PARTY_SITE_USES_STG_TBL | 8 | 8 | 8 | 0 | 0 | 33 | 7 | - |
| DMT_HZ_ACCOUNTS_STG_TBL | 7 | 7 | 7 | 0 | 0 | 33 | 7 | - |
| DMT_HZ_ACCT_SITES_STG_TBL | 7 | 7 | 7 | 0 | 0 | 38 | 7 | - |
| DMT_HZ_ACCT_SITE_USES_STG_TBL | 7 | 7 | 7 | 0 | 0 | 35 | 7 | - |
| DMT_GL_INTERFACE_STG_TBL | 8 | 8 | 8 | 0 | 0 | 77 | 80 | - |
| DMT_GL_BUDGET_INT_STG_TBL | 5 | 5 | 5 | 0 | 0 | 37 | 9 | - |
| DMT_FA_ASSET_HDR_STG_TBL | 9 | 9 | 9 | 0 | 0 | 37 | 7 | - |
| DMT_FA_ASSET_BOOK_STG_TBL | 9 | 9 | 9 | 0 | 0 | 14 | 9 | - |
| DMT_FA_ASSET_ASSIGN_STG_TBL | 9 | 9 | 9 | 0 | 0 | 18 | 8 | - |
| DMT_PJF_PROJECTS_STG_TBL | 6 | 6 | 6 | 0 | 0 | 157 | 7 | - |
| DMT_PJF_TASKS_STG_TBL | 7 | 7 | 7 | 0 | 0 | 122 | 8 | - |
| DMT_PJF_TEAM_MEMBERS_STG_TBL | 6 | 6 | 6 | 0 | 0 | 15 | 7 | - |
| DMT_PJC_TXN_CONTROLS_STG_TBL | 6 | 6 | 6 | 0 | 0 | 19 | 7 | - |
| DMT_PJC_EXPENDITURES_STG_TBL | 8 | 8 | 8 | 0 | 0 | 103 | 23 | - |
| DMT_PRJ_BUDGET_STG_TBL | 6 | 6 | 6 | 0 | 0 | 61 | 7 | - |
| DMT_PJB_BILL_EVENTS_STG_TBL | 3 | 3 | 3 | 0 | 0 | 78 | 7 | - |
| DMT_EGP_ITEM_STG_TBL | 4 | 4 | 4 | 0 | 0 | 169 | 9 | - |
| DMT_EGP_ITEM_CAT_STG_TBL | 5 | 5 | 5 | 0 | 0 | 12 | 7 | - |
| DMT_GMS_AWD_HEADERS_STG_TBL | 8 | 8 | 8 | 0 | 0 | 124 | 7 | - |
| DMT_GMS_AWD_PROJECTS_STG_TBL | 5 | 5 | 5 | 0 | 0 | 56 | 7 | - |
| DMT_GMS_AWD_PERSONNEL_STG_TBL | 7 | 7 | 7 | 0 | 0 | 61 | 7 | - |
| DMT_GMS_AWD_FUNDING_STG_TBL | 5 | 5 | 5 | 0 | 0 | 10 | 7 | - |
| DMT_GMS_AWD_FUND_SRC_STG_TBL | 5 | 5 | 5 | 0 | 0 | 8 | 7 | - |
| DMT_GMS_AWD_FUND_ALLOC_STG_TBL | 5 | 5 | 5 | 0 | 0 | 4 | 7 | - |
| DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL | 5 | 5 | 5 | 0 | 0 | 5 | 7 | - |
| DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL | 1 | 1 | 1 | 0 | 0 | 5 | 7 | - |
| DMT_GMS_AWD_BDGT_PRDS_STG_TBL | 5 | 5 | 5 | 0 | 0 | 4 | 7 | - |
| DMT_GMS_AWD_CFDAS_STG_TBL | 1 | 1 | 1 | 0 | 0 | 2 | 7 | - |
| DMT_GMS_AWD_CERTS_STG_TBL | 1 | 1 | 1 | 0 | 0 | 13 | 7 | - |
| DMT_GMS_AWD_KEYWORDS_STG_TBL | 1 | 1 | 1 | 0 | 0 | 3 | 7 | - |
| DMT_GMS_AWD_ORG_CREDITS_STG_TBL | 5 | 5 | 5 | 0 | 0 | 4 | 7 | - |
| DMT_GMS_AWD_REFERENCES_STG_TBL | 1 | 1 | 1 | 0 | 0 | 5 | 7 | - |
| DMT_GMS_AWD_TERMS_STG_TBL | 1 | 1 | 1 | 0 | 0 | 6 | 7 | - |
| parent link FA_ASSET_ASSIGN -> asset | | | | | | | | clean |
| parent link INV_TRX_LOTS -> transaction | | | | | | | | clean |
| parent link INV_TRX_SERIALS -> transaction | | | | | | | | clean |


| Object | Format | Upload | Run | GOOD | BAD | Unaccounted | Verdict |
|---|---|---|---|---|---|---|---|
| Items | header | upload OK (4/4 rows -> DMT_EGP_ITEM_STG_TBL, 5/5 rows -> DMT_EGP_ITEM_CAT_STG_TBL) | run 417, prefix 93440 | GOOD 6/6 LOADED | BAD 3/3 FAILED with error | unaccounted 0 | PASS |
| Items | fbdi | upload OK (4/4 rows -> DMT_EGP_ITEM_STG_TBL, 5/5 rows -> DMT_EGP_ITEM_CAT_STG_TBL) | run 418, prefix 93443 | GOOD 6/6 LOADED | BAD 3/3 FAILED with error | unaccounted 0 | PASS |
| Suppliers | header | upload OK (3/3 rows -> DMT_POZ_SUPPLIERS_STG_TBL) | run 417, prefix 93440 | GOOD 2/2 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS |
| Suppliers | fbdi | upload OK (3/3 rows -> DMT_POZ_SUPPLIERS_STG_TBL) | run 418, prefix 93443 | GOOD 2/2 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS |
| SupplierAddresses | header | upload OK (4/4 rows -> DMT_POZ_SUP_ADDR_STG_TBL) | run 417, prefix 93440 | GOOD 2/2 LOADED | BAD 2/2 FAILED with error | unaccounted 0 | PASS |
| SupplierAddresses | fbdi | upload OK (4/4 rows -> DMT_POZ_SUP_ADDR_STG_TBL) | run 418, prefix 93443 | GOOD 2/2 LOADED | BAD 2/2 FAILED with error | unaccounted 0 | PASS |
| SupplierSites | header | upload OK (4/4 rows -> DMT_POZ_SUP_SITE_STG_TBL) | run 417, prefix 93440 | GOOD 2/2 LOADED | BAD 2/2 FAILED with error | unaccounted 0 | PASS |
| SupplierSites | fbdi | upload OK (4/4 rows -> DMT_POZ_SUP_SITE_STG_TBL) | run 418, prefix 93443 | GOOD 2/2 LOADED | BAD 2/2 FAILED with error | unaccounted 0 | PASS |
| SupplierSiteAssignments | header | upload OK (3/3 rows -> DMT_POZ_SUP_SITE_ASSN_STG_TBL) | run 417, prefix 93440 | GOOD 2/2 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS |
| SupplierSiteAssignments | fbdi | upload OK (3/3 rows -> DMT_POZ_SUP_SITE_ASSN_STG_TBL) | run 418, prefix 93443 | GOOD 2/2 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS |
| SupplierContacts | header | upload OK (4/4 rows -> DMT_POZ_SUP_CONTACTS_STG_TBL) | run 417, prefix 93440 | GOOD 2/2 LOADED | BAD 2/2 FAILED with error | unaccounted 0 | PASS |
| SupplierContacts | fbdi | upload OK (4/4 rows -> DMT_POZ_SUP_CONTACTS_STG_TBL) | run 418, prefix 93443 | GOOD 2/2 LOADED | BAD 2/2 FAILED with error | unaccounted 0 | PASS |
| Requisitions | header | upload OK (6/6 rows -> DMT_POR_REQ_HEADERS_STG_TBL, 7/7 rows -> DMT_POR_REQ_LINES_STG_TBL, 7/7 rows -> DMT_POR_REQ_DISTS_STG_TBL) | run 417, prefix 93440 | GOOD 6/6 LOADED | BAD 14/14 FAILED with error | unaccounted 0 | PASS |
| Requisitions | fbdi | upload OK (6/6 rows -> DMT_POR_REQ_HEADERS_STG_TBL, 7/7 rows -> DMT_POR_REQ_LINES_STG_TBL, 7/7 rows -> DMT_POR_REQ_DISTS_STG_TBL) | run 418, prefix 93443 | GOOD 6/6 LOADED | BAD 14/14 FAILED with error | unaccounted 0 | PASS |
| PurchaseOrders | header | upload OK (9/9 rows -> DMT_PO_HEADERS_INT_STG_TBL, 9/9 rows -> DMT_PO_LINES_INT_STG_TBL, 5/5 rows -> DMT_PO_LINE_LOCS_INT_STG_TBL, 5/5 rows -> DMT_PO_DISTS_INT_STG_TBL) | run 417, prefix 93440 | GOOD 8/8 LOADED | BAD 11/11 FAILED with error | unaccounted 0 | PASS |
| PurchaseOrders | fbdi | upload OK (9/9 rows -> DMT_PO_HEADERS_INT_STG_TBL, 9/9 rows -> DMT_PO_LINES_INT_STG_TBL, 5/5 rows -> DMT_PO_LINE_LOCS_INT_STG_TBL, 5/5 rows -> DMT_PO_DISTS_INT_STG_TBL) | run 418, prefix 93443 | GOOD 8/8 LOADED | BAD 11/11 FAILED with error | unaccounted 0 | PASS |
| BlanketPOs | header | upload OK (9/9 rows -> DMT_PO_HEADERS_INT_STG_TBL, 9/9 rows -> DMT_PO_LINES_INT_STG_TBL) | run 417, prefix 93440 | GOOD 4/4 LOADED | BAD 3/3 FAILED with error | unaccounted 0 | PASS |
| BlanketPOs | fbdi | upload OK (9/9 rows -> DMT_PO_HEADERS_INT_STG_TBL, 9/9 rows -> DMT_PO_LINES_INT_STG_TBL) | run 418, prefix 93443 | GOOD 4/4 LOADED | BAD 3/3 FAILED with error | unaccounted 0 | PASS |
| Contracts | header | upload OK (9/9 rows -> DMT_PO_HEADERS_INT_STG_TBL) | run 417, prefix 93440 | GOOD 1/1 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS |
| Contracts | fbdi | upload OK (9/9 rows -> DMT_PO_HEADERS_INT_STG_TBL) | run 418, prefix 93443 | GOOD 1/1 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS |
| APInvoices | header | upload OK (5/5 rows -> DMT_AP_INVOICES_INT_STG_TBL, 6/6 rows -> DMT_AP_INVOICE_LINES_INT_STG_TBL) | run 417, prefix 93440 | GOOD 6/6 LOADED | BAD 5/5 FAILED with error | unaccounted 0 | PASS |
| APInvoices | fbdi | upload OK (5/5 rows -> DMT_AP_INVOICES_INT_STG_TBL, 6/6 rows -> DMT_AP_INVOICE_LINES_INT_STG_TBL) | run 418, prefix 93443 | GOOD 0/6 LOADED | BAD 1/5 FAILED with error | unaccounted 6 | FAIL: GOOD 0/6 LOADED with a Fusion id (3 FAILED); BAD 1/5 FAILED with an error; 6 unaccounted |
| MiscReceipts | header | - | - | - | - | - | FAIL: backlog #794: a header upload cannot link MiscReceipts lots and serials to their transaction (SOURCE_ID is copied from the source scenario); not uploaded or run in the header format until fixed |
| MiscReceipts | fbdi | upload OK (8/8 rows -> DMT_INV_TRX_STG_TBL, 3/3 rows -> DMT_INV_TRX_LOTS_STG_TBL, 3/3 rows -> DMT_INV_TRX_SERIALS_STG_TBL) | run 418, prefix 93443 | GOOD 3/5 LOADED | BAD 9/9 FAILED with error | unaccounted 0 | FAIL: GOOD 3/5 LOADED with a Fusion id (2 LOADED without their own Fusion id) |
| Customers | header | upload OK (7/7 rows -> DMT_HZ_PARTIES_STG_TBL, 7/7 rows -> DMT_HZ_LOCATIONS_STG_TBL, 7/7 rows -> DMT_HZ_PARTY_SITES_STG_TBL, 8/8 rows -> DMT_HZ_PARTY_SITE_USES_STG_TBL, 7/7 rows -> DMT_HZ_ACCOUNTS_STG_TBL, 7/7 rows -> DMT_HZ_ACCT_SITES_STG_TBL, 7/7 rows -> DMT_HZ_ACCT_SITE_USES_STG_TBL) | run 417, prefix 93440 | GOOD 19/19 LOADED | BAD 31/31 FAILED with error | unaccounted 0 | PASS |
| Customers | fbdi | upload OK (7/7 rows -> DMT_HZ_PARTIES_STG_TBL, 7/7 rows -> DMT_HZ_LOCATIONS_STG_TBL, 7/7 rows -> DMT_HZ_PARTY_SITES_STG_TBL, 8/8 rows -> DMT_HZ_PARTY_SITE_USES_STG_TBL, 7/7 rows -> DMT_HZ_ACCOUNTS_STG_TBL, 7/7 rows -> DMT_HZ_ACCT_SITES_STG_TBL, 7/7 rows -> DMT_HZ_ACCT_SITE_USES_STG_TBL) | run 418, prefix 93443 | GOOD 19/19 LOADED | BAD 31/31 FAILED with error | unaccounted 0 | PASS |
| ARInvoices | header | upload OK (11/11 rows -> DMT_RA_LINES_STG_TBL, 12/12 rows -> DMT_RA_DISTS_STG_TBL) | run 417, prefix 93440 | GOOD 13/13 LOADED | BAD 10/10 FAILED with error | unaccounted 0 | PASS |
| ARInvoices | fbdi | upload OK (11/11 rows -> DMT_RA_LINES_STG_TBL, 12/12 rows -> DMT_RA_DISTS_STG_TBL) | run 418, prefix 93443 | GOOD 13/13 LOADED | BAD 10/10 FAILED with error | unaccounted 0 | PASS |
| GLBalances | header | upload OK (8/8 rows -> DMT_GL_INTERFACE_STG_TBL) | run 417, prefix 93440 | GOOD 2/2 LOADED | BAD 6/6 FAILED with error | unaccounted 0 | PASS |
| GLBalances | fbdi | upload OK (8/8 rows -> DMT_GL_INTERFACE_STG_TBL) | run 418, prefix 93443 | GOOD 2/2 LOADED | BAD 6/6 FAILED with error | unaccounted 0 | PASS |
| GLBudgets | header | upload OK (5/5 rows -> DMT_GL_BUDGET_INT_STG_TBL) | run 417, prefix 93440 | GOOD 2/2 LOADED | BAD 3/3 FAILED with error | unaccounted 0 | PASS |
| GLBudgets | fbdi | upload OK (5/5 rows -> DMT_GL_BUDGET_INT_STG_TBL) | run 418, prefix 93443 | GOOD 2/2 LOADED | BAD 3/3 FAILED with error | unaccounted 0 | PASS |
| Assets | header | upload OK (9/9 rows -> DMT_FA_ASSET_HDR_STG_TBL, 9/9 rows -> DMT_FA_ASSET_BOOK_STG_TBL, 9/9 rows -> DMT_FA_ASSET_ASSIGN_STG_TBL) | run 417, prefix 93440 | GOOD 12/12 LOADED | BAD 15/15 FAILED with error | unaccounted 0 | PASS |
| Assets | fbdi | upload OK (9/9 rows -> DMT_FA_ASSET_HDR_STG_TBL, 9/9 rows -> DMT_FA_ASSET_BOOK_STG_TBL, 9/9 rows -> DMT_FA_ASSET_ASSIGN_STG_TBL) | run 418, prefix 93443 | GOOD 12/12 LOADED | BAD 15/15 FAILED with error | unaccounted 0 | PASS |
| Projects | header | upload OK (6/6 rows -> DMT_PJF_PROJECTS_STG_TBL, 7/7 rows -> DMT_PJF_TASKS_STG_TBL, 6/6 rows -> DMT_PJF_TEAM_MEMBERS_STG_TBL, 6/6 rows -> DMT_PJC_TXN_CONTROLS_STG_TBL) | run 417, prefix 93440 | GOOD 8/8 LOADED | BAD 17/17 FAILED with error | unaccounted 0 | PASS |
| Projects | fbdi | upload OK (6/6 rows -> DMT_PJF_PROJECTS_STG_TBL, 7/7 rows -> DMT_PJF_TASKS_STG_TBL, 6/6 rows -> DMT_PJF_TEAM_MEMBERS_STG_TBL, 6/6 rows -> DMT_PJC_TXN_CONTROLS_STG_TBL) | run 418, prefix 93443 | GOOD 8/8 LOADED | BAD 17/17 FAILED with error | unaccounted 0 | PASS |
| BillingEvents | header | upload OK (3/3 rows -> DMT_PJB_BILL_EVENTS_STG_TBL) | run 417, prefix 93440 | GOOD 2/2 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS |
| BillingEvents | fbdi | upload OK (3/3 rows -> DMT_PJB_BILL_EVENTS_STG_TBL) | run 418, prefix 93443 | GOOD 2/2 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS |
| Expenditures | header | upload OK (8/8 rows -> DMT_PJC_EXPENDITURES_STG_TBL) | run 417, prefix 93440 | GOOD 2/2 LOADED | BAD 6/6 FAILED with error | unaccounted 0 | PASS |
| Expenditures | fbdi | upload OK (8/8 rows -> DMT_PJC_EXPENDITURES_STG_TBL) | run 418, prefix 93443 | GOOD 2/2 LOADED | BAD 6/6 FAILED with error | unaccounted 0 | PASS |
| Grants | header | upload OK (8/8 rows -> DMT_GMS_AWD_HEADERS_STG_TBL, 5/5 rows -> DMT_GMS_AWD_PROJECTS_STG_TBL, 7/7 rows -> DMT_GMS_AWD_PERSONNEL_STG_TBL, 5/5 rows -> DMT_GMS_AWD_FUNDING_STG_TBL, 5/5 rows -> DMT_GMS_AWD_FUND_SRC_STG_TBL, 5/5 rows -> DMT_GMS_AWD_FUND_ALLOC_STG_TBL, 5/5 rows -> DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL, 1/1 rows -> DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL, 5/5 rows -> DMT_GMS_AWD_BDGT_PRDS_STG_TBL, 1/1 rows -> DMT_GMS_AWD_CFDAS_STG_TBL, 1/1 rows -> DMT_GMS_AWD_CERTS_STG_TBL, 1/1 rows -> DMT_GMS_AWD_KEYWORDS_STG_TBL, 5/5 rows -> DMT_GMS_AWD_ORG_CREDITS_STG_TBL, 1/1 rows -> DMT_GMS_AWD_REFERENCES_STG_TBL, 1/1 rows -> DMT_GMS_AWD_TERMS_STG_TBL) | run 417, prefix 93440 | GOOD 3/33 LOADED | BAD 23/23 FAILED with error | unaccounted 0 | FAIL: GOOD 3/33 LOADED with a Fusion id (30 LOADED without their own Fusion id) |
| Grants | fbdi | upload OK (8/8 rows -> DMT_GMS_AWD_HEADERS_STG_TBL, 5/5 rows -> DMT_GMS_AWD_PROJECTS_STG_TBL, 7/7 rows -> DMT_GMS_AWD_PERSONNEL_STG_TBL, 5/5 rows -> DMT_GMS_AWD_FUNDING_STG_TBL, 5/5 rows -> DMT_GMS_AWD_FUND_SRC_STG_TBL, 5/5 rows -> DMT_GMS_AWD_FUND_ALLOC_STG_TBL, 5/5 rows -> DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL, 1/1 rows -> DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL, 5/5 rows -> DMT_GMS_AWD_BDGT_PRDS_STG_TBL, 1/1 rows -> DMT_GMS_AWD_CFDAS_STG_TBL, 1/1 rows -> DMT_GMS_AWD_CERTS_STG_TBL, 1/1 rows -> DMT_GMS_AWD_KEYWORDS_STG_TBL, 5/5 rows -> DMT_GMS_AWD_ORG_CREDITS_STG_TBL, 1/1 rows -> DMT_GMS_AWD_REFERENCES_STG_TBL, 1/1 rows -> DMT_GMS_AWD_TERMS_STG_TBL) | run 418, prefix 93443 | GOOD 3/33 LOADED | BAD 23/23 FAILED with error | unaccounted 0 | FAIL: GOOD 3/33 LOADED with a Fusion id (30 LOADED without their own Fusion id) |
| ProjectBudgets | header | upload OK (6/6 rows -> DMT_PRJ_BUDGET_STG_TBL) | run 417, prefix 93440 | GOOD 1/1 LOADED | BAD 5/5 FAILED with error | unaccounted 0 | PASS |
| ProjectBudgets | fbdi | upload OK (6/6 rows -> DMT_PRJ_BUDGET_STG_TBL) | run 418, prefix 93443 | GOOD 1/1 LOADED | BAD 5/5 FAILED with error | unaccounted 0 | PASS |
| Workers | header | upload OK (4/4 rows -> DMT_WORKER_STG_TBL, 3/3 rows -> DMT_PERSON_NAME_STG_TBL, 1/1 rows -> DMT_PERSON_EMAIL_STG_TBL, 3/3 rows -> DMT_WORK_REL_STG_TBL, 5/5 rows -> DMT_ASSIGNMENT_STG_TBL) | run 417, prefix 93440 | GOOD 5/5 LOADED | BAD 11/11 FAILED with error | unaccounted 0 | PASS |
| Workers | fbdi | - | - | - | - | - | NOT APPLICABLE: not applicable: HCM object loaded by HCM Data Loader, no FBDI file |
| Salaries | header | upload OK (2/2 rows -> DMT_SALARY_STG_TBL) | run 417, prefix 93440 | GOOD 1/1 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS |
| Salaries | fbdi | - | - | - | - | - | NOT APPLICABLE: not applicable: HCM object loaded by HCM Data Loader, no FBDI file |
| SalaryBases | header | upload OK (3/3 rows -> DMT_SAL_BASIS_STG_TBL) | run 417, prefix 93440 | GOOD 2/2 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS |
| SalaryBases | fbdi | - | - | - | - | - | NOT APPLICABLE: not applicable: HCM object loaded by HCM Data Loader, no FBDI file |
| Absences | header | upload OK (3/3 rows -> DMT_ABSENCE_STG_TBL) | run 417, prefix 93440 | GOOD 2/2 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS |
| Absences | fbdi | - | - | - | - | - | NOT APPLICABLE: not applicable: HCM object loaded by HCM Data Loader, no FBDI file |
| TalentProfiles | header | upload OK (2/2 rows -> DMT_TALENT_PROF_STG_TBL, 2/2 rows -> DMT_TALENT_PROF_ITEM_STG_TBL) | run 417, prefix 93440 | GOOD 2/2 LOADED | BAD 2/2 FAILED with error | unaccounted 0 | PASS |
| TalentProfiles | fbdi | - | - | - | - | - | NOT APPLICABLE: not applicable: HCM object loaded by HCM Data Loader, no FBDI file |

## Ready for functional testing

Passes in the header run, and passes in the FBDI run or the FBDI format does not apply.

| Object | Ready |
|---|---|
| Items | yes |
| Suppliers | yes |
| SupplierAddresses | yes |
| SupplierSites | yes |
| SupplierSiteAssignments | yes |
| SupplierContacts | yes |
| Requisitions | yes |
| PurchaseOrders | yes |
| BlanketPOs | yes |
| Contracts | yes |
| APInvoices | no: FBDI failed |
| MiscReceipts | no: header, FBDI failed |
| Customers | yes |
| ARInvoices | yes |
| GLBalances | yes |
| GLBudgets | yes |
| Assets | yes |
| Projects | yes |
| BillingEvents | yes |
| Expenditures | yes |
| Grants | no: header, FBDI failed |
| ProjectBudgets | yes |
| Workers | yes |
| Salaries | yes |
| SalaryBases | yes |
| Absences | yes |
| TalentProfiles | yes |
