# Customers

## Status
DMT2 offline slice proven 2026-07-09 (unit suite 27/27, golden byte-identical to
run 116). Reconciler rebuilt fail-CLOSED / two-tier 2026-07-09 (obj/customers-rule1)
— no more fail-open. Live Rule #1 gate PROVEN 2026-07-11: 20/20 customers reached the Fusion base
tables (`hz_cust_accounts`). The earlier `batchId is null` crash — the positional
`NEW,N,<run_id>` ParameterList was never mapped to the bulk import's internal
Batch_Id — is RESOLVED by passing `BulkImportJob` a four-value ParameterList that
auto-creates the HZ import batch (see "RESOLVED 2026-07-11" in Known Issues). Frozen predecessor stack claimed "E2E LOADED"
but that was a FALSE PASS: the frozen DMT_HZ_PARTIES_TFM held 18 LOADED / 0 real
FUSION_PARTY_ID — its fail-open reconciler masked the same batchId-null crash.

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
- ESS Job: /oracle/apps/ess/cdm/foundation/bulkImport;BulkImportJob
- ParameterList (RESOLVED 2026-07-11): four values —
  `<Batch ID>,<Batch Name>,Customer and Consumer,<Source System>` — which
  auto-creates the `HZ_IMP_BATCH_SUMMARY` import batch the bulk import then consumes.
  The Batch ID is the user's uploaded `BATCH_ID` (run id only as NVL fallback); the
  Source System comes from the user's data, never hard-coded `'DMT'`. An empty Batch
  Name loads 0 rows. The earlier positional `NEW,N,<run_id>` form did NOT work — the
  bulk import never mapped slot 3 to its internal `Batch_Id`. Proven live 2026-07-11:
  20/20 customers to `hz_cust_accounts`.
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

## Duplicate-hold root cause & mapping (2026-07-15)

Investigated why regression Customer GOOD rows never reach the HZ base tables.
Read-only Fusion queries via `scripts/fusion_bip_query.py --cred fin_impl`. Findings:

### The real hold reason — the source system, not the party name
The party rows that sat un-created were stamped with `PARTY_ORIG_SYSTEM = 'DMT'`.
`DMT` is **NOT a registered Trading Community source system** in Fusion. The customer
bulk import therefore rejects every one of those parties with import error
**`HZ_INVALID_ORIG_SYSTEM`** on token `PARTY_ORIG_SYSTEM` (found in `HZ_IMP_ERRORS`
for the Fusion surrogate batch `300000048330164`, whose batch name `300000048330160`
maps to our run 160). With no party created in `HZ_PARTIES`, the accounts then fail
with the invalid-party-reference cascade the run log shows (`HZ_IMP_INVAL_PARTY_REF`).

Evidence that `DMT` is unregistered while `LEG1` is valid:
```
-- HZ_ORIG_SYSTEMS_B: DMT returns NO ROW; LEG1 and CSV are active + TCA-enabled
SELECT orig_system, status, enable_for_tca_flag, orig_system_type
FROM   HZ_ORIG_SYSTEMS_B WHERE orig_system IN ('DMT','LEG1','CSV');
-- LEG1 -> A, Y, SPOKE      CSV -> A, Y, SPOKE      DMT -> (no row)
```
This is a **data/mapping issue, not a DQM match-rule config we cannot change.** The
source system must be one Fusion has registered and enabled for TCA. `LEG1` already is.

### The proven good-customer pattern (LEG1)
Earlier regression runs that used `PARTY_ORIG_SYSTEM = 'LEG1'` created cleanly and
reached the BASE tables. Captured driving values:
```
-- HZ_ORIG_SYS_REFERENCES: LEG1 parties + accounts DID create (status 'A')
OREF 10015RT-CUST-G2 -> HZ_PARTIES        party_id 100002539164902
OREF 10015RT-ACCT-G2 -> HZ_CUST_ACCOUNTS  cust_account_id 100002539164981
-- HZ_PARTIES: party_name '10015Fnargle Systems', party_type ORGANIZATION, status A
-- HZ_CUST_ACCOUNTS: account_number '10015RTG002', status A
```
Pattern that creates cleanly: `PARTY_ORIG_SYSTEM='LEG1'`, `PARTY_TYPE='ORGANIZATION'`,
the run prefix prepended to both the org name and the account number
(`10015Fnargle Systems` / `10015RTG002`) so the name matches nothing and escapes any
duplicate hold. `RT-CUST-G2` (Fnargle) and `RT-CUST-G3` (Zorptell) both created this
way; there is NO un-prefixed exact-name party in `HZ_PARTIES`, so the prefix-in-name
already guarantees uniqueness — no DQM duplicate is lurking.

### Note on `RT-CUST-G1` / "Blorptech Widgets"
`RT-CUST-G1` has never created under ANY prefix, and NO existing `%BLORPTECH%` /
`%WIDGET%` party exists in `HZ_PARTIES`. So G1 is **not** blocked by a name-duplicate
match. Its absence is because "Blorptech Widgets" is a recently changed seed name and
every recent run used the broken `DMT` source system — G1 simply has not had a good
`LEG1` run yet. Nothing suggests a name change is required.

### The current seed already uses LEG1 — verify at run time, not in code
`scripts/insert_regression_test_data.py` (party insert ~line 546) already sets
`PARTY_ORIG_SYSTEM = 'LEG1'`. The `'DMT'`-stamped interface rows are from OLDER runs
(batches 147-160). The transformer (`DMT_CUST_TRANSFORM_PKG`) and FBDI generator
(`DMT_CUST_FBDI_GEN_PKG`) both carry `*_ORIG_SYSTEM` through unchanged — no `'DMT'`
hardcode. So the code path is already correct for LEG1.

**Proposed change: none to code or seed for the orig-system.** The fix is to run the
current LEG1 seed live end-to-end and confirm all GOOD parties/accounts reach the base
tables. If any future data uses a source system other than one of the TCA-registered
values, add a pipeline pre-check (or a `DMT_LOOKUP` list) that validates
`*_ORIG_SYSTEM` against `HZ_ORIG_SYSTEMS_B` (status='A', enable_for_tca_flag='Y')
before generation, so an unregistered source system fails fast with a clear error
instead of silently holding at the interface.

### Reusable discovery queries (read-only, fin_impl)
```sql
-- Is a source system registered + usable for customer import?
SELECT orig_system, status, enable_for_tca_flag, orig_system_type
FROM   HZ_ORIG_SYSTEMS_B WHERE orig_system = :sys;

-- Did our parties/accounts reach the BASE tables?
SELECT orig_system_reference, owner_table_name, owner_table_id
FROM   HZ_ORIG_SYS_REFERENCES
WHERE  orig_system = 'LEG1' AND status = 'A'
AND    orig_system_reference LIKE '%RT-CUST%';

-- Real import errors for a batch (surrogate batch id from HZ_IMP_BATCH_SUMMARY):
SELECT interface_table_name, message_name, token1_value
FROM   HZ_IMP_ERRORS WHERE batch_id = :fusion_batch_id;

-- Map our run id to the Fusion surrogate batch it produced:
SELECT batch_id, batch_name, batch_object, batch_status, original_system
FROM   HZ_IMP_BATCH_SUMMARY WHERE batch_name LIKE '%'||:run_id||'%';
```

### Uncertainty
The `HZ_INVALID_ORIG_SYSTEM` evidence comes from batch `300000048330164`, which
also carries unrelated leftover rows (RELSHIPS/CONTACTS/CLASSIFICS tables our pipeline
never loads), so that batch is not a clean isolation of our run. The isolation that
IS clean: `DMT` returns no row in `HZ_ORIG_SYSTEMS_B` while `LEG1` does, and LEG1-
stamped `RT-CUST` refs demonstrably created in the base while DMT-stamped ones did
not. Confidence in "unregistered source system = the hold cause" is high; the live
LEG1 re-run is the confirming test still to do.

## Known Issues
- **RESOLVED 2026-07-11 — `batchId is null` is fixed; 20/20 customers reached the
  HZ base tables (`hz_cust_accounts`).** The customer bulk import needs an
  `HZ_IMP_BATCH_SUMMARY` batch to consume; the positional `NEW,N,<run_id>` form
  never created one (the bulk import ignored slot 3). The fix is to pass
  `BulkImportJob` a **four-value ParameterList** — `<Batch ID>,<Batch Name>,Customer
  and Consumer,<Source System>` — which **auto-creates** the import batch. No
  separate batch-summary mechanism is needed. Source refinement: the Batch ID is the
  user's uploaded `BATCH_ID` (they pre-create the batch in Fusion), carried through
  the transform — the run id is only an NVL fallback when the user supplies none; the
  Source System likewise comes from the user's data, never hard-coded `'DMT'`. An
  **empty Batch Name loads 0 rows.** Proven live 2026-07-11: 20/20 to
  `hz_cust_accounts`. Frozen-stack proof of the id source: ConversionTool commit
  `6c8e38c`. (Moved here from the coding-standards section of `docs/DMT_DESIGN.html`,
  2026-07-14 — it is a Customers resolved issue, not a general standard; the general
  rule "always supply a traceable batch id" stays in the design doc.)
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
- **RESOLVED 2026-07-11 (was OPEN) — the diagnosis below pinned the root cause; the
  fix is the four-value ParameterList in the RESOLVED item above. Retained as the
  investigation record. The customer bulk import previously failed with
  batch id null (2026-07-09 re-gate,
  run 160 / scenario CUSTOMERS_R1B_0709 / prefix 10043, branch
  fix/paramlist-batch-id).** The ParameterList fix now sends `NEW,N,160` (slot 3
  = the run-id batch id) — CONFIRMED in the live loadAndImportData envelope
  (`<erp:ParameterList>NEW,N,160</erp:ParameterList>`) and in ESS
  `request_property` (`submit.argument1=NEW`, `submit.argument2=N`,
  `submit.argument3=160`). The FBDI load ESS job SUCCEEDS (request 9719501) and
  lands all 3 parties in `HZ_IMP_PARTIES_T` with `BATCH_ID=160`,
  `LOAD_REQUEST_ID=9719501`. The chained `BulkImportJob` (9719517) runs, but the
  bulk import does **NOT** map positional `submit.argument3` to its internal
  `Batch_Id` parameter — `Batch_Id` stays empty (`''`) — and its child
  `DataImportJob` (9719518) is submitted with **batch id null** (the child
  request name is literally `ESS submitted for batch id null`). Nothing moves to
  the HZ base tables; `HZ_IMP_ERRORS` has 0 rows for batch 160 and
  `HZ_IMP_BATCH_SUMMARY` has NO row for 160.
  - **Why the slot fix is not enough:** the customer bulk import keys on a Fusion
    `HZ_IMP_BATCH_SUMMARY.BATCH_ID` (a surrogate like `300000…`) that the
    interface-load step is supposed to create. DMT's FBDI stamps `BATCH_ID=160`
    (our run id) on the interface rows but never creates the batch-summary row,
    so the bulk import has no batch to import. Every `DataImportJob` in this
    instance's ENTIRE history (21 of 21) is in the error state — the customer
    bulk import has never once succeeded here, including under the frozen stack.
  - **Consequence:** the two-tier reconciler correctly marks all 21 rows FAILED
    with `[RECONCILE_ERROR]` (unaccounted=0, run terminal `COMPLETED_ERRORS`,
    work item DONE) — it does **not** fake a pass. The live Rule #1 GOOD half
    (LOADED with real base ids) still cannot be shown.
  - **Remaining work (the real fix):** create the HZ import batch (a
    `HZ_IMP_BATCH_SUMMARY` row / batch name) before/at load so the bulk import
    has a batch id to consume, and pass THAT Fusion batch id — not the raw
    positional slot — to `BulkImportJob`. This is a mechanism change, not a
    ParameterList slot change, and is the next Customers live item.
- Related, upstream: the customer **validator** (`DMT_CUST_VALIDATOR_PKG`) does
  not reject the BAD party's invalid `PARTY_TYPE` before generation — RT-CUST-BAD1
  reaches STG_STATUS = TRANSFORMED with no error and flows into the FBDI zip. A
  stronger pre-validation would have failed it before the ESS load. Tracked
  separately.

## History
- 2026-07-11 (batch-id RESOLVED — live Rule #1 GOOD half proven): replaced the
  positional `NEW,N,<run_id>` ParameterList with the four-value
  `<Batch ID>,<Batch Name>,Customer and Consumer,<Source System>` form, which
  auto-creates the `HZ_IMP_BATCH_SUMMARY` batch the customer bulk import consumes.
  Batch ID sourced from the user's uploaded `BATCH_ID` (run id NVL fallback), Source
  System from the user's data. Proven live: 20/20 customers reached
  `hz_cust_accounts`; an empty Batch Name loads 0. Frozen-stack id-source proof:
  ConversionTool commit `6c8e38c`. The general "always supply a traceable batch id"
  rule stays in `docs/DMT_DESIGN.html`; this Customers-specific resolution moved here
  from that doc's coding-standards section on 2026-07-14.
- 2026-07-09 (fix/paramlist-batch-id — batch-id ParameterList standard):
  investigated the batchId-null crash per the ESS-param-discovery rule. Frozen
  stack finding: the frozen ATP loadAndImportData envelope log and ESS
  request_property both prove the frozen stack sent only `NEW,N` for Customers
  (NOT even `NEW,N,<run_id>` — the `,<run_id>` default lived on a different
  submit path); the frozen `objects/Customers/README.md` itself flagged the
  ParameterList as "UNKNOWN — needs verification". The frozen "E2E LOADED" claim
  was a FALSE PASS: frozen `DMT_HZ_PARTIES_TFM` = 18 LOADED / 0 real
  `FUSION_PARTY_ID` (fail-open reconciler masking the same crash). Batch id was
  never random in the frozen stack — where present it was the run id. Fix: added
  a Customers branch to the `DMT_LOADER_PKG` ParameterList override so it sends
  `NEW,N,<run_id>` (slot 3 = the object-per-run FBDI batch id = run id = the
  BATCH_ID the transformer already stamps on every HZ interface row and the
  reconciler joins on). Package VALID; unit 27/27; golden byte-identical
  twice-through. Live re-gate run 160 (scenario CUSTOMERS_R1B_0709, prefix
  10043): the ParameterList `NEW,N,160` was sent and accepted
  (`submit.argument3=160`), but the bulk import does NOT consume slot 3 as its
  `Batch_Id` — the child DataImportJob 9719518 still submits with batch id null
  (request name `ESS submitted for batch id null`), so no rows reached the HZ
  base tables and the fail-closed reconciler correctly marked all 21 FAILED
  (unaccounted=0). **Rule #1 GOOD half still blocked**, now on a deeper cause:
  the customer bulk import needs an `HZ_IMP_BATCH_SUMMARY` batch created at load
  time, not a positional ParameterList value (see Known Issues). Codified the
  batch-id standard as a red PROPOSED rule in docs/DMT_DESIGN.html section 7.
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
