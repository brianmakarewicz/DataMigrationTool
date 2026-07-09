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
- Results/Reconciliation: `db/packages/dmt_cust_results_pkg.*`
- BIP Data Model/Report: `bip/Customers/` (deploy target `/Custom/DMT2/`)
- Golden inputs: `test/golden/inputs/Customer*_input.csv`; golden zip `test/fbdi_zips/Customers_116.zip`
- Unit test: `test/unit/test_customers.sql`; golden compare: `test/golden/test_customers_golden.sh`

## Reference Files
None in this folder.

## Known Issues
None currently.

## History
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
