# Upload tests (backlog #786) after #787, #790, #788, #792, #793: results 2026-10-19/20

This replaces the per-object results of 2026-10-19 (`upload_verify_atp_20261019.*`, kept for history).

## What was promoted

Main aea47c8 (PRs #766 #767 #768 #769) was promoted to ATP through `scripts/ci_promote.py`:
- **Local gate.** Local regression run 416 (prefix 93439) passed with no new failures (7 known review items, unchanged), and the local click-through passed 68 of 68 steps.
- **ATP.** `deploy-prod` finished with 0 invalid objects, runtime config OK. ATP regression run 186 (prefix 93441) passed with no new failures (the same 7 known items), and the ATP click-through passed 68 of 68 steps.

**#787 root cause, proven on local before the fix.**
1. The dictionary had 0 of 5,109 FBDI positions.
2. Running the FBDI seed set 3,049 positions.
3. Running the object registry seed next set them back to 0, because its SEED_DICTIONARY deletes and rebuilds the dictionary.

**#787 fix (PR #766).** The deploy runs seeds in db/install.sql order. Two deploys in a row kept all positions with 0 invalid objects, and the 7 FBDI uploads that failed on ATP on 2026-10-19 now stage exactly.

## How the test works now (owner design, 2026-10-19)

Per format there is one zip of every in-scope object, one scenario (UPL-HDR-&lt;stamp&gt; / UPL-FBDI-&lt;stamp&gt;) and one run.
- **Upload.** The zip goes through page 25 (Smart Upload) in a real browser.
- **Staging check.** Each file's rows must stage exactly.
- **Comparison with the baseline before the run (owner requirement).** For every staging table: the row count, and every staged row matched one to one to its baseline row on every column the format carries (typed values). The comparison also checks the parent links: the #793 child links, and every registered parent-child pair. It reuses test/upload_samples/roundtrip_test.py. Columns the format cannot carry, and admin columns, are listed as excluded in the JSON. The run is submitted only when the comparison is clean.
- **Run.** The prefix is synced first (highest used on local and ATP, plus one). Then one SUBMIT_PIPELINE run, tagged UPLOAD_VERIFY.
- **Judging.** Each object is judged from DMT_RECORD_DETAIL_V. A GOOD row passes only when LOADED with its own Fusion id; a BAD row passes only when FAILED with real error text; nothing may be unaccounted.

Page 25 sends a whole zip down one path (header or FBDI) by its first recognised file name, hence two zips. The mixed-format loader (UPLOAD_ZIP_AUTO) is not wired to the page, and the page was not changed for that.

**The comparison gap and #795.** The FBDI runs (local 418, ATP 188) were submitted when the comparison did not yet check registered parent-child links. The extended comparison (PR #771) then found one difference in the FBDI uploads, on both instances: AP invoice lines lose their header (INVOICE_ID). That is new backlog #795. Every other table and link of the FBDI uploads equals the baseline, so the other FBDI objects' results stand. Under the owner's rule the FBDI scenario is not rerun until #795 is fixed. Re-comparison: `upload_baseline_recompare_atp_20261020.json`.

## Results per object and format (ATP; local identical in every verdict)

| Object | Format | Upload (staged exactly, ATP) | ATP run | GOOD | BAD | Unaccounted | ATP verdict | Local (run, verdict) |
|---|---|---|---|---|---|---|---|---|
| Items | header | upload OK (4/4 -> DMT_EGP_ITEM_STG_TBL, 5/5 -> DMT_EGP_ITEM_CAT_STG_TBL) | run 187, prefix 93442 | GOOD 6/6 LOADED | BAD 3/3 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| Items | fbdi | upload OK (4/4 -> DMT_EGP_ITEM_STG_TBL, 5/5 -> DMT_EGP_ITEM_CAT_STG_TBL) | run 188, prefix 93444 | GOOD 6/6 LOADED | BAD 3/3 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| Suppliers | header | upload OK (3/3 -> DMT_POZ_SUPPLIERS_STG_TBL) | run 187, prefix 93442 | GOOD 2/2 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| Suppliers | fbdi | upload OK (3/3 -> DMT_POZ_SUPPLIERS_STG_TBL) | run 188, prefix 93444 | GOOD 2/2 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| SupplierAddresses | header | upload OK (4/4 -> DMT_POZ_SUP_ADDR_STG_TBL) | run 187, prefix 93442 | GOOD 2/2 LOADED | BAD 2/2 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| SupplierAddresses | fbdi | upload OK (4/4 -> DMT_POZ_SUP_ADDR_STG_TBL) | run 188, prefix 93444 | GOOD 2/2 LOADED | BAD 2/2 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| SupplierSites | header | upload OK (4/4 -> DMT_POZ_SUP_SITE_STG_TBL) | run 187, prefix 93442 | GOOD 2/2 LOADED | BAD 2/2 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| SupplierSites | fbdi | upload OK (4/4 -> DMT_POZ_SUP_SITE_STG_TBL) | run 188, prefix 93444 | GOOD 2/2 LOADED | BAD 2/2 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| SupplierSiteAssignments | header | upload OK (3/3 -> DMT_POZ_SUP_SITE_ASSN_STG_TBL) | run 187, prefix 93442 | GOOD 2/2 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| SupplierSiteAssignments | fbdi | upload OK (3/3 -> DMT_POZ_SUP_SITE_ASSN_STG_TBL) | run 188, prefix 93444 | GOOD 2/2 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| SupplierContacts | header | upload OK (4/4 -> DMT_POZ_SUP_CONTACTS_STG_TBL) | run 187, prefix 93442 | GOOD 2/2 LOADED | BAD 2/2 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| SupplierContacts | fbdi | upload OK (4/4 -> DMT_POZ_SUP_CONTACTS_STG_TBL) | run 188, prefix 93444 | GOOD 2/2 LOADED | BAD 2/2 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| Requisitions | header | upload OK (6/6 -> DMT_POR_REQ_HEADERS_STG_TBL, 7/7 -> DMT_POR_REQ_LINES_STG_TBL, 7/7 -> DMT_POR_REQ_DISTS_STG_TBL) | run 187, prefix 93442 | GOOD 6/6 LOADED | BAD 14/14 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| Requisitions | fbdi | upload OK (6/6 -> DMT_POR_REQ_HEADERS_STG_TBL, 7/7 -> DMT_POR_REQ_LINES_STG_TBL, 7/7 -> DMT_POR_REQ_DISTS_STG_TBL) | run 188, prefix 93444 | GOOD 6/6 LOADED | BAD 14/14 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| PurchaseOrders | header | upload OK (9/9 -> DMT_PO_HEADERS_INT_STG_TBL, 9/9 -> DMT_PO_LINES_INT_STG_TBL, 5/5 -> DMT_PO_LINE_LOCS_INT_STG_TBL, 5/5 -> DMT_PO_DISTS_INT_STG_TBL) | run 187, prefix 93442 | GOOD 8/8 LOADED | BAD 11/11 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| PurchaseOrders | fbdi | upload OK (9/9 -> DMT_PO_HEADERS_INT_STG_TBL, 9/9 -> DMT_PO_LINES_INT_STG_TBL, 5/5 -> DMT_PO_LINE_LOCS_INT_STG_TBL, 5/5 -> DMT_PO_DISTS_INT_STG_TBL) | run 188, prefix 93444 | GOOD 8/8 LOADED | BAD 11/11 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| BlanketPOs | header | upload OK (9/9 -> DMT_PO_HEADERS_INT_STG_TBL, 9/9 -> DMT_PO_LINES_INT_STG_TBL) | run 187, prefix 93442 | GOOD 4/4 LOADED | BAD 3/3 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| BlanketPOs | fbdi | upload OK (9/9 -> DMT_PO_HEADERS_INT_STG_TBL, 9/9 -> DMT_PO_LINES_INT_STG_TBL) | run 188, prefix 93444 | GOOD 4/4 LOADED | BAD 3/3 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| Contracts | header | upload OK (9/9 -> DMT_PO_HEADERS_INT_STG_TBL) | run 187, prefix 93442 | GOOD 1/1 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| Contracts | fbdi | upload OK (9/9 -> DMT_PO_HEADERS_INT_STG_TBL) | run 188, prefix 93444 | GOOD 1/1 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| APInvoices | header | upload OK (5/5 -> DMT_AP_INVOICES_INT_STG_TBL, 6/6 -> DMT_AP_INVOICE_LINES_INT_STG_TBL) | run 187, prefix 93442 | GOOD 6/6 LOADED | BAD 5/5 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| APInvoices | fbdi | upload OK (5/5 -> DMT_AP_INVOICES_INT_STG_TBL, 6/6 -> DMT_AP_INVOICE_LINES_INT_STG_TBL) | run 188, prefix 93444 | GOOD 0/6 LOADED | BAD 1/5 FAILED with error | unaccounted 6 | FAIL: GOOD 0/6 LOADED with a Fusion id (3 FAILED); BAD 1/5 FAILED with an error; 6 unaccounted | run 418, FAIL |
| MiscReceipts | header | - | - | - | - | - | FAIL: backlog #794: a header upload cannot link MiscReceipts lots and serials to their transaction (SOURCE_ID is copied from the source scenario); not uploaded or run in the header format until fixed | FAIL |
| MiscReceipts | fbdi | upload OK (8/8 -> DMT_INV_TRX_STG_TBL, 3/3 -> DMT_INV_TRX_LOTS_STG_TBL, 3/3 -> DMT_INV_TRX_SERIALS_STG_TBL) | run 188, prefix 93444 | GOOD 3/5 LOADED | BAD 9/9 FAILED with error | unaccounted 0 | FAIL: GOOD 3/5 LOADED with a Fusion id (2 LOADED without their own Fusion id) | run 418, FAIL |
| Customers | header | upload OK (7/7 -> DMT_HZ_PARTIES_STG_TBL, 7/7 -> DMT_HZ_LOCATIONS_STG_TBL, 7/7 -> DMT_HZ_PARTY_SITES_STG_TBL, 8/8 -> DMT_HZ_PARTY_SITE_USES_STG_TBL, 7/7 -> DMT_HZ_ACCOUNTS_STG_TBL, 7/7 -> DMT_HZ_ACCT_SITES_STG_TBL, 7/7 -> DMT_HZ_ACCT_SITE_USES_STG_TBL) | run 187, prefix 93442 | GOOD 19/19 LOADED | BAD 31/31 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| Customers | fbdi | upload OK (7/7 -> DMT_HZ_PARTIES_STG_TBL, 7/7 -> DMT_HZ_LOCATIONS_STG_TBL, 7/7 -> DMT_HZ_PARTY_SITES_STG_TBL, 8/8 -> DMT_HZ_PARTY_SITE_USES_STG_TBL, 7/7 -> DMT_HZ_ACCOUNTS_STG_TBL, 7/7 -> DMT_HZ_ACCT_SITES_STG_TBL, 7/7 -> DMT_HZ_ACCT_SITE_USES_STG_TBL) | run 188, prefix 93444 | GOOD 19/19 LOADED | BAD 31/31 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| ARInvoices | header | upload OK (11/11 -> DMT_RA_LINES_STG_TBL, 12/12 -> DMT_RA_DISTS_STG_TBL) | run 187, prefix 93442 | GOOD 13/13 LOADED | BAD 10/10 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| ARInvoices | fbdi | upload OK (11/11 -> DMT_RA_LINES_STG_TBL, 12/12 -> DMT_RA_DISTS_STG_TBL) | run 188, prefix 93444 | GOOD 13/13 LOADED | BAD 10/10 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| GLBalances | header | upload OK (8/8 -> DMT_GL_INTERFACE_STG_TBL) | run 187, prefix 93442 | GOOD 2/2 LOADED | BAD 6/6 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| GLBalances | fbdi | upload OK (8/8 -> DMT_GL_INTERFACE_STG_TBL) | run 188, prefix 93444 | GOOD 2/2 LOADED | BAD 6/6 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| GLBudgets | header | upload OK (5/5 -> DMT_GL_BUDGET_INT_STG_TBL) | run 187, prefix 93442 | GOOD 2/2 LOADED | BAD 3/3 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| GLBudgets | fbdi | upload OK (5/5 -> DMT_GL_BUDGET_INT_STG_TBL) | run 188, prefix 93444 | GOOD 2/2 LOADED | BAD 3/3 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| Assets | header | upload OK (9/9 -> DMT_FA_ASSET_HDR_STG_TBL, 9/9 -> DMT_FA_ASSET_BOOK_STG_TBL, 9/9 -> DMT_FA_ASSET_ASSIGN_STG_TBL) | run 187, prefix 93442 | GOOD 12/12 LOADED | BAD 15/15 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| Assets | fbdi | upload OK (9/9 -> DMT_FA_ASSET_HDR_STG_TBL, 9/9 -> DMT_FA_ASSET_BOOK_STG_TBL, 9/9 -> DMT_FA_ASSET_ASSIGN_STG_TBL) | run 188, prefix 93444 | GOOD 12/12 LOADED | BAD 15/15 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| Projects | header | upload OK (6/6 -> DMT_PJF_PROJECTS_STG_TBL, 7/7 -> DMT_PJF_TASKS_STG_TBL, 6/6 -> DMT_PJF_TEAM_MEMBERS_STG_TBL, 6/6 -> DMT_PJC_TXN_CONTROLS_STG_TBL) | run 187, prefix 93442 | GOOD 8/8 LOADED | BAD 17/17 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| Projects | fbdi | upload OK (6/6 -> DMT_PJF_PROJECTS_STG_TBL, 7/7 -> DMT_PJF_TASKS_STG_TBL, 6/6 -> DMT_PJF_TEAM_MEMBERS_STG_TBL, 6/6 -> DMT_PJC_TXN_CONTROLS_STG_TBL) | run 188, prefix 93444 | GOOD 8/8 LOADED | BAD 17/17 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| BillingEvents | header | upload OK (3/3 -> DMT_PJB_BILL_EVENTS_STG_TBL) | run 187, prefix 93442 | GOOD 2/2 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| BillingEvents | fbdi | upload OK (3/3 -> DMT_PJB_BILL_EVENTS_STG_TBL) | run 188, prefix 93444 | GOOD 2/2 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| Expenditures | header | upload OK (8/8 -> DMT_PJC_EXPENDITURES_STG_TBL) | run 187, prefix 93442 | GOOD 2/2 LOADED | BAD 6/6 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| Expenditures | fbdi | upload OK (8/8 -> DMT_PJC_EXPENDITURES_STG_TBL) | run 188, prefix 93444 | GOOD 2/2 LOADED | BAD 6/6 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| Grants | header | upload OK (8/8 -> DMT_GMS_AWD_HEADERS_STG_TBL, 5/5 -> DMT_GMS_AWD_PROJECTS_STG_TBL, 7/7 -> DMT_GMS_AWD_PERSONNEL_STG_TBL, 5/5 -> DMT_GMS_AWD_FUNDING_STG_TBL, 5/5 -> DMT_GMS_AWD_FUND_SRC_STG_TBL, 5/5 -> DMT_GMS_AWD_FUND_ALLOC_STG_TBL, 5/5 -> DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL, 1/1 -> DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL, 5/5 -> DMT_GMS_AWD_BDGT_PRDS_STG_TBL, 1/1 -> DMT_GMS_AWD_CFDAS_STG_TBL, 1/1 -> DMT_GMS_AWD_CERTS_STG_TBL, 1/1 -> DMT_GMS_AWD_KEYWORDS_STG_TBL, 5/5 -> DMT_GMS_AWD_ORG_CREDITS_STG_TBL, 1/1 -> DMT_GMS_AWD_REFERENCES_STG_TBL, 1/1 -> DMT_GMS_AWD_TERMS_STG_TBL) | run 187, prefix 93442 | GOOD 3/33 LOADED | BAD 23/23 FAILED with error | unaccounted 0 | FAIL: GOOD 3/33 LOADED with a Fusion id (30 LOADED without their own Fusion id) | run 417, FAIL |
| Grants | fbdi | upload OK (8/8 -> DMT_GMS_AWD_HEADERS_STG_TBL, 5/5 -> DMT_GMS_AWD_PROJECTS_STG_TBL, 7/7 -> DMT_GMS_AWD_PERSONNEL_STG_TBL, 5/5 -> DMT_GMS_AWD_FUNDING_STG_TBL, 5/5 -> DMT_GMS_AWD_FUND_SRC_STG_TBL, 5/5 -> DMT_GMS_AWD_FUND_ALLOC_STG_TBL, 5/5 -> DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL, 1/1 -> DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL, 5/5 -> DMT_GMS_AWD_BDGT_PRDS_STG_TBL, 1/1 -> DMT_GMS_AWD_CFDAS_STG_TBL, 1/1 -> DMT_GMS_AWD_CERTS_STG_TBL, 1/1 -> DMT_GMS_AWD_KEYWORDS_STG_TBL, 5/5 -> DMT_GMS_AWD_ORG_CREDITS_STG_TBL, 1/1 -> DMT_GMS_AWD_REFERENCES_STG_TBL, 1/1 -> DMT_GMS_AWD_TERMS_STG_TBL) | run 188, prefix 93444 | GOOD 3/33 LOADED | BAD 23/23 FAILED with error | unaccounted 0 | FAIL: GOOD 3/33 LOADED with a Fusion id (30 LOADED without their own Fusion id) | run 418, FAIL |
| ProjectBudgets | header | upload OK (6/6 -> DMT_PRJ_BUDGET_STG_TBL) | run 187, prefix 93442 | GOOD 1/1 LOADED | BAD 5/5 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| ProjectBudgets | fbdi | upload OK (6/6 -> DMT_PRJ_BUDGET_STG_TBL) | run 188, prefix 93444 | GOOD 1/1 LOADED | BAD 5/5 FAILED with error | unaccounted 0 | PASS | run 418, PASS |
| Workers | header | upload OK (4/4 -> DMT_WORKER_STG_TBL, 3/3 -> DMT_PERSON_NAME_STG_TBL, 1/1 -> DMT_PERSON_EMAIL_STG_TBL, 3/3 -> DMT_WORK_REL_STG_TBL, 5/5 -> DMT_ASSIGNMENT_STG_TBL) | run 187, prefix 93442 | GOOD 5/5 LOADED | BAD 11/11 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| Workers | fbdi | - | - | - | - | - | NOT APPLICABLE: not applicable: HCM object loaded by HCM Data Loader, no FBDI file | NOT APPLICABLE |
| Salaries | header | upload OK (2/2 -> DMT_SALARY_STG_TBL) | run 187, prefix 93442 | GOOD 1/1 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| Salaries | fbdi | - | - | - | - | - | NOT APPLICABLE: not applicable: HCM object loaded by HCM Data Loader, no FBDI file | NOT APPLICABLE |
| SalaryBases | header | upload OK (3/3 -> DMT_SAL_BASIS_STG_TBL) | run 187, prefix 93442 | GOOD 2/2 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| SalaryBases | fbdi | - | - | - | - | - | NOT APPLICABLE: not applicable: HCM object loaded by HCM Data Loader, no FBDI file | NOT APPLICABLE |
| Absences | header | upload OK (3/3 -> DMT_ABSENCE_STG_TBL) | run 187, prefix 93442 | GOOD 2/2 LOADED | BAD 1/1 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| Absences | fbdi | - | - | - | - | - | NOT APPLICABLE: not applicable: HCM object loaded by HCM Data Loader, no FBDI file | NOT APPLICABLE |
| TalentProfiles | header | upload OK (2/2 -> DMT_TALENT_PROF_STG_TBL, 2/2 -> DMT_TALENT_PROF_ITEM_STG_TBL) | run 187, prefix 93442 | GOOD 2/2 LOADED | BAD 2/2 FAILED with error | unaccounted 0 | PASS | run 417, PASS |
| TalentProfiles | fbdi | - | - | - | - | - | NOT APPLICABLE: not applicable: HCM object loaded by HCM Data Loader, no FBDI file | NOT APPLICABLE |

Files: `upload_verify_atp_20261020.*`, `upload_verify_local_20261020.*`.
- **ATP runs:** header 187 (prefix 93442), FBDI 188 (prefix 93444).
- **Local runs:** header 417 (prefix 93440), FBDI 418 (prefix 93443).
- **Uploads:** header 62 of 62 files staged exactly; FBDI 55 of 55 staging tables (57 files, 22 objects) staged exactly.

## Ready for functional testing

The rule: the object passes the header run, and passes the FBDI run or FBDI does not apply.

**Ready (24):** Items, Suppliers, SupplierAddresses, SupplierSites, SupplierSiteAssignments, SupplierContacts, Requisitions, PurchaseOrders, BlanketPOs, Contracts, Customers, ARInvoices, GLBalances, GLBudgets, Assets, Projects, BillingEvents, Expenditures, ProjectBudgets, Workers, Salaries, SalaryBases, Absences, TalentProfiles.

**Not ready (3):**
- **APInvoices:** header PASS; FBDI FAIL from #795.
- **MiscReceipts:** header not run (#794, lots and serials cannot link in the header format); FBDI FAIL on the own-Fusion-id rule (2 lot/serial rows LOADED without their own id, #789).
- **Grants:** header and FBDI FAIL on the own-Fusion-id rule (30 child rows LOADED without their own id, #789).

## Negative upload tests (#790, #788)

Files: `upload_negative_{local,atp}_20261020.*`. The zips hold Suppliers, APInvoices and Projects plus their upstream objects. Each of the Suppliers, AP invoice and Projects files has one row with text in a number column, one with an over-length value, and one with an unparseable date.

| Test | Expected | Local | ATP |
|---|---|---|---|
| 1 mixed rows, header | good rows stage, each bad row in Upload Errors with a readable error, log COMPLETED_WITH_ERRORS; then the good rows LOAD | PASS (3 of 3 bad rows rejected per file; run 419 prefix 93445: all 6 objects PASS) | PASS (run 189 prefix 93446: all 6 objects PASS) |
| 1 mixed rows, FBDI | same | upload PASS (3 of 3 bad rows rejected per file); run not submitted, the comparison differs from the baseline on the AP link (#795) | same as local |
| 2 wrong layout, header (Projects columns in the Suppliers file) | nothing staged, visible rejection | PASS (0 staged, "Wrong layout: only 1 of the 10 columns ...", 1 Upload Errors row, page error) | PASS |
| 2 wrong layout, FBDI (Suppliers file, values moved 3 slots) | nothing staged, visible rejection | PASS (0 staged, "the first row has 158 fields, the template has 155") | PASS |
| 3 page message (all four uploads) | never plain success | PASS 4 of 4 (error notification with the summary) | PASS 4 of 4 |

A bad date is rejected with "Line N, column C: \"value\" is not a valid date (expected ...). The row was not loaded." Number and length errors carry the Oracle error.

**Known limits:**
- Rows rejected by DML error logging carry their order among the errors, not their file line.
- The three FBDI child files with a parent link (#793) are rewritten before loading, so the field-count check cannot catch a wrong layout there.

## Defects logged

| Backlog | What |
|---|---|
| #794 (P2) | A header upload cannot link MiscReceipts lots and serials to their transaction (SOURCE_ID copied from the source scenario). MiscReceipts is left out of the header test until it is fixed. |
| #795 (P1) | An FBDI upload loses the AP invoice line-to-header link (INVOICE_ID slot 1 unmapped in both AP files); every FBDI-uploaded AP invoice fails with NO INVOICE LINES. |
| #789 (open, owner rule) | The Grants child rows and the MiscReceipts lot and serial rows are LOADED without their own Fusion id. |

## Commands

```
python test/playwright/dmt_upload_verify.py --target atp --formats header,fbdi --json-out <json> --md-out <md>
python test/playwright/dmt_upload_verify.py --target atp --negative --json-out <json> --md-out <md>
```
Add `--resume` to continue an interrupted file. `--upload-only` stops after the comparison with the baseline.
