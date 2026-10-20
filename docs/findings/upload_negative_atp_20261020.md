# Upload verification (atp) - 2026-10-20T00:04

Backlog #786. Per format one zip of every object, uploaded once through Smart Upload (page 25) in a real browser into its own scenario, then one pipeline run of that scenario on atp (console https://g6726c838b72234-queryapp.adb.us-ashburn-1.oraclecloudapps.com/ords). Baseline data: RegressionTest261013111321 (regression run 186 gives each row's expected outcome). Code: 74e3d7c.

| Object | Format | Upload | Run | GOOD | BAD | Unaccounted | Verdict |
|---|---|---|---|---|---|---|---|

## Negative upload tests

Objects in the zips: Suppliers, SupplierAddresses, SupplierSites, SupplierSiteAssignments, APInvoices, Projects. Bad rows were added to DMT_POZ_SUPPLIERS_STG_TBL, DMT_AP_INVOICES_INT_STG_TBL, DMT_PJF_PROJECTS_STG_TBL.

| Test | Format | Scenario | Result | Verdict |
|---|---|---|---|---|
| 1 mixed rows | header | UPL-NEG-HDR-2610200004 | DMT_POZ_SUPPLIERS_STG_TBL.csv: 3 staged of 3 good, 3 error row(s) for 3 bad, log COMPLETED_WITH_ERRORS (errors: row 7 END_DATE_ACTIVE: Line 7, column END_DATE_ACTIVE: "NOT-A-DATE" is not a valid date (e / row 1 : ORA-01722: unable to convert string value containing 'N' to a number: 
ORA-03302:  / row 2 : ORA-12899: value too large for column "DMT2_OWNER"."DMT_POZ_SUPPLIERS_STG_TBL"."IM); DMT_AP_INVOICES_INT_STG_TBL.csv: 5 staged of 5 good, 3 error row(s) for 3 bad, log COMPLETED_WITH_ERRORS (errors: row 9 INVOICE_DATE: Line 9, column INVOICE_DATE: "NOT-A-DATE" is not a valid date (expecte / row 1 : ORA-01722: unable to convert string value containing 'N' to a number: 
ORA-03302:  / row 2 : ORA-12899: value too large for column "DMT2_OWNER"."DMT_AP_INVOICES_INT_STG_TBL"."); DMT_PJF_PROJECTS_STG_TBL.csv: 6 staged of 6 good, 3 error row(s) for 3 bad, log COMPLETED_WITH_ERRORS (errors: row 10 PROJECT_START_DATE: Line 10, column PROJECT_START_DATE: "NOT-A-DATE" is not a valid / row 1 : ORA-01722: unable to convert string value containing 'N' to a number: 
ORA-03302:  / row 2 : ORA-12899: value too large for column "DMT2_OWNER"."DMT_PJF_PROJECTS_STG_TBL"."PRO); run 189 prefix 93446 COMPLETED_ERRORS | PASS |
| 1 mixed rows | fbdi | UPL-NEG-FBDI-2610200004 | PoSupplierImport.csv: 3 staged of 3 good, 3 error row(s) for 3 bad, log COMPLETED_WITH_ERRORS (errors: row 6 END_DATE_ACTIVE: Line 6, column END_DATE_ACTIVE: "NOT-A-DATE" is not a valid date (e / row 1 : ORA-01722: unable to convert string value containing 'N' to a number: 
ORA-03302:  / row 2 : ORA-12899: value too large for column "DMT2_OWNER"."DMT_POZ_SUPPLIERS_STG_TBL"."ON); ApInvoicesInterface.csv: 5 staged of 5 good, 3 error row(s) for 3 bad, log COMPLETED_WITH_ERRORS (errors: row 8 INVOICE_DATE: Line 8, column INVOICE_DATE: "NOT-A-DATE" is not a valid date (expecte / row 1 : ORA-01722: unable to convert string value containing 'N' to a number: 
ORA-03302:  / row 2 : ORA-12899: value too large for column "DMT2_OWNER"."DMT_AP_INVOICES_INT_STG_TBL"."); PjfProjectsAllXface.csv: 6 staged of 6 good, 3 error row(s) for 3 bad, log COMPLETED_WITH_ERRORS (errors: row 9 PROJECT_START_DATE: Line 9, column PROJECT_START_DATE: "NOT-A-DATE" is not a valid d / row 1 : ORA-01722: unable to convert string value containing 'N' to a number: 
ORA-03302:  / row 2 : ORA-12899: value too large for column "DMT2_OWNER"."DMT_PJF_PROJECTS_STG_TBL"."PLA) | FAIL: the staged good rows differ from the baseline: DMT_AP_INVOICE_LINES_INT_STG_TBL -> DMT_AP_INVOICES_INT_STG_TBL on INVOICE_ID: 6 of 6 child rows find their parent in the baseline, 0 of 6 in the upload |
| 2 wrong layout | header | UPL-NEG-HDR-LAYOUT-2610200004 | DMT_POZ_SUPPLIERS_STG_TBL.csv carrying the DMT_PJF_PROJECTS_STG_TBL columns and its 6 rows: 0 row(s) staged, log FAILED (loaded 0, errored 1), loader said: Wrong layout: only 1 of the 10 columns in DMT_POZ_SUPPLIERS_STG_TBL.csv are columns of POZ_SUPPLIERS (DMT_POZ_SUPPLIERS_STG_TBL), so the file was not , page error shown: yes, Upload Errors rows: 1 | PASS |
| 2 wrong layout | fbdi | UPL-NEG-FBDI-LAYOUT-2610200004 | PoSupplierImport.csv with every value moved 3 slots right (3 rows, 158 slots instead of 155): 0 row(s) staged, log FAILED (loaded 0, errored 1), loader said: Wrong layout: the first row of PoSupplierImport.csv has 158 fields, but the Oracle FBDI template for POZ_SUPPLIERS has 155, so the file was not loaded, page error shown: yes, Upload Errors rows: 1 | PASS |
| 3 page message | test 1 mixed rows (header) | - | PASS: page showed error 'Error Message 1 error has occurred 3 file(s) in this upload failed or had rejected rows; see Upload Errors below. 10 objects, 50 rows loaded, 9 errors, 0 skippe' | PASS |
| 3 page message | test 1 mixed rows (fbdi) | - | PASS: page showed error 'Error Message 1 error has occurred 3 file(s) in this upload failed or had rejected rows; see Upload Errors below. POZ_SUPPLIERS: 3 loaded, 3 errors — 3 loaded, ' | PASS |
| 3 page message | test 2 wrong layout (header) | - | PASS: page showed error 'Error Message 1 error has occurred 1 file(s) in this upload failed or had rejected rows; see Upload Errors below. 1 objects, 0 rows loaded, 1 errors, 0 skipped.' | PASS |
| 3 page message | test 2 wrong layout (fbdi) | - | PASS: page showed error 'Error Message 1 error has occurred 1 file(s) in this upload failed or had rejected rows; see Upload Errors below. POZ_SUPPLIERS: 0 loaded, 1 errors — Wrong layo' | PASS |
