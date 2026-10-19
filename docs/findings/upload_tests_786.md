# Upload tests per object on ATP (backlog #786), 2026-10-19

The test is `test/playwright/dmt_upload_verify.py`. Per-entry results are in
`upload_verify_atp_20261019.json`, with a table in `upload_verify_atp_20261019.md`.

## What ran on ATP

1. **Suppliers, header format, end to end.** The Suppliers file (3 rows) went
   through Smart Upload (page 25) of app 500 into the new scenario
   UPL-HDR-Suppliers-2610191717 and staged exactly (3 of 3 rows, every value
   unchanged, no upload errors). Run 185 (prefix 93437, synced to the highest
   prefix used on local and ATP plus one, and not used on local) halted at
   preflight: the BIP login was refused with *invalid username or password*. So
   GOOD 0/2 LOADED, BAD 0/1 FAILED with an error, 3 of 3 rows unaccounted:
   **FAIL**. The test reported this correctly.
2. **Upload half for all 27 objects in both formats** (`--upload-only`, so no
   runs and no prefixes used), each into its own new scenario.

## Why the runs stopped: the Fusion demo password has expired

A cookie-free REST call to the demo pod returns HTTP 401 for all six demo users
(fin_impl, calvin.roth, natalie.salesrep, scm_impl, hcm_impl, ppm_impl) with the
password in connections.json, steadily, eight minutes apart, while the pod
itself answers. ATP stores that same password. This is the pod-side password
expiry case, which needs the demo password rotated (the rotate-demo-password
routine). Rotating it changes the shared password for every demo user, so it
needs the owner's approval. No other run was submitted.

## Upload results (checks 1 and 2)

**Header format: all 27 objects PASS the upload.** Each object's files, and its
upstream objects' files, staged with exactly the file's rows and every value
unchanged, and no row went to DMT_UPLOAD_ERROR_TBL.

**FBDI format** (16 objects where it applies):

| Result | Objects |
|---|---|
| staged exactly | Suppliers, SupplierAddresses, SupplierSites, SupplierSiteAssignments, SupplierContacts, APInvoices, Customers, Projects, BillingEvents |
| staged nothing (Oracle error) | Items (ORA-12899), GLBalances (ORA-01841), GLBudgets (ORA-01722) |
| own files staged, upstream Items file did not | Requisitions, PurchaseOrders |
| page said loaded, values in the wrong columns | Expenditures (8 rows), ProjectBudgets (6 rows) |
| not applicable | BlanketPOs, Contracts, MiscReceipts, Assets (no FBDI mapping); ARInvoices (partial: no FBDI file for distributions); Grants (partial: 13 of its 15 tables have no FBDI file); Workers, Salaries, SalaryBases, Absences, TalentProfiles (HCM Data Loader) |

The FBDI failures share one cause, backlog **#787**: DMT_UPLOAD_DICT_TBL has no
FBDI_POSITION on ATP or local, because the deploy runs the seed files
alphabetically and the dictionary rebuild in dmt_upload_object_tbl.sql wipes the
positions dmt_upload_fbdi_metadata.sql set. The loader then maps FBDI slot N to
the Nth column, which only works where a table's column order happens to equal
the FBDI order. The FBDI objects that failed are expected to stage once the
positions are back, but that is not proven yet.

Backlog **#788**: when a file in the zip fails, page 25 shows it inside the green
success message and writes nothing to DMT_UPLOAD_ERROR_TBL, so the Upload Errors
region says there are none.

## Expected outcomes and the Fusion id rule

GOOD and BAD come from the regression's own verdict for the same source row in
baseline run 184. Applied to run 184 itself, the test's judging gives PASS for
25 of the 27 objects, exactly as the regression does. The other two are flagged
only by the owner's "LOADED with a Fusion id" rule: 30 Grants child rows (award
funding, projects, personnel, and so on) and 2 MiscReceipts rows (one lot, one
serial) are LOADED from their own success line in the import report and carry
no Fusion id. The design accepts this (section 5, cross-grain shape (c)). The
test counts them as failures until the owner decides otherwise.

## Ready for functional testing

None yet. No object has a passing run, because no run could reach Fusion. These
cannot be ready until #787 is fixed, because their FBDI upload fails: Items,
Requisitions, PurchaseOrders, GLBalances, GLBudgets, Expenditures and
ProjectBudgets.

## To finish

After the password is rotated (and ATP's stored copy updated with
`scripts/ci_promote.py runtime-config --target atp --yes`), run:

```
python test/playwright/dmt_upload_verify.py --target atp --objects all --formats header,fbdi \
    --json-out docs/findings/upload_verify_atp_20261019.json \
    --md-out docs/findings/upload_verify_atp_20261019.md --skip-done
```

This runs every uploaded-but-not-run entry on the scenario it already uploaded,
one run at a time, with the prefix synced before each run.
