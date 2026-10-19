# Upload verification (atp) - 2026-10-19T17:21

Backlog #786. Smart Upload (page 25) in a real browser, then a pipeline run per object scenario on atp (console https://g6726c838b72234-queryapp.adb.us-ashburn-1.oraclecloudapps.com/ords). Baseline data: RegressionTest261013111321 (regression run 184 gives each row's expected outcome). Code: ef30e66.

| Object | Format | Upload | Run | GOOD | BAD | Unaccounted | Verdict |
|---|---|---|---|---|---|---|---|
| Items | header | upload OK (4/4 rows -> DMT_EGP_ITEM_STG_TBL, 5/5 rows -> DMT_EGP_ITEM_CAT_STG_TBL) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| Items | fbdi | upload FAILED (0/4 rows -> DMT_EGP_ITEM_STG_TBL, 0/5 rows -> DMT_EGP_ITEM_CAT_STG_TBL) | - | - | - | - | FAIL: upload: DMT_EGP_ITEM_STG_TBL: staged 0 of 4 rows; 0 staged row(s) do not match the file; DMT_EGP_ITEM_CAT_STG_TBL: staged 0 of 5 rows; 0 staged row(s) do not match the file; loader said EGP_ITEM: FBDI loader failed: ORA-12899: value too large for column "DMT2_OWNER"."DMT_EGP_ITEM_STG_TBL"."STYLE_ITEM_FLAG" (actual: 4, maximum: 1); loader said EGP_ITEM_CAT: FBDI loader failed: ORA-12899: value too large for column "DMT2_OWNER"."DMT_EGP_ITEM_CAT_STG_TBL"."ORGANIZATION_CODE" (actual: 20, maximum: 18) (run not submitted) |
| Suppliers | header | upload OK (3/3 rows -> DMT_POZ_SUPPLIERS_STG_TBL) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| Suppliers | fbdi | upload OK (3/3 rows -> DMT_POZ_SUPPLIERS_STG_TBL) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| SupplierAddresses | header | upload OK (4/4 rows -> DMT_POZ_SUP_ADDR_STG_TBL; plus 1 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| SupplierAddresses | fbdi | upload OK (4/4 rows -> DMT_POZ_SUP_ADDR_STG_TBL; plus 1 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| SupplierSites | header | upload OK (4/4 rows -> DMT_POZ_SUP_SITE_STG_TBL; plus 2 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| SupplierSites | fbdi | upload OK (4/4 rows -> DMT_POZ_SUP_SITE_STG_TBL; plus 2 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| SupplierSiteAssignments | header | upload OK (3/3 rows -> DMT_POZ_SUP_SITE_ASSN_STG_TBL; plus 3 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| SupplierSiteAssignments | fbdi | upload OK (3/3 rows -> DMT_POZ_SUP_SITE_ASSN_STG_TBL; plus 3 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| SupplierContacts | header | upload OK (4/4 rows -> DMT_POZ_SUP_CONTACTS_STG_TBL; plus 4 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| SupplierContacts | fbdi | upload OK (4/4 rows -> DMT_POZ_SUP_CONTACTS_STG_TBL; plus 4 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| Requisitions | header | upload OK (6/6 rows -> DMT_POR_REQ_HEADERS_STG_TBL, 7/7 rows -> DMT_POR_REQ_LINES_STG_TBL, 7/7 rows -> DMT_POR_REQ_DISTS_STG_TBL; plus 6 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| Requisitions | fbdi | upload FAILED (6/6 rows -> DMT_POR_REQ_HEADERS_STG_TBL, 7/7 rows -> DMT_POR_REQ_LINES_STG_TBL, 7/7 rows -> DMT_POR_REQ_DISTS_STG_TBL; plus 6 upstream file(s), 2 of them failed) | - | - | - | - | FAIL: upload: the file of upstream object(s) Items did not stage (this object's own files staged correctly); loader said EGP_ITEM: FBDI loader failed: ORA-12899: value too large for column "DMT2_OWNER"."DMT_EGP_ITEM_STG_TBL"."STYLE_ITEM_FLAG" (actual: 4, maximum: 1); loader said EGP_ITEM_CAT: FBDI loader failed: ORA-12899: value too large for column "DMT2_OWNER"."DMT_EGP_ITEM_CAT_STG_TBL"."ORGANIZATION_CODE" (actual: 20, maximum: 18) (run not submitted) |
| PurchaseOrders | header | upload OK (4/4 rows -> DMT_PO_HEADERS_INT_STG_TBL, 5/5 rows -> DMT_PO_LINES_INT_STG_TBL, 5/5 rows -> DMT_PO_LINE_LOCS_INT_STG_TBL, 5/5 rows -> DMT_PO_DISTS_INT_STG_TBL; plus 10 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| PurchaseOrders | fbdi | upload FAILED (4/4 rows -> DMT_PO_HEADERS_INT_STG_TBL, 5/5 rows -> DMT_PO_LINES_INT_STG_TBL, 5/5 rows -> DMT_PO_LINE_LOCS_INT_STG_TBL, 5/5 rows -> DMT_PO_DISTS_INT_STG_TBL; plus 10 upstream file(s), 2 of them failed) | - | - | - | - | FAIL: upload: the file of upstream object(s) Items did not stage (this object's own files staged correctly); loader said EGP_ITEM: FBDI loader failed: ORA-12899: value too large for column "DMT2_OWNER"."DMT_EGP_ITEM_STG_TBL"."STYLE_ITEM_FLAG" (actual: 4, maximum: 1); loader said EGP_ITEM_CAT: FBDI loader failed: ORA-12899: value too large for column "DMT2_OWNER"."DMT_EGP_ITEM_CAT_STG_TBL"."ORGANIZATION_CODE" (actual: 20, maximum: 18) (run not submitted) |
| BlanketPOs | header | upload OK (3/3 rows -> DMT_PO_HEADERS_INT_STG_TBL, 4/4 rows -> DMT_PO_LINES_INT_STG_TBL; plus 6 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| BlanketPOs | fbdi | - | - | - | - | - | NOT APPLICABLE: no FBDI mapping |
| Contracts | header | upload OK (2/2 rows -> DMT_PO_HEADERS_INT_STG_TBL; plus 4 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| Contracts | fbdi | - | - | - | - | - | NOT APPLICABLE: no FBDI mapping |
| APInvoices | header | upload OK (5/5 rows -> DMT_AP_INVOICES_INT_STG_TBL, 6/6 rows -> DMT_AP_INVOICE_LINES_INT_STG_TBL; plus 4 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| APInvoices | fbdi | upload OK (5/5 rows -> DMT_AP_INVOICES_INT_STG_TBL, 6/6 rows -> DMT_AP_INVOICE_LINES_INT_STG_TBL; plus 4 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| MiscReceipts | header | upload OK (8/8 rows -> DMT_INV_TRX_STG_TBL, 3/3 rows -> DMT_INV_TRX_LOTS_STG_TBL, 3/3 rows -> DMT_INV_TRX_SERIALS_STG_TBL; plus 2 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| MiscReceipts | fbdi | - | - | - | - | - | NOT APPLICABLE: no FBDI mapping |
| Customers | header | upload OK (7/7 rows -> DMT_HZ_PARTIES_STG_TBL, 7/7 rows -> DMT_HZ_LOCATIONS_STG_TBL, 7/7 rows -> DMT_HZ_PARTY_SITES_STG_TBL, 8/8 rows -> DMT_HZ_PARTY_SITE_USES_STG_TBL, 7/7 rows -> DMT_HZ_ACCOUNTS_STG_TBL, 7/7 rows -> DMT_HZ_ACCT_SITES_STG_TBL, 7/7 rows -> DMT_HZ_ACCT_SITE_USES_STG_TBL) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| Customers | fbdi | upload OK (7/7 rows -> DMT_HZ_PARTIES_STG_TBL, 7/7 rows -> DMT_HZ_LOCATIONS_STG_TBL, 7/7 rows -> DMT_HZ_PARTY_SITES_STG_TBL, 8/8 rows -> DMT_HZ_PARTY_SITE_USES_STG_TBL, 7/7 rows -> DMT_HZ_ACCOUNTS_STG_TBL, 7/7 rows -> DMT_HZ_ACCT_SITES_STG_TBL, 7/7 rows -> DMT_HZ_ACCT_SITE_USES_STG_TBL) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| ARInvoices | header | upload OK (11/11 rows -> DMT_RA_LINES_STG_TBL, 12/12 rows -> DMT_RA_DISTS_STG_TBL; plus 7 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| ARInvoices | fbdi | - | - | - | - | - | NOT APPLICABLE: partial FBDI mapping: no FBDI file for ARInvoices:DMT_RA_DISTS_STG_TBL |
| GLBalances | header | upload OK (8/8 rows -> DMT_GL_INTERFACE_STG_TBL) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| GLBalances | fbdi | upload FAILED (0/8 rows -> DMT_GL_INTERFACE_STG_TBL) | - | - | - | - | FAIL: upload: DMT_GL_INTERFACE_STG_TBL: staged 0 of 8 rows; 0 staged row(s) do not match the file; loader said GL_INTERFACE: FBDI loader failed: ORA-01841: (full) year must be between -4713 and +9999, and not be 0 (run not submitted) |
| GLBudgets | header | upload OK (5/5 rows -> DMT_GL_BUDGET_INT_STG_TBL) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| GLBudgets | fbdi | upload FAILED (0/5 rows -> DMT_GL_BUDGET_INT_STG_TBL) | - | - | - | - | FAIL: upload: DMT_GL_BUDGET_INT_STG_TBL: staged 0 of 5 rows; 0 staged row(s) do not match the file; loader said GL_BUDGET_INT: FBDI loader failed: ORA-01722: unable to convert string value containing 'U' to a number:  (run not submitted) |
| Assets | header | upload OK (9/9 rows -> DMT_FA_ASSET_HDR_STG_TBL, 9/9 rows -> DMT_FA_ASSET_BOOK_STG_TBL, 9/9 rows -> DMT_FA_ASSET_ASSIGN_STG_TBL) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| Assets | fbdi | - | - | - | - | - | NOT APPLICABLE: no FBDI mapping |
| Projects | header | upload OK (6/6 rows -> DMT_PJF_PROJECTS_STG_TBL, 7/7 rows -> DMT_PJF_TASKS_STG_TBL, 6/6 rows -> DMT_PJF_TEAM_MEMBERS_STG_TBL, 6/6 rows -> DMT_PJC_TXN_CONTROLS_STG_TBL) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| Projects | fbdi | upload OK (6/6 rows -> DMT_PJF_PROJECTS_STG_TBL, 7/7 rows -> DMT_PJF_TASKS_STG_TBL, 6/6 rows -> DMT_PJF_TEAM_MEMBERS_STG_TBL, 6/6 rows -> DMT_PJC_TXN_CONTROLS_STG_TBL) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| BillingEvents | header | upload OK (3/3 rows -> DMT_PJB_BILL_EVENTS_STG_TBL; plus 4 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| BillingEvents | fbdi | upload OK (3/3 rows -> DMT_PJB_BILL_EVENTS_STG_TBL; plus 4 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| Expenditures | header | upload OK (8/8 rows -> DMT_PJC_EXPENDITURES_STG_TBL; plus 4 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| Expenditures | fbdi | upload FAILED (0/8 rows -> DMT_PJC_EXPENDITURES_STG_TBL; plus 4 upstream file(s), all OK) | - | - | - | - | FAIL: upload: DMT_PJC_EXPENDITURES_STG_TBL: staged 8 of 8 rows; 8 staged row(s) do not match the file (first difference: QUANTITY: file '8' staged ''; WORK_TYPE: file '' staged 'RT-EXP-PCS10080-2025-04-18'; ORIG_TRANSACTION_REFERENCE: file 'RT-EXP-PCS10080-2025-04-18' staged '') (run not submitted) |
| Grants | header | upload OK (8/8 rows -> DMT_GMS_AWD_HEADERS_STG_TBL, 5/5 rows -> DMT_GMS_AWD_FUNDING_STG_TBL, 5/5 rows -> DMT_GMS_AWD_PROJECTS_STG_TBL, 7/7 rows -> DMT_GMS_AWD_PERSONNEL_STG_TBL, 1/1 rows -> DMT_GMS_AWD_TERMS_STG_TBL, 5/5 rows -> DMT_GMS_AWD_FUND_SRC_STG_TBL, 5/5 rows -> DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL, 1/1 rows -> DMT_GMS_AWD_KEYWORDS_STG_TBL, 1/1 rows -> DMT_GMS_AWD_CERTS_STG_TBL, 1/1 rows -> DMT_GMS_AWD_CFDAS_STG_TBL, 5/5 rows -> DMT_GMS_AWD_FUND_ALLOC_STG_TBL, 5/5 rows -> DMT_GMS_AWD_ORG_CREDITS_STG_TBL, 5/5 rows -> DMT_GMS_AWD_BDGT_PRDS_STG_TBL, 1/1 rows -> DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL, 1/1 rows -> DMT_GMS_AWD_REFERENCES_STG_TBL; plus 4 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| Grants | fbdi | - | - | - | - | - | NOT APPLICABLE: partial FBDI mapping: no FBDI file for Grants:DMT_GMS_AWD_FUNDING_STG_TBL, Grants:DMT_GMS_AWD_PROJECTS_STG_TBL, Grants:DMT_GMS_AWD_TERMS_STG_TBL, Grants:DMT_GMS_AWD_FUND_SRC_STG_TBL, Grants:DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL, Grants:DMT_GMS_AWD_KEYWORDS_STG_TBL, Grants:DMT_GMS_AWD_CERTS_STG_TBL, Grants:DMT_GMS_AWD_CFDAS_STG_TBL, Grants:DMT_GMS_AWD_FUND_ALLOC_STG_TBL, Grants:DMT_GMS_AWD_ORG_CREDITS_STG_TBL, Grants:DMT_GMS_AWD_BDGT_PRDS_STG_TBL, Grants:DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL, Grants:DMT_GMS_AWD_REFERENCES_STG_TBL |
| ProjectBudgets | header | upload OK (6/6 rows -> DMT_PRJ_BUDGET_STG_TBL; plus 4 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| ProjectBudgets | fbdi | upload FAILED (0/6 rows -> DMT_PRJ_BUDGET_STG_TBL; plus 4 upstream file(s), all OK) | - | - | - | - | FAIL: upload: DMT_PRJ_BUDGET_STG_TBL: staged 6 of 6 rows; 6 staged row(s) do not match the file (first difference: PROCESSING_MODE: file 'Create' staged '') (run not submitted) |
| Workers | header | upload OK (4/4 rows -> DMT_WORKER_STG_TBL, 3/3 rows -> DMT_PERSON_NAME_STG_TBL, 1/1 rows -> DMT_PERSON_EMAIL_STG_TBL, 3/3 rows -> DMT_WORK_REL_STG_TBL, 5/5 rows -> DMT_ASSIGNMENT_STG_TBL) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| Workers | fbdi | - | - | - | - | - | NOT APPLICABLE: not applicable: HCM object loaded by HCM Data Loader, no FBDI file |
| Salaries | header | upload OK (2/2 rows -> DMT_SALARY_STG_TBL; plus 5 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| Salaries | fbdi | - | - | - | - | - | NOT APPLICABLE: not applicable: HCM object loaded by HCM Data Loader, no FBDI file |
| SalaryBases | header | upload OK (3/3 rows -> DMT_SAL_BASIS_STG_TBL; plus 6 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| SalaryBases | fbdi | - | - | - | - | - | NOT APPLICABLE: not applicable: HCM object loaded by HCM Data Loader, no FBDI file |
| Absences | header | upload OK (3/3 rows -> DMT_ABSENCE_STG_TBL; plus 5 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| Absences | fbdi | - | - | - | - | - | NOT APPLICABLE: not applicable: HCM object loaded by HCM Data Loader, no FBDI file |
| TalentProfiles | header | upload OK (2/2 rows -> DMT_TALENT_PROF_STG_TBL, 2/2 rows -> DMT_TALENT_PROF_ITEM_STG_TBL; plus 5 upstream file(s), all OK) | - | - | - | - | UPLOAD ONLY: upload passed; run not submitted yet (--upload-only) |
| TalentProfiles | fbdi | - | - | - | - | - | NOT APPLICABLE: not applicable: HCM object loaded by HCM Data Loader, no FBDI file |

## Ready for functional testing

Header PASS, FBDI PASS or not applicable, and the run PASS.

| Object | Ready |
|---|---|
| Items | no: FBDI failed |
| Suppliers | not yet: run not done |
| SupplierAddresses | not yet: run not done |
| SupplierSites | not yet: run not done |
| SupplierSiteAssignments | not yet: run not done |
| SupplierContacts | not yet: run not done |
| Requisitions | no: FBDI failed |
| PurchaseOrders | no: FBDI failed |
| BlanketPOs | not yet: run not done |
| Contracts | not yet: run not done |
| APInvoices | not yet: run not done |
| MiscReceipts | not yet: run not done |
| Customers | not yet: run not done |
| ARInvoices | not yet: run not done |
| GLBalances | no: FBDI failed |
| GLBudgets | no: FBDI failed |
| Assets | not yet: run not done |
| Projects | not yet: run not done |
| BillingEvents | not yet: run not done |
| Expenditures | no: FBDI failed |
| Grants | not yet: run not done |
| ProjectBudgets | no: FBDI failed |
| Workers | not yet: run not done |
| Salaries | not yet: run not done |
| SalaryBases | not yet: run not done |
| Absences | not yet: run not done |
| TalentProfiles | not yet: run not done |
