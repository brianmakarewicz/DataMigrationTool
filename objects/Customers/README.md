# Customers

## Status
DMT2 offline slice proven 2026-07-09 (unit suite 27/27, golden byte-identical to
run 116). Live E2E gate deferred to the serialized live phase. Frozen predecessor
stack: E2E LOADED.

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
- **Reconciliation is interface-tier only and cannot yet prove Rule #1 (OPEN,
  found by the 2026-07-09 live gate).** The Customers BIP report reads only the
  interface table `HZ_IMP_PARTIES_T`, filtered by `LOAD_REQUEST_ID`. On the
  demo instance (fa-esew-dev28), after a *successful* bulk import (both the load
  ESS job and the chained import ESS job return SUCCEEDED) the interface table
  still shows `INTERFACE_STATUS` and `IMPORT_STATUS` NULL and `PARTY_ID` NULL
  for every row. Consequences observed on live run 147 (prefix 10030):
  - GOOD parties are marked LOADED but with a NULL `FUSION_PARTY_ID` — no
    positive base-table id was captured.
  - The BAD party (RT-CUST-BAD1, PARTY_TYPE = INVALID_TYPE) is wrongly marked
    LOADED, because the NULL interface status is read as success and no
    `HZ_IMP_ERRORS` row surfaced through the interface-tier query.
  This is a genuine reconciliation gap, not a data-quality failure: the load
  and import both succeeded and the rows are present in `HZ_IMP_PARTIES_T`. The
  fix is a two-tier Contract v1 report that positively confirms each GOOD row
  against the HZ **base** tables (real `HZ_PARTIES.PARTY_ID` etc.) and reads
  `HZ_IMP_ERRORS` for the BAD row's rejection — the same base-tier read-back
  the GLBalances report already does and the same "Contract v1 report rework"
  tracked item the Suppliers site-id backfill and Projects interface-tier
  children await. Until then the Customers live Rule #1 gate does NOT pass.
- Related, upstream of the reconciler: the customer **validator**
  (`DMT_CUST_VALIDATOR_PKG`) does not reject the BAD party's invalid
  `PARTY_TYPE` before generation — RT-CUST-BAD1 reached STG_STATUS = TRANSFORMED
  with no error and flowed into the FBDI zip. A stronger pre-validation would
  have failed it before the ESS load. Tracked separately from this reconciler
  work.
- Child record types are reconciled by cascade, not by their own Fusion base
  id. Only the party record type is read back from the BIP report. The six
  child record types (locations, party sites, party site uses, accounts,
  account sites, account site uses) are marked LOADED because their parent
  reached LOADED — their FUSION_* id columns are NOT populated. A child row that
  cannot be linked to a LOADED parent is marked FAILED with a
  `[RECONCILE_ERROR]` note (never silently LOADED). Capturing each child's own
  Fusion id also lands with the Contract v1 report rework.

## History
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
