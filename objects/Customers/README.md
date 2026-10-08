# Customers

## Status
2026-09-30 (backlog #133, Contract v1 finish): all seven HZ tiers are wired,
reconcile, and report honest per-record outcomes. Verified against regression run
142 (prefix 93222): the two account-site tiers came back 0 LOADED / 4 FAILED each,
and that is an HONEST Fusion rejection, not a wiring bug. Each failed record carries
a real Trading Community import error read from the live `HZ_IMP_*_T` interface
tables — interface status 'W' (held) or 'E' (rejected) plus the genuine error
lookup codes `HZ_IMP_INVAL_VALUE_COMPARE` (account sites / uses) and
`HZ_IMP_INVAL_PARTY_REF` / `HZ_IMP_ACTION_MISMATCH` (parents). The G1 subtree fails
because its party failed upstream; the BAD row points at a nonexistent account on
purpose; and even G2/G3 — whose parent Account and PartySite both LOADED and whose
linkage references are correctly stamped by the transform — are rejected by Fusion's
own value-compare validation. No tier is unwired or mis-generated, so no code change:
per the mission, a real rejection is a correct outcome, not something to "fix" by
editing data. The `DMT_BIP_REPORT_TBL` Customers row is already converged onto the
DMT2 catalog (`/Custom/DMT2/Customers/DMT_CUST_RECON_V6_*` since 2026-10-07, CONTRACT_VERSION = 1,
FUSION_ID_COLUMN + RECON_KEY_SQL populated) and the V2 report is deployed additively
at `/Custom/DMT2/Customers/` (the frozen `/Custom/DMT/` is left untouched); the seed
is idempotent (re-run twice clean, 0 invalid objects).

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
  The Batch ID is the run prefix followed by the user's uploaded `BATCH_ID` (owner
  decision 2026-10-07; see "Fusion batch id and recon V6" below); the
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
- BIP Data Model/Report: `bip/Customers/DMT_CUST_RECON_V6_DM.xdm` + `DMT_CUST_RECON_V6_RPT.xdo`
  (deploy target `/Custom/DMT2/Customers/`; deployed by `scripts/deploy_recon_bip_reports.py Customers`).
  V6 is the live one the `DMT_BIP_REPORT_TBL` seed row points at (migration
  `db/migrations/2026-10-07_customers_recon_v6_registry.sql`). V6 selects every base tier by
  `REQUEST_ID = :P_FUSION_BATCH_ID` (the batch id the load sent) instead of V5's prefix match on the
  orig-system reference; everything below is unchanged from V5. An INTERFACE row is returned as
  ERROR only when it has its OWN Fusion error: its own `HZ_IMP_ERRORS` rows joined on
  `error_id`+`batch_id`, with the full `FND_NEW_MESSAGES` text (tokens substituted). A row Fusion
  held or rejected with no error of its own is not returned, so the shared sweep marks it
  UNACCOUNTED. V4 (deployed first on 2026-10-07, kept in the catalog) is the same query but still
  appended the composed fallback `(no message text found in FND_NEW_MESSAGES)` when Fusion had no
  text for an error's MESSAGE_NAME; V5 returns just the real MESSAGE_NAME then. V3 (2026-10-06) instead composed a sentence from import status codes for such rows
  ("Not created: Fusion left this row at import status W ...") and listed parent rows Fusion had
  only held as if they had errored; that text was stamped `[FUSION_ERROR]` with no real Fusion
  error behind it, which the design document forbids. V2 built the message as a batch-wide
  LISTAGG of every error name for the interface table (run 236 findings R1,
  `docs/findings/run236_Customers_Items_unaccounted.md`). V3, V2 and the original
  `DMT_CUST_RECON_DM.xdm` / `DMT_CUST_RECON_RPT.xdo` stay deployed alongside (never overwritten).
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
(Superseded 2026-10-07: G1 is held because the BAD party site use INVALID_USE sits on
`RT-PSITE-G1`, and a failed party site use holds its whole party. See "Cross-grain error
propagation" below; run 257's `RT-CUST-XU` reproduced it on a fresh name.)
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

## Party Site Uses reconciliation — interim key + deferred forward-fix (2026-07-21)

Run 234 (prefix 10115) left all four Party Site Use records UNACCOUNTED even though
two loaded, one failed for a real reason, and one was held. Two reconciler/report
defects, both now addressed for run-234 accounting (branch
`fix/customers-siteuse-error-tier`). Full evidence: `docs/findings/run234_Customers.md`.

### What was fixed
1. **Base-tier match now uses an interim key.** The site use's own external reference
   (`SITEUSE_ORIG_SYSTEM_REF`) is written NULL into Fusion, so
   `HZ_ORIG_SYS_REFERENCES` has no `HZ_PARTY_SITE_USES` row to match — the old base
   query could never resolve even for genuinely loaded uses. The BIP report and the
   reconciler now match a loaded site use by its **parent site's registered reference
   plus the site_use_type** (`SITE_ORIG_SYSTEM_REFERENCE || '/' || SITE_USE_TYPE`).
   Verified unique per prefix live (10115: `G2/BILL_TO`→100002550113684,
   `G3/BILL_TO`→100002550113683). Both columns are present on every TFM row and every
   interface row, so there is no wrong-row risk.
2. **Error tier added for Party Site Uses.** The BIP report had no error-tier branch
   for `HZ_IMP_PARTYSITEUSES_T`, so a failed (`E`) or held (`W`) site use fell straight
   through to UNACCOUNTED. Added a row-precise branch keyed on the interface row's own
   `IMPORT_STATUS_CODE` (filtered by `LOAD_REQUEST_ID`), emitting the same interim key
   and the batch-level `HZ_IMP_ERRORS` `MESSAGE_NAME` list as context. Record 364
   (`INVALID_USE`, status `E`) now reports FAILED with the real `HZ_API_INVALID_LOOKUP`
   batch signal; record 361 (status `W`, parent held for CDM duplicate review) reports
   its real held/warning status. Neither is fabricated — each is the row's own live
   Fusion status.

**A BIP catalog re-deploy is required.** The `DMT_CUST_RECON_DM.xdm` change is committed
in the repo but NOT deployed to live Fusion BIP by this work. Per project rule, BIP
objects are never overwritten — the human must do a versioned deploy of the updated data
model to `/Custom/DMT2/Customers/`.

### DEFERRED forward-fix (not in this branch) — FBDI generator NULL site-use reference
The root cause of the NULL is upstream of the FBDI generator: the transformer
(`DMT_CUST_TRANSFORM_PKG`) leaves `SITEUSE_ORIG_SYSTEM` and `SITEUSE_ORIG_SYSTEM_REF`
NULL on the TFM row. The generator (`dmt_cust_fbdi_gen_pkg`, `gen_party_site_uses_csv`)
already writes both columns positionally from the TFM, so the CSV carries NULL. The
proper forward-fix is to have the transformer populate `SITEUSE_ORIG_SYSTEM` (a
TCA-registered orig system such as `LEG1`) and `SITEUSE_ORIG_SYSTEM_REF` so TCA
registers the site use in `HZ_ORIG_SYS_REFERENCES`; then the base-tier match can key on
the site use's own reference and the interim parent-ref key can be retired. That change
touches the transformer and risks altering the golden FBDI output, so it is **deferred**
to its own branch rather than bundled into this reconciler fix. Do the same review for
`AccountSiteUses` (`CUST_SITEUSE_ORIG_SYSTEM` / `CUST_SITEUSE_ORIG_SYS_REF`).

### Follow-up: error tier for the other deep record types
The BIP report still lacks an error-tier branch for Locations, PartySites, AccountSites
and AccountSiteUses (only Parties, Accounts and now PartySiteUses are error-covered). A
`W`/`E` interface row for those types would still sweep to UNACCOUNTED. Adding those
branches is low-risk (same shape as the PartySiteUses branch) but was left out of this
focused fix; track as a follow-up.

## Cross-grain error propagation (2026-10-07, backlog #168 / #193)

The customer bulk import does not write an error on every row it refuses. When one row fails it
leaves related rows at import status `W` (held) with no `HZ_IMP_ERRORS` row of their own. Design
section 5 ("Whole-document rejection carries the real error to every grain") says such a row must
land FAILED quoting the real error of the row that held it, in the shared format
`[FUSION_ERROR] Rejected with document: <grain> <key>: <real msg>`
(`DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR`). `DMT_CUST_RESULTS_PKG.PROPAGATE_DOCUMENT_ERRORS` does this
after the per-row apply and before the shared UNACCOUNTED sweep.

**Which rows Fusion holds, and in which direction, was read from Fusion, not assumed.** All
`HZ_IMP_*_T` rows of the 44 DMT loads in import batch 5001 (load request ids 9971978 to
10070462, runs 236 and 238 included) were compared with the status of the rows they reference:

| A row with its own error on... | ...holds (Fusion evidence) | Never holds |
|---|---|---|
| a party site use | its WHOLE party: the party, every party site, party site use, account, account site and account site use of that party (43 of 43 parties that had a failed site use and no error of their own were held; no party was ever held without one) | the location (it loads) |
| a party | its whole tree (2 of 2) | the location |
| a party site | its party site uses and the account sites on it (4 of 4) | the party |
| an account | its account sites, and so their uses (86 of 86 not created) | the party (84 parties S beside a failed account) |
| an account site | its account site uses (86 of 86 held) | its party site (86 S), its account (2 S) |

So the "held parts" of runs 236/238 come from two real errors: the INVALID_USE party site use on
`RT-PSITE-G1` holds the whole G1 customer (party, party site, BILL_TO use, account, account
site G1, account site BAD1 that sits on `RT-PSITE-G1`, and both account site uses on account
site G1), and the SET_CODE rejection of account sites G2/G3 holds their account site uses. The
earlier explanation of the G1 hold as a CDM duplicate review was wrong: G1 is the only customer
that carries the bad party site use. Note the direction: an account-site error does **not** hold
the account above it, so a held account only quotes a party-level or party-site-use error.

Rule details: sources are rows FAILED with their own `[FUSION_ERROR]` text (never a quote, so
quotes never chain); targets are the other rows in the source's scope that Fusion received
(`FBDI_CSV_ID` set) and that are not LOADED; the quote is appended once (idempotent); a held row
with no failed row in its scope stays for the UNACCOUNTED sweep. Static SQL, one SELECT plus one
FORALL UPDATE per TFM table, work-item scoped, no COMMIT.

**Runs 236 / 238.** Their rows are terminal (FAILED with the old V2/V3 text) and the sanctioned
rerun (`DMT_QUEUE_PKG.RERUN_RUN`) only re-opens UNACCOUNTED rows, so it cannot change them, and
they are not reset. A read-only dry run fetched the deployed V5 report from live Fusion through
`DMT_RECON_CONTRACT_PKG.FETCH_ROWS` and applied the apply and propagation rules in memory: in
both runs the 10 rows V5 leaves UNACCOUNTED become FAILED quoting a real error (11 LOADED,
7 FAILED with their own error, 10 FAILED with their document, 0 UNACCOUNTED).

**Regression scenario** `RegressionTest2610071942` (id 347) adds three cross-grain customers,
each with one defect: `RT-CUST-XG` (account site SET_CODE is a business-unit name), `RT-CUST-XU`
(one party site use with an invalid type) and `RT-CUST-XP` (invalid party type, full tree under
it). GOOD account sites and account site uses now send set code `CUSTSITE`, so G2/G3 load end
to end. Expected outcomes are listed in `scripts/regression_scenario.json`.
`RegressionTest2610071932` (id 346) is the first mint of this change: it sent no SET_CODE on the
GOOD account site uses and Fusion rejected G2/G3 with `HZ_IMP_INVAL_VALUE_COMPARE` (run 256;
its expected outcomes record that). Scenarios 343 and 345 (`RegressionTest2610071921` /
`...1927`) are empty: their inserts lost the DB connection; they were left as they are.

**Proof run 257** (prefix 93313, scenario `RegressionTest2610071942`, `STANDALONE:Customers`):
22 LOADED, 28 FAILED, 0 UNACCOUNTED; all 50 listed rows met their expected outcome.
G2, G3 and the XG party / party site / use / account load untouched; XG's account site fails
with its own SET_CODE error and its account site use quotes it; every XU row quotes the XU
INVALID_USE error (the party too, which confirms on a fresh name that a failed party site use
holds the whole party); every XP row quotes the party's `HZ_IMP_PARTY_NAME_ERROR`; all
locations except BAD1 load. A second reconcile pass (in a rolled-back transaction) changed no
status and no ERROR_TEXT byte (`PROPAGATE_DOCUMENT_ERRORS`: 20 pairs, 0 rows updated), and the
sanctioned `RERUN_RUN` re-opened nothing. Click-through `dmt_console_verify.py --run-id 257
--cemlis Customers`: PASS.

## Fusion batch id and recon V6 (2026-10-07, backlog #238)

**Owner decision 2026-10-07.** The batch id DMT sends the customer bulk import is the run prefix
followed by the source `BATCH_ID`: prefix 93335 and source batch 5001 give `933355001`. With
`USE_PREFIX = N` (cutover, NULL prefix) the source batch is sent unchanged. When the source has no
batch id, DMT sends the prefix followed by the **work-queue id** (one Customers work item makes the
loads of a run, and the work-queue id never repeats inside one database; outside a work item, as in
the offline golden test, the run id is used). The transform stamps this value as the TFM `BATCH_ID`
(`DMT_CUST_TRANSFORM_PKG`), so the generator writes it into every HZ CSV and `RUN_CUSTOMERS` sends it
in the ParameterList. The source `BATCH_ID` still decides the partitioning: the prefix is the same
for the whole run, so one source batch is exactly one Fusion batch and one load.

**Why.** The regression seed always uses batch 5001 (`CUST_BATCH_ID` in
`scripts/insert_regression_test_data.py`), and Fusion copies the batch id into `REQUEST_ID` on every
HZ base row, so every earlier test run carried 5001 and the report could only find its rows by
searching on the prefix. That breaks the design rule that reports find rows by Fusion job or batch
id (design document section 5).

**What Fusion stamps (verified 2026-10-07, read-only queries).** All Fusion batch columns are
`NUMBER(18)`: `HZ_IMP_BATCH_SUMMARY.BATCH_ID`, `HZ_IMP_*_T.BATCH_ID`, `HZ_IMP_ERRORS.BATCH_ID`, and
`REQUEST_ID` on `HZ_PARTIES`, `HZ_LOCATIONS`, `HZ_PARTY_SITES`, `HZ_PARTY_SITE_USES`,
`HZ_CUST_ACCOUNTS`, `HZ_CUST_ACCT_SITES_ALL`, `HZ_CUST_SITE_USES_ALL` and `HZ_ORIG_SYS_REFERENCES`.
A 5-digit prefix leaves 13 digits for the source batch id. Every one of those base tables carries
the batch id in its own `REQUEST_ID` (run 257: every base row = 5001; run 279: 22 base rows =
933355001, exactly the 22 LOADED rows), so V6 selects each tier directly and never goes through a
parent.

**Report V6.** Base rows: `<base table>.REQUEST_ID = TO_NUMBER(:P_FUSION_BATCH_ID)`, joined to
`HZ_ORIG_SYS_REFERENCES` only to build the RECORD_KEY (party site uses use their parent party
site's reference + `SITE_USE_TYPE`). Interface and error rows: `LOAD_REQUEST_ID =
:P_LOAD_REQUEST_ID`, unchanged. No `LIKE` anywhere. `P_FUSION_BATCH_ID` is a seventh, optional
report parameter: `DMT_RECON_CONTRACT_PKG.FETCH_ROWS` sends it only when the caller passes
`p_fusion_batch_id`, so no other object's report call changed. `DMT_CUST_RESULTS_PKG` resolves the
batch id with `RESOLVE_SENT_BATCH_ID`: the TFM `BATCH_ID` of the most recently generated customer
FBDI of the work item (the highest parties `FBDI_CSV_ID`). `RUN_CUSTOMERS` generates, loads and
reconciles one batch at a time, so that is the batch of the load being reconciled. Cross-grain
propagation (`PROPAGATE_DOCUMENT_ERRORS`) is unchanged.

**Proof run 279** (prefix 93335, scenario `RegressionTest2610071942`, `STANDALONE:Customers`): the
ParameterList sent `933355001,Batch ID 933355001 LEG1,CUSTOMER,LEG1`; Fusion created batch
933355001 and stamped it on the 7 interface parties rows of load 10075855 and on all 22 base rows.
Outcomes match run 257 exactly: 22 LOADED, 8 FAILED with their own error, 20 FAILED quoting their
document, 0 UNACCOUNTED; all 50 listed rows met their expected outcome. A reconcile-only rerun
(`DMT_QUEUE_WORKER_PKG.RECONCILE_VIA_REGISTRY` with the recorded ids) left all 50 TFM rows
byte-identical (same MD5 over status, Fusion ids, batch, work item and ERROR_TEXT; 0 rows updated).
`dmt_regression_run.py`: PASS with the same 6 REST spot-check review items as run 257.
`dmt_console_verify.py --run-id 279 --cemlis Customers`: PASS.

## Known Issues
- **Several source batches in one work item (not exercised by the regression).** The reconciler
  takes the batch of the most recently generated customer FBDI. That is right for the inline
  reconcile of each batch and for a reconcile-only rerun of the last batch, but if the LAST batch's
  load failed, a reconcile-only rerun would use the queue row's ids (the previous batch) with the
  last batch's id. The rerun only touches UNACCOUNTED rows, and the inline reconcile is correct.
- **Keyset paging past one page (backlog #414).** `DMT_UTIL_PKG.RUN_BIP_REPORT` splits the parameter
  string on `~`, and Customers RECORD_KEYs contain `~`, so a second page's `P_AFTER_KEY` is cut
  short. Only a Customers load with more than `BIP_CHUNK_SIZE` (5,000) report rows is affected.
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

## Table-name vs FBDI-tab audit (backlog #90, 2026-10-01)

Backlog #90 asks whether every STG/TFM table name mirrors the FBDI CSV tab
(record type) it loads. The rule is "one object = one FBDI zip = one tab per
record type". Customers is the **Trading Community (TCA) bulk import: one zip
carrying SEVEN CSVs**, all submitted under one `BulkImportJob` ESS job.

**The mapping (from `DMT_CUST_FBDI_GEN_PKG` + the seven HzImp*.ctl):**

| FBDI tab / CSV | Interface table | Source STG table | Source TFM table | Verdict |
|---|---|---|---|---|
| HzImpPartiesT.csv | HZ_IMP_PARTIES_T | DMT_HZ_PARTIES_STG_TBL | DMT_HZ_PARTIES_TFM_TBL | ALIGNED |
| HzImpLocationsT.csv | HZ_IMP_LOCATIONS_T | DMT_HZ_LOCATIONS_STG_TBL | DMT_HZ_LOCATIONS_TFM_TBL | ALIGNED |
| HzImpPartySitesT.csv | HZ_IMP_PARTYSITES_T | DMT_HZ_PARTY_SITES_STG_TBL | DMT_HZ_PARTY_SITES_TFM_TBL | ALIGNED |
| HzImpPartySiteUsesT.csv | HZ_IMP_PARTYSITEUSES_T | DMT_HZ_PARTY_SITE_USES_STG_TBL | DMT_HZ_PARTY_SITE_USES_TFM_TBL | ALIGNED |
| HzImpAccountsT.csv | HZ_IMP_ACCOUNTS_T | DMT_HZ_ACCOUNTS_STG_TBL | DMT_HZ_ACCOUNTS_TFM_TBL | ALIGNED |
| HzImpAcctSitesT.csv | HZ_IMP_ACCTSITES_T | DMT_HZ_ACCT_SITES_STG_TBL | DMT_HZ_ACCT_SITES_TFM_TBL | ALIGNED |
| HzImpAcctSiteUsesT.csv | HZ_IMP_ACCTSITEUSES_T | DMT_HZ_ACCT_SITE_USES_STG_TBL | DMT_HZ_ACCT_SITE_USES_TFM_TBL | ALIGNED |

All seven record types map 1:1 to their own STG/TFM pair, and each DMT name is
the `DMT_` + Fusion-interface-root form (`HZ_PARTIES` ↔ HZ_IMP_PARTIES_T,
`HZ_ACCT_SITES` ↔ HZ_IMP_ACCTSITES_T, etc. — `ACCT` for "Account" is the only
abbreviation, consistent across the three account tables). No misalignment.

**Findings:**
1. **Fully ALIGNED** — every table already mirrors its tab; no physical rename
   needed and no NOT-MODELED gap (all seven TCA import tabs are modeled).
2. **No spec-header fix required** — `DMT_CUST_FBDI_GEN_PKG` already lists the
   seven CSVs with their correct `HZ_IMP_*_T` interface tables.
