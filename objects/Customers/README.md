# Customers

## Status
DMT2 offline slice proven 2026-07-09 (unit suite 27/27, golden byte-identical to
run 116). Reconciler rebuilt fail-CLOSED / two-tier 2026-07-09 (obj/customers-rule1)
— no more fail-open. Live Rule #1 gate BLOCKED upstream: the customer bulk import
job fails with `batchId is null`, so GOOD rows cannot reach the Fusion base tables
yet (see Known Issues). Frozen predecessor stack: E2E LOADED.

## The object model — ONE object, seven record types
Customers is ONE object. Its single FBDI zip carries SEVEN HZ CSVs (parties,
locations, party sites, party site uses, accounts, account sites, account site
uses) — record types of one object, NOT seven objects. One zip, one ESS load
job. Contrast the five-object supplier family. See the registry rows in
`db/seed/dmt_cemli_catalog_tbl.sql` (7 record types) and
`db/seed/dmt_pipeline_def_tbl.sql` (one Customers row, EXEC_PROC
DMT_LOADER_PKG.RUN_CUSTOMERS / RECON_PROC DMT_CUST_RESULTS_PKG.RECONCILE_BATCH).

## Pipeline
- Module: Financials
- FBDI Template: HzImpPartiesT.xlsm (7 sheets)
- Interface Tables: HZ_IMP_PARTIES_T, HZ_IMP_LOCATIONS_T, HZ_IMP_PARTY_SITES_T, HZ_IMP_PARTY_SITE_USES_T, HZ_IMP_ACCOUNTS_T, HZ_IMP_ACCOUNT_SITES_T, HZ_IMP_ACCOUNT_SITE_USES_T
- FBDI CSV members: HzImpPartiesT, HzImpLocationsT, HzImpPartySitesT, HzImpPartySiteUsesT, HzImpAccountsT, HzImpAcctSitesT, HzImpAcctSiteUsesT (LF-terminated)
- UCM Account: ar/customerImport/import
- ESS Job: /oracle/apps/ess/cdm/foundation/bulkImport
- ParameterList: UNKNOWN -- needs verification (live phase)
- Loader Type: SQLLOADER
- Auth User: fin_impl

## Record types
1. Parties
2. Locations
3. PartySites
4. PartySiteUses
5. Accounts
6. AccountSites
7. AccountSiteUses

## Code References (DMT2 layout)
- STG/TFM Table DDL: `db/tables/dmt_hz_{parties,locations,party_sites,party_site_uses,accounts,acct_sites,acct_site_uses}_{stg,tfm}_tbl.sql`
  (14 tables; PKs are GENERATED ALWAYS AS IDENTITY — the per-table id sequences were retired 2026-07-09)
- Retired-sequence drop tool: `db/tools/drop_retired_customer_sequences.sql`
- Validator: `db/packages/dmt_cust_validator_pkg.*`
- Transformer: `db/packages/dmt_cust_transform_pkg.*` (7 TRANSFORM_* procedures)
- FBDI Generator: `db/packages/dmt_cust_fbdi_gen_pkg.*` (one GENERATE_FBDI, builds the 7-CSV zip)
- Results/Reconciliation: `db/packages/dmt_cust_results_pkg.*` (Contract v1, shared transport)
- BIP Data Model/Report: `bip/Customers/DMT_CUST_RECON_DM.xdm` + `DMT_CUST_RECON_RPT.xdo`
  (deploy target `/Custom/DMT2/Customers/`; deployed by `scripts/deploy_supplier_bip_reports.py Customers`)
- Golden inputs: `test/golden/inputs/Customer*_input.csv`; golden zip `test/fbdi_zips/Customers_116.zip`
- Unit test: `test/unit/test_customers.sql`; golden compare: `test/golden/test_customers_golden.sh`

## Reference Files
None in this folder.

## Known Issues
- **FIXED 2026-07-09 (obj/customers-rule1): the fail-open reconciler is gone.**
  The old reconciler read only the interface table `HZ_IMP_PARTIES_T` and marked
  a party LOADED when `INTERFACE_STATUS` was NULL. On this demo instance the
  interface status is always NULL after import, so every row — including the BAD
  one — was wrongly LOADED and no real Fusion id was captured. The reconciler is
  now **two-tier and fail-CLOSED** (same shape as GLBalances): the BIP report
  positively confirms each record type against its own Fusion **base** table via
  `HZ_ORIG_SYS_REFERENCES` (`ORIG_SYSTEM='DMT'` + the prefixed reference) and
  reads `HZ_IMP_ERRORS` for reject text. A TFM row is marked LOADED **only** when
  a real base id is returned (stored in that record type's `FUSION_*_ID` column);
  FAILED when Fusion error text is present; otherwise left un-LOADED and swept to
  FAILED. There is no interface-status path and no parent→child LOADED cascade —
  each record type is confirmed by its own base id. Absence is never LOADED.
- **OPEN, upstream of the reconciler — the customer bulk import job fails with
  `batchId is null`, so no row reaches the base tables (found by the
  2026-07-09 live re-gate, run 152 / scenario CUSTOMERS_R1_0709 / prefix
  10035).** The FBDI load ESS job (`InterfaceLoaderController` 9719106) SUCCEEDS
  and lands all 3 parties in `HZ_IMP_PARTIES_T`, but the chained
  `BulkImportJob` (9719122) is invoked with **Batch ID = null** and its child
  `DataImportJob` (9719131) throws:
  `java.lang.NullPointerException: Cannot invoke "String.trim()" because
  "this.batchId" is null`. Nothing moves from the interface table to
  `HZ_PARTIES`/`HZ_LOCATIONS`/…; `HZ_ORIG_SYS_REFERENCES` gets no `DMT` rows for
  the prefix and `HZ_IMP_ERRORS` stays empty. The import ParameterList DMT sends
  (`NEW,N,<run_id>`) does not carry the Batch ID this bulk import needs — this is
  the "ParameterList: UNKNOWN — needs verification (live phase)" item above, now
  pinned to a concrete failure. **Consequence:** the two-tier reconciler
  correctly marks all 21 rows FAILED with `[RECONCILE_ERROR]` (unaccounted=0),
  because the base tables genuinely lack the rows — it does **not** fake a pass.
  The live Rule #1 gate therefore does NOT yet pass on this instance: the GOOD
  half (LOADED with real base ids) cannot be shown until the import job gets its
  Batch ID. The reconciler/report fix is complete and correct; the blocker is
  the import ParameterList. Tracked as the next Customers live item.
- Related, upstream: the customer **validator** (`DMT_CUST_VALIDATOR_PKG`) does
  not reject the BAD party's invalid `PARTY_TYPE` before generation — RT-CUST-BAD1
  reaches STG_STATUS = TRANSFORMED with no error and flows into the FBDI zip. A
  stronger pre-validation would have failed it before the ESS load. Tracked
  separately.

## History
- 2026-07-09 (obj/customers-rule1 — fail-open fix): rebuilt the reconciler
  `DMT_CUST_RESULTS_PKG.PARSE_AND_UPDATE` to be two-tier and fail-CLOSED and
  rebuilt `bip/Customers/DMT_CUST_RECON_DM.xdm` to a two-tier query. The report
  now LEFT JOINs each record type's Fusion base table via `HZ_ORIG_SYS_REFERENCES`
  (`ORIG_SYSTEM='DMT'` + prefixed reference) for a real id, and reads
  `HZ_IMP_ERRORS` (via BATCH_ID) for reject text; it emits per row RECORD_TYPE,
  ORIG_SYSTEM_REFERENCE, FUSION_ID, ERROR_MESSAGE (GL-style Contract-v1 shape).
  The reconciler marks LOADED only on a non-null base FUSION_ID (stored in each
  record type's own FUSION_*_ID column), FAILED on error text, else sweeps to
  FAILED — the `interface_status IS NULL => LOADED` path and the parent→child
  LOADED cascade are removed entirely. Package VALID; check_column_dictionary
  Customers 14/14 PASS; golden byte-identical twice-through; unit suite 27/27.
  Report redeployed to `/Custom/DMT2/Customers/`; standalone RUN_BIP_REPORT
  returns parseable Contract-v1 XML (root DATA_DS, 4 params echoed).
  Live re-gate run 152 (scenario CUSTOMERS_R1_0709, prefix 10035): load ESS
  9719106 SUCCEEDED, but the chained BulkImportJob 9719122 / DataImportJob
  9719131 failed with `batchId is null` — no rows reached the base tables, so the
  fail-closed reconciler correctly marked all 21 rows FAILED (unaccounted=0),
  refusing to fake a pass. The fail-OPEN bug is fixed and proven; the live Rule #1
  GOOD half is blocked on the import Batch ID parameter (see Known Issues).
- 2026-07-09 (Stage E live enablement): reconciler modernized to the shared
  Contract v1 pattern (the Wave-1 blind-review FAIL fix). The private
  `bip_soap_post` UTL_HTTP function was deleted; the reconciler now routes its
  SOAP through the shared `DMT_UTIL_PKG.RUN_BIP_REPORT` (no raw-envelope
  logging — the master Fusion password no longer reaches the log). The
  `EXECUTE IMMEDIATE` sweep over the six child tables was replaced with six
  static UPDATE statements (no dynamic SQL in the package). The report SOAP
  parameter moved from the retired `P_BATCH_ID` to the four Contract v1
  parameters `P_RUN_ID` / `P_LOAD_REQUEST_ID` / `P_IMPORT_ESS_ID` / `P_PREFIX`
  (the report filters on `P_LOAD_REQUEST_ID`). `RECONCILE_BATCH` keeps its
  public 3-argument signature, so `DMT_LOADER_PKG` is unaffected. The BIP data
  model and report were rebuilt to Contract v1 and renamed
  `DMT_CUST_RECON_DM.xdm` / `DMT_CUST_RECON_RPT.xdo` (the `_RECON_` infix), and
  the report was migrated from the frozen `/Custom/DMT/` to
  `/Custom/DMT2/Customers/`. The `DMT_BIP_REPORT_TBL` seed row was repointed to
  `/Custom/DMT2/`. Standalone `RUN_BIP_REPORT` returns parseable Contract v1
  XML (root `DATA_DS`, all four parameters echoed). Package compiles VALID.
  Live E2E run 147 (scenario CUSTOMERS_E_0709, prefix 10030): 21 STG rows
  seeded (2 GOOD + 1 BAD per record type), submitted via
  `DMT_SCHEDULER_PKG.SUBMIT_OBJECTS`, driven to terminal by manual
  `HEARTBEAT_TICK`. Load ESS 9718922 SUCCEEDED, chained import ESS 9718931
  SUCCEEDED; the modernized reconciler ran via the shared transport (HTTP 200,
  no 401). Run reached COMPLETED_ERRORS / work item DONE, all 21 records
  accounted. **The live Rule #1 gate did NOT pass** — see the first Known Issue:
  the interface-tier report returns NULL status/ids on this instance, so GOOD
  parties captured no `FUSION_PARTY_ID` and the BAD party was wrongly LOADED.
  The reconciler modernization (transport, static UPDATEs, Contract v1 params)
  is complete and correct; the remaining base-tier read-back is the tracked
  Contract v1 report rework.
- 2026-07-09: DMT2 Wave-1 OFFLINE port. Converted all 14 HZ STG/TFM tables to
  identity PKs (accepted identity rule; 14 sequences retired). Fixed two ported
  conformance defects, mirroring the Stage D Suppliers fix: the transformer's
  reprocess-time ERROR_TEXT reset (a write-back to staging) and the results
  package's echo of run outcomes onto all 7 STG tables were both removed —
  results now write only the TFM tier. Column-dictionary check: all 14 tables
  PASS. Unit suite 27/27 green. Golden FBDI byte-identical to run 116 after
  normalizing only {RUN_ID} and {PREFIX}.
- Frozen predecessor stack: E2E LOADED confirmed working. 7-record-type pipeline validated.
- 2026-04-02 (frozen stack): Regression test — 38L/0F (O2C pipeline). All customers + AR invoices LOADED. BIP reconciliation confirmed working.
