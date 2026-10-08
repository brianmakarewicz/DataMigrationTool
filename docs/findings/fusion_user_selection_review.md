# Which Fusion user each DMT call runs as (review, 2026-10-07)

## The rule being checked

Owner rule (2026-10-07): there is one central place that decides which Fusion user (username and password) DMT uses for an object. That place is `DMT_ERP_INTERFACE_OPTIONS_TBL.FUSION_USERNAME / FUSION_PASSWORD`, read through `DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS` (or `GET_CREDENTIALS_FOR_REQUEST`, which traces an ESS request id back to its CEMLI and then calls `GET_CEMLI_CREDENTIALS`). When the object's row has no user, `GET_CEMLI_CREDENTIALS` falls back to `DMT_CONFIG_TBL.FUSION_USERNAME / FUSION_PASSWORD`; that fallback is part of the central mechanism, so a call that goes through the resolver conforms even when the answer is the global user.

Every call DMT makes to Fusion for an object must get its user through that mechanism: the FBDI upload and loadAndImportData, ESS submit, poll and output download, BIP report runs, REST lookups (including "Verify in Fusion"), HDL upload, submit and poll, the REST loads for configuration objects, and the error and log fetches.

How the user is picked, as used in the table:

- **Central:** `GET_CEMLI_CREDENTIALS` / `GET_CREDENTIALS_FOR_REQUEST`, or credentials handed down from a caller that got them there. Conforms.
- **Config key:** a `DMT_CONFIG_TBL` key other than through the resolver (`BIP_USERNAME`, `HCM_USERNAME`, `FUSION_USERNAME` read directly, `<Object>_USERNAME`).
- **Hardcoded:** a username literal in code.
- **Default fallback:** the call passes no user (or `NULL`), so a transport helper (`DMT_UTIL_PKG.BASIC_AUTH_HEADER`, `DMT_UTIL_PKG.HTTP_REQUEST`, `DMT_LOADER_PKG.soap_http`, `DMT_ESS_UTIL_PKG.soap_http` / `soap_http_blob`) silently fills in `DMT_CONFIG_TBL.FUSION_USERNAME`. This bypasses the object's row: setting a user on that row has no effect on this call.
- **connections.json (Python):** only in tooling; listed separately.

"Can it disagree" asks whether this call can run as a different Fusion user from the one that submitted the object's load. Fusion refuses `getESSJobStatus` and `downloadESSJobExecutionDetails` on another user's request (HTTP 500 FND_CMN_SYS_ERR, proven for Grants in `docs/findings/known_good_Grants.md` and for P2P in queue-worker runs 86/96/97), so a disagreement on a poll or a download is a hard failure, not a cosmetic one.

Per-object users seeded today (`db/seed/dmt_erp_interface_options_tbl.sql` plus `db/migrations/2026-10-07_grants_ppm_impl_and_recon_v2.sql`): `calvin.roth` for Suppliers, SupplierAddresses, SupplierSites, SupplierContacts, SupplierSiteAssignments, PurchaseOrders, BlanketPOs, Contracts and Requisitions; `SCM_IMPL` for Items and ItemCategories; `scm_impl` for MiscReceipts; `ppm_impl` for Grants. Every other CEMLI resolves to the global `fin_impl` today, so for those objects a bypass is latent: it behaves correctly until someone sets a user on the object's row, which is exactly the action the rule says must work.

## What was reviewed

Every place in `db/packages`, `db/lookup`, `db/procedures`, `db/jobs`, `scripts`, `db/tools` and the two APEX exports (`apex/f500`, `apex/f501src`) that chooses a Fusion user or password or builds Fusion credentials, found by searching for `GET_CEMLI_CREDENTIALS`, `GET_CREDENTIALS_FOR_REQUEST`, `BASIC_AUTH_HEADER`, `Authorization`, `userID`, `GET_CONFIG('..._USERNAME' / '..._PASSWORD')`, `UTL_HTTP.BEGIN_REQUEST`, username literals, and every caller of the ESS, BIP and HDL wrappers (`SUBMIT_LOAD`, `SUBMIT_IMPORT_JOB`, `POLL_ESS_JOB`, `GET_IMPORT_ESS_ID`, `GET_ESS_ZIP`, `GET_ESS_OUTPUT_TEXT`, `GET_ESS_OUTPUT_XML`, `CAPTURE_ESS_OUTPUT`, `ENUMERATE_ESS_FILES`, `CAPTURE_ESS_HIERARCHY`, `CAPTURE_REPORT_ESS_JOB`, `RUN_BIP_REPORT`, `DMT_HDL_UTIL_PKG.REST_HTTP`). Line numbers are from `origin/main` on 2026-10-07. No product code was changed.

Out of scope for fixing here: `DMT_REST_LOOKUP_PKG` ("Verify in Fusion"), which another agent is fixing in an open PR; it is listed for completeness only.

## Summary

| | Count |
|---|---|
| Conforming pipeline paths | 20 |
| Non-conforming pipeline paths (backlog items #266 to #285) | 20 |
| Non-conforming, already being fixed elsewhere ("Verify in Fusion") | 1 |
| Unreferenced code that would bypass the rule if revived (one P3 item, #286) | 8 |
| Python tooling and other out-of-scope places (information only) | 12 |

P1 items (the wrong user, or a second credential copy the run never checks, would make a load, poll or reconcile fail or give a wrong result):

- **#266** reconciliation BIP runs (`RUN_BIP_REPORT`) use `BIP_USERNAME/BIP_PASSWORD` for every object.
- **#267** `GET_IMPORT_ESS_ID` uses `BIP_USERNAME/BIP_PASSWORD` with no fallback; a failure skips the import poll and reconciles early.
- **#268** `CAPTURE_ESS_HIERARCHY` uses `BIP_USERNAME/BIP_PASSWORD`, and `POLL_ESS_JOB` treats its failure as a hard stop.
- **#269** `CAPTURE_REPORT_ESS_JOB` finds the report child with `BIP_USERNAME/BIP_PASSWORD`; a failure skips the downstream-completion gate (backlog #71).
- **#270** `SUBMIT_IMPORT_JOB` has no user parameter, so Expenditures and the queue's post-run jobs submit as the global user and then poll as the object's user.
- **#271** AP Invoices submits with `NULL` credentials but its report child is polled through the central resolver.
- **#275** reconcile-time ESS output downloads (BillingEvents, Expenditures, ProjectBudgets, Projects, Assets) download as the global user what the object's user submitted.
- **#278** HDL (all HCM objects) runs as `HCM_USERNAME`, while the run preflight verifies a different credential for those objects.

Two P2 items fail today, not just latently, because they download output of jobs submitted by a per-object user: **#274** (`CAPTURE_ESS_OUTPUT`, Suppliers, Grants, MiscReceipts) and **#276** (import-report error harvest, PurchaseOrders, BlanketPOs, Contracts, Requisitions, Items). Both are error and log fetches whose failure is logged and swallowed, so the row verdicts still come from BIP; the user loses the Fusion error text. **#277** (the "Fetch File List" button) also fails today for those objects' jobs.

A credential-maintenance gap ties the P1 items together: `db/tools/setup_runtime_config.py`, which `scripts/ci_promote.py runtime-config` runs after every deploy, sets only `DMT_CONFIG_TBL.FUSION_PASSWORD` and the per-object passwords in `DMT_ERP_INTERFACE_OPTIONS_TBL`. It never sets `BIP_PASSWORD` or `HCM_PASSWORD` (only `test/unit/setup_fusion_config.py` does), and `DMT_UTIL_PKG.RUN_PREFLIGHT` verifies only what `GET_CEMLI_CREDENTIALS` returns. So the BIP and HDL credentials are second copies that the deploy tooling does not refresh and the run gate does not check; when one goes stale, the preflight passes and the run fails mid-flight.

## Conforming paths

| # | File and line | Serves | How the user is picked | Can it disagree with the loading user? |
|---|---|---|---|---|
| 1 | `db/packages/dmt_util_pkg.pkb.sql:641-663` `GET_CEMLI_CREDENTIALS` | The central resolver itself | Central: options row, else `FUSION_USERNAME/PASSWORD` | No. Note: username and password are each `NVL`'d separately, so a row with a user but a `NULL` password pairs that user with the global password (401). Resolving as a pair would be safer. |
| 2 | `db/packages/dmt_util_pkg.pkb.sql:670-688` `GET_CREDENTIALS_FOR_REQUEST` | ESS downloads keyed by request id | Central, via `DMT_ESS_JOB_TBL.CEMLI_CODE` | Only if the request id is not in `DMT_ESS_JOB_TBL` (then global). |
| 3 | `db/packages/dmt_util_pkg.pkb.sql:1831-1838` `RUN_PREFLIGHT` | Pre-run credential check per CEMLI in the run | Central | No, but it verifies only the central credential; see #266 to #269 and #278 for the credentials it never checks. |
| 4 | `db/packages/dmt_util_pkg.pkb.sql:1734-1770` `VERIFY_CREDENTIAL` | One authenticated probe | Caller-supplied (from #3) | No. |
| 5 | `db/packages/dmt_loader_pkg.pkb.sql:1315` `sup_after_generate` (submit 1318-1328, polls 1350, 1375) | Suppliers, SupplierAddresses, SupplierSites, SupplierContacts, SupplierSiteAssignments: upload, loadAndImportData, poll | Central | No (the ESS output capture at 1409 does; see #274). |
| 6 | `db/packages/dmt_loader_pkg.pkb.sql:2079` `fin_after_generate` (submit 2082-2092, polls 2114, 2139) | BillingEvents, Grants, Projects, PlanBudgets, ProjectBudgets, Assets: upload, load, poll | Central | No (the output capture at 2198 does; see #274). |
| 7 | `db/packages/dmt_loader_pkg.pkb.sql:2539` with `po_submit_and_reconcile_one` 1511-1583 | PurchaseOrders: upload, load, polls | Central | No (the import-report harvest at 1602 does; see #276). |
| 8 | `db/packages/dmt_loader_pkg.pkb.sql:2884` | Customers via `po_submit_and_reconcile_one` | Central | No. |
| 9 | `db/packages/dmt_loader_pkg.pkb.sql:3061` with `ar_submit_and_reconcile_one` 1815-1883 | ARInvoices: upload, load, polls | Central | No (harvest at 1916; see #276). |
| 10 | `db/packages/dmt_loader_pkg.pkb.sql:3322` (load 3454-3464, polls 3472-3473, 3504-3505) | Expenditures: upload, load, both polls | Central | Yes, through the import submit at 3498; see #270. |
| 11 | `db/packages/dmt_loader_pkg.pkb.sql:3720` | Requisitions via `po_submit_and_reconcile_one` | Central | No (harvest; see #276). |
| 12 | `db/packages/dmt_loader_pkg.pkb.sql:3952` | Items and ItemCategories (one FBDI) via `po_submit_and_reconcile_one` | Central | No (harvest; see #276). |
| 13 | `db/packages/dmt_loader_pkg.pkb.sql:4181` (load 4184-4194, poll 4217-4218, PollTMEssJob submit 4247-4262, poll 4288-4289) | MiscReceipts | Central | No (output capture at 4322; see #274). |
| 14 | `db/packages/dmt_loader_pkg.pkb.sql:4457` and `:4575` | BlanketPOs and Contracts via `po_submit_and_reconcile_one` | Central | No (harvest; see #276). |
| 15 | `db/packages/dmt_queue_worker_pkg.pkb.sql:1709` (poll 1720-1730) | Async queue poll of every load/import job | Central | Yes for post-run jobs, which are submitted without a user; see #270. |
| 16 | `db/packages/dmt_ess_util_pkg.pkb.sql:1149` (report-child poll 1239-1243, enumerate 1355-1358) | `CAPTURE_REPORT_ESS_JOB`: poll and file list of the import report child | Central | No for these two calls (the BIP lookup at 1152 does not conform; see #269). |
| 17 | `db/packages/dmt_ess_util_pkg.pkb.sql:963-968` `DOWNLOAD_ESS_FILE_TO_BROWSER` | Console file download | Central (auto-resolves by request id when no user is passed) | Only as in #2. |
| 18 | `db/packages/dmt_fnd_vs_results_pkg.pkb.sql:217` (submit 236-246, poll 253-262) | ValueSets: upload, load, poll | Central | No. |
| 19 | `db/packages/dmt_grants_results_pkg.pkb.sql:175-180` | Grants import-report XML download | Central | No. |
| 20 | APEX download processes: `apex/f500/application/shared_components/logic/application_processes/download_ess_file.sql:38`, `download_ess_file_v2.sql:46`, `apex/f500/application/pages/page_00057.sql:270`; `apex/f501src/livedmt2/shared-components/app-processes.apx:24, 81`, `apex/f501src/livedmt2/pages/p00057-record-detail.apx:284` | Console "download this ESS file" | Central (`GET_CREDENTIALS_FOR_REQUEST` / `GET_CEMLI_CREDENTIALS`, or the auto-resolve in #17) | Only as in #2. The `ENUMERATE` branch of the same processes does not conform; see #277. |

## Non-conforming pipeline paths

| File and line | Serves | How the user is picked | Can it disagree with the loading user? | Backlog |
|---|---|---|---|---|
| `db/packages/dmt_util_pkg.pkb.sql:1110-1111` `RUN_BIP_REPORT` (takes `p_cemli_code` but ignores it for the user). Callers: `dmt_recon_engine_pkg:124`, `dmt_recon_contract_pkg:93`, every `*_compare_pkg` (ap, ar, cust, gl, hcm, po, ppm, sup, fa_req), the five `dmt_poz_sup_*_results_pkg:48`, `dmt_egp_item_results_pkg:564, 581`, `dmt_egp_item_cat_results_pkg:180`, `dmt_billing_event_results_pkg:748`, `dmt_expenditure_results_pkg:770`, `dmt_fnd_vs_results_pkg:342`, `dmt_fnd_lookup_results_pkg:503`, `dmt_inv_uom_results_pkg:329`, `dmt_zx_results_pkg:457`, `dmt_ap_pay_term_results_pkg:334`, `dmt_ce_bank_results_pkg:595`, `dmt_plan_budget_results_pkg:100` | BIP reconciliation and post-run comparison for every object | Config key: `BIP_USERNAME`, else `FUSION_USERNAME` | Yes: always `fin_impl` (Grants loads as `ppm_impl`, Requisitions as `calvin.roth`). Today's data models read base tables without data security, so results match; the live risk is the separate `BIP_PASSWORD` copy, which the deploy tooling never refreshes and the preflight never verifies. | #266 P1 |
| `db/packages/dmt_loader_pkg.pkb.sql:1009-1010` `get_import_ess_id` (callers: `dmt_queue_worker_pkg:1743, 1844`, `dmt_egp_item_*_results_pkg`) | Finding the import job id spawned by loadAndImportData | Config key: `BIP_USERNAME/BIP_PASSWORD`, no fallback (raises -20051 if either is missing) | Yes (same as above). On failure the queue worker sets the import id to `NULL` and goes straight to RECONCILING, so the import job is never polled and reconcile can run before Fusion has finished. | #267 P1 |
| `db/packages/dmt_ess_util_pkg.pkb.sql:399-400` `CAPTURE_ESS_HIERARCHY` (called from `dmt_loader_pkg:828` inside `POLL_ESS_JOB`, `dmt_queue_worker_pkg:1765`, `dmt_fnd_vs_results_pkg:147`) | ESS job tree capture | Config key: `BIP_USERNAME`, else `FUSION_USERNAME` | Yes. `POLL_ESS_JOB` documents this call as a hard stop ("do not swallow"), so a stale BIP credential fails the poll of every object. | #268 P1 |
| `db/packages/dmt_ess_util_pkg.pkb.sql:1152-1153` `CAPTURE_REPORT_ESS_JOB`, the BIP lookup of the report child | Finding the import report child job | Config key: `BIP_USERNAME`, else `FUSION_USERNAME` (the poll and enumerate in the same procedure are central) | Yes. Failure returns `NULL` silently, which skips the backlog #71 downstream-completion gate and lets reconcile run early (early UNACCOUNTED). | #269 P1 |
| `db/packages/dmt_loader_pkg.pkb.sql:525-650` `SUBMIT_IMPORT_JOB` (no user parameter; `soap_http` at 598 gets none). Callers: Expenditures `dmt_loader_pkg:3498`, GLBudgets `:6008`, queue post-run `dmt_queue_worker_pkg:1602` | ESS submit of a separate import or post-run job | Default fallback (global user) | Yes, structurally: Expenditures polls that job at 3504 as the Expenditures user, and the queue worker polls post-run jobs (Assets PostMassAdditions and other `POST_LOAD_JOB_NAME` rows) as the object's user. Setting a user on those rows makes the poll return HTTP 500. | #270 P1 |
| `db/packages/dmt_loader_pkg.pkb.sql:4696, 4746-4759` `RUN_AP_INVOICES` passes `p_username => NULL, p_password => NULL` | AP Invoices upload, load, polls | Default fallback | Yes, structurally: the report child (`APXIIMPT_BIP`) is polled through the central resolver in `CAPTURE_REPORT_ESS_JOB`. Setting an AP user makes the submit stay `fin_impl` while the report-child poll runs as the new user, so the completion gate times out and rows stay unaccounted. | #271 P1 |
| `db/packages/dmt_loader_pkg.pkb.sql:5728, 5799-5812` `RUN_GL_BALANCES` passes `NULL` credentials | GL Balances upload, load, polls | Default fallback | Consistent today (no report child, every call global); a user set on the GLBalances row is ignored. | #272 P2 |
| `db/packages/dmt_loader_pkg.pkb.sql:5942-5958, 6008-6012` `RUN_GL_BUDGETS` (`SUBMIT_LOAD`, `POLL_ESS_JOB`, `SUBMIT_IMPORT_JOB` all without a user) | GL Budgets upload, load, per-run-name import, polls | Default fallback | Consistent today; a user set on the GLBudgets row is ignored. | #273 P2 |
| `db/packages/dmt_ess_util_pkg.pkb.sql:611-624` `GET_ESS_OUTPUT_TEXT` (calls `GET_ESS_ZIP` with no user) via `CAPTURE_ESS_OUTPUT` 756-775. Callers: `dmt_loader_pkg:1409` (Suppliers x5), `:2198` (BillingEvents, Grants, Projects, PlanBudgets, ProjectBudgets, Assets), `:4322` (MiscReceipts) | ESS output capture into the log when rows are still GENERATED after reconcile | Default fallback | Yes, and it fails today for Suppliers x5 (`calvin.roth`), Grants (`ppm_impl`) and MiscReceipts (`scm_impl`). The failure is logged and swallowed. | #274 P2 |
| `GET_ESS_OUTPUT_XML` / `GET_ESS_OUTPUT_TEXT` called without a user inside reconcile: `dmt_billing_event_results_pkg:406`, `dmt_expenditure_results_pkg:212, 411, 479`, `dmt_prj_budget_results_pkg:143`, `dmt_project_results_pkg:213`, `dmt_fa_asset_results_pkg:539` | Reading the import report or SQL*Loader log to attribute per-row errors and verdicts | Default fallback | Yes, structurally: these jobs are submitted through the central resolver, so the moment one of these objects gets a user the download returns HTTP 500 and the per-row attribution silently disappears (wrong verdicts). Latent today (all resolve to `fin_impl`). | #275 P1 |
| `db/packages/dmt_import_report_pkg.pkb.sql:186` `PARSE_AND_LOG_ERRORS` (`GET_ESS_OUTPUT_XML` with no user), called from `dmt_loader_pkg:1602` (`po_submit_and_reconcile_one`) and `:1916` (`ar_submit_and_reconcile_one`) | Import-report error harvest into the log | Default fallback | Yes, and it fails today for PurchaseOrders, BlanketPOs, Contracts, Requisitions (`calvin.roth`) and Items/ItemCategories (`SCM_IMPL`). Logged as "Import Report capture failed ... Continuing to BIP"; row verdicts still come from BIP. | #276 P2 |
| `db/packages/dmt_ess_util_pkg.pkb.sql:822-836` `ENUMERATE_ESS_FILES` called with no user from `apex/f500/application/pages/page_00058.sql:125`, `apex/f500/.../download_ess_file.sql:29`, `download_ess_file_v2.sql:30`, `apex/f501src/livedmt2/pages/p00058-ess-job-output.apx:114`, `apex/f501src/livedmt2/shared-components/app-processes.apx:15, 65`; also `ENUMERATE_ALL_ESS_FILES` 906-923 (manual helper) | Console "Fetch File List from Fusion" | Default fallback | Yes, and it fails today for every job submitted by a per-object user. | #277 P2 |
| `db/packages/dmt_hdl_util_pkg.pkb.sql:12-26` `get_auth` (used by `REST_HTTP` at 61, so by `UPLOAD_HDL`, `SUBMIT_HDL`, `POLL_HDL`, `GET_HDL_ERRORS`, `LOOKUP_FUSION_IDS`) | HDL upload, submit, poll, error fetch and Fusion-id lookups for every HCM object | Config key: `HCM_USERNAME`, else `FUSION_USERNAME` | Not with itself (every HDL call uses the same user), but `RUN_PREFLIGHT` verifies the central credential for HCM CEMLIs (`fin_impl`), not `hcm_impl`, and `setup_runtime_config.py` never sets `HCM_PASSWORD`. A stale HCM password passes the preflight and fails the HDL load. Moving HDL onto the resolver needs options rows for the HCM CEMLIs first, or it would fall back to `fin_impl`, which gets HTTP 403 on `uploadFile`. | #278 P1 |
| `db/packages/dmt_ap_pay_term_results_pkg.pkb.sql:73-74` private `rest_call` | PaymentTerms REST load | Config key: `FUSION_USERNAME/PASSWORD` read directly | Consistent within the object; a user set on the PaymentTerms row is ignored. | #279 P2 |
| `db/packages/dmt_fnd_lookup_results_pkg.pkb.sql:88-89` private `rest_call` | Lookups REST load | Config key: `FUSION_USERNAME/PASSWORD` | As above. | #280 P2 |
| `db/packages/dmt_inv_uom_results_pkg.pkb.sql:61-62` private `rest_call` | UnitsOfMeasure REST load | Config key: `FUSION_USERNAME/PASSWORD` | As above. | #281 P2 |
| `db/packages/dmt_zx_results_pkg.pkb.sql:69-70` private `rest_call` | TaxConfig REST load | Config key: `FUSION_USERNAME/PASSWORD` | As above. | #282 P2 |
| `db/packages/dmt_ce_bank_results_pkg.pkb.sql:60, 85-86` private `rest_call` | CashBanks REST load | Hardcoded `C_CE_USERNAME := 'fin_impl'`, paired with the global `FUSION_PASSWORD` | Consistent today, but user and password come from different sources: if `FUSION_USERNAME` is ever changed, CashBanks sends `fin_impl` with the other user's password (401, and repeated 401s risk a lockout). | #283 P2 |
| `db/packages/dmt_util_pkg.pkb.sql:1622` `REFRESH_LOOKUPS` (run preflight) through `db/packages/dmt_bip_deploy_pkg.pkb.sql:221-222` `GET_SESSION_TOKEN` and `:23-26` `bip_username` (the `/~user/` scratch folder); also every `DMT_BIP_DEPLOY_PKG.DEPLOY_RECON_REPORT` / `DEPLOY_CATALOG_OBJECT` call | Name-to-id lookup refresh at the start of every run; BIP catalog deploys | Config key: `FUSION_USERNAME/PASSWORD` read directly | Not object-scoped, so it cannot disagree with an object's loading user; but there is no central decision for the run-scoped user either. | #284 P2 |
| Silent global defaults in the transport helpers: `db/packages/dmt_util_pkg.pkb.sql:53-54` (`BASIC_AUTH_HEADER`), `:374` (`HTTP_REQUEST` with no `p_auth_header`), `db/packages/dmt_loader_pkg.pkb.sql:211-213` (`soap_http`), `db/packages/dmt_ess_util_pkg.pkb.sql:40, 117` (`soap_http`, `soap_http_blob`), and the `DEFAULT NULL` user parameters on `SUBMIT_LOAD`, `POLL_ESS_JOB`, `GET_ESS_ZIP`, `GET_ESS_OUTPUT_XML`, `DOWNLOAD_ESS_FILE_BLOB`, `ENUMERATE_ESS_FILES`, `ENUMERATE_ALL_ESS_FILES`, `DOWNLOAD_ESS_FILE_TO_BROWSER` | Every Fusion call that does not pass a user | Default fallback | This is the mechanism behind #270 to #277: omitting the user is silently accepted. | #285 P2 |
| `db/packages/dmt_rest_lookup_pkg.pkb.sql:113-125` `LOOKUP_RECORD` (via `DMT_REST_QUERY_PKG.QUERY_FUSION_RECORD`) | "Verify in Fusion" REST lookup | Config key: `<Object>_USERNAME`, else `HCM_USERNAME` when `AUTH_TYPE = 'HCM'`, else `FUSION_USERNAME` | Yes (not the options-table user). | Being fixed in another agent's open PR (backlog #223); no new item. |

## Unreferenced code that would bypass the rule if revived

None of these is called by the pipeline or the console today (checked by searching `db`, `apex` and `scripts` for callers). They are collected in one P3 item, **#286**, to delete them or route them through the resolver.

| File and line | What it is | How it picks the user |
|---|---|---|
| `db/packages/dmt_rest_loader_pkg.pkb.sql:19-35, 93` | Generic REST loader (`LOAD_OBJECT_REST`, `POST_TO_FUSION`, `PATCH_FUSION`); installed, never called | `FUSION_USERNAME/PASSWORD` directly |
| `db/packages/dmt_util_pkg.pkb.sql:444-591` `BIP_REQUEST` | Old REST BIP helper | Default fallback via `HTTP_REQUEST` |
| `db/packages/dmt_ess_util_pkg.pkb.sql:504-537` `DOWNLOAD_ESS_FILE` | Legacy CLOB download | Default fallback |
| `db/packages/dmt_egp_item_results_pkg.pkb.sql:619-773` `LOAD_AND_RECONCILE` | Old Items load path (`SUBMIT_LOAD` 668, polls 704, 726) | Default fallback; would submit Items as `fin_impl` instead of `SCM_IMPL` |
| `db/packages/dmt_egp_item_cat_results_pkg.pkb.sql:218-340` `LOAD_AND_RECONCILE` | Old ItemCategories load path (`SUBMIT_LOAD` 259, polls 292, 308) | Default fallback; same problem |
| `db/packages/dmt_bip_setup_pkg.pkb.sql:23-26, 173-174, 459-460` | BIP proof-of-concept package | `FUSION_USERNAME/PASSWORD` directly |
| `db/lookup/packages/dmt_lkp_refresh_pkg.pkb:78-79, 125-126` | `DMT_LOOKUP` schema refresh package; `REFRESH_LOOKUPS` uses `DMT_BIP_DEPLOY_PKG` instead | `SELECT` from `DMT_CONFIG_TBL` (`FUSION_USERNAME/PASSWORD`) |
| `db/packages/fbt_bip_pkg.pkb.sql` (whole package) | Standalone BIP toolkit; credentials are parameters. Only `scripts/fusion_bip_query.py` calls it | Caller-supplied |

## Python tooling and other out-of-scope places (information only)

| File and line | What it does | How it picks the user |
|---|---|---|
| `db/tools/setup_runtime_config.py:82-110` | Fills `FUSION_PASSWORD` and the per-object `FUSION_PASSWORD`s from connections.json after a deploy (run by `scripts/ci_promote.py:317-333 runtime-config`) | connections.json, matched by the username already in the DB. It is the tool that feeds the central mechanism; it does not set `BIP_PASSWORD` or `HCM_PASSWORD` (see the summary). |
| `test/unit/setup_fusion_config.py:43-68` | Local test setup | connections.json (`fin_impl`, `hcm_impl`); the only place that writes `BIP_USERNAME/PASSWORD` and `HCM_USERNAME/PASSWORD` |
| `scripts/fusion_bip_query.py:25-52` | Read-only research queries | connections.json via `--cred` (default `fin_impl`) |
| `scripts/deploy_ess_child_job_dm.py:36-37, 54` | One-off BIP data-model deploy | `BIP_USERNAME/PASSWORD` from the DB config |
| `scripts/deploy_recon_bip_reports.py:183` | Deploys recon reports through `DMT_BIP_DEPLOY_PKG.DEPLOY_RECON_REPORT` | DB-side `FUSION_USERNAME` (see #284) |
| `scripts/dmt_regression_run.py`, `scripts/dmt_deploy.py`, `scripts/build_results_xlsx.py`, `scripts/build_expanded_scenario.py`, `scripts/load_expert_rows.py` | DB connections only | No Fusion user |
| `scripts/dmt_apex_smoke.py`, `scripts/dmt_apex_playwright_gate.py`, `scripts/dmt_apex_url_target.py`, `scripts/playwright_verify.js`, `test/playwright/*` | APEX console login (`DMT_SMOKE`) | APEX user, not a Fusion user |
| `scripts/insert_regression_test_data.py:1804` | Comment only (Grants loads as `PPM_IMPL`) | None |
| `apex/f500/application/pages/page_09999.sql`, `apex/f501src/livedmt2/pages/p09999-login.apx` | APEX login page | APEX user, not a Fusion user |
| `db/views/dmt_config_admin_v.sql` | Masks secret config values in the UI | None |
| `db/packages/dmt_ben_depend_hdl_gen_pkg.pkb.sql:25`, `dmt_ben_partic_hdl_gen_pkg.pkb.sql:31`, `dmt_work_sched_hdl_gen_pkg.pkb.sql:20` | Comments recording how something was verified (`--cred fin_impl`) | None |
| `db/seed/dmt_config_tbl.sql:54-99` | Seeds `BIP_USERNAME`, `FUSION_USERNAME`, `HCM_USERNAME` (passwords masked) | Seed data for the config keys above |

## Side findings (not about users; recorded so they are not lost)

- `db/packages/dmt_queue_worker_pkg.pkb.sql:1765` calls `DMT_ESS_UTIL_PKG.CAPTURE_ESS_HIERARCHY(l_rec.RUN_ID, l_rec.CEMLI_CODE, l_rec.LOAD_ESS_JOB_ID)` positionally, but the signature is `(p_run_id, p_parent_request_id NUMBER, p_cemli_code)`. The CEMLI code lands in the request-id parameter, the conversion fails, and the surrounding `WHEN OTHERS THEN NULL` hides it, so this hierarchy capture never happens.
- Both page-58 exports (`apex/f500/application/pages/page_00058.sql:125-126`, `apex/f501src/livedmt2/pages/p00058-ess-job-output.apx:114`) call `DMT_ESS_UTIL_PKG.DOWNLOAD_ESS_FILE_V2_TO_BROWSER`, which does not exist in `db/packages/dmt_ess_util_pkg.pks.sql`, so the page-58 download action errors (caught and returned as JSON `error`).
