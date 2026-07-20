# Finding: Customer account-site reconciliation failure in run 179

**Date:** 2026-07-20 (run 179 analysis; run 180 in progress will re-confirm)
**Object:** Customers - the account-site tier (`DMT_HZ_ACCT_SITES_TFM_TBL`)
**Scope:** This is the account-*sites* issue explicitly left out of PR #207 (which fixed the
site-*uses*). See `docs/FINDINGS_customer_sites_reconcile.md` section 3.
**Run 179:** prefix `10063`, scenario 179, final status FAILED.

## Root cause (one sentence)

The account sites genuinely never loaded into Fusion - they are stuck in the interface table
`HZ_IMP_ACCTSITES_T` at status `W` (held) or `E` (rejected), never `S` (created) - and the
reconciler cannot report *why* because the Customers reconciliation BIP report has no error-tier
block for account sites, so their held/rejected rows produce no report row at all and fall through
to the generic "not confirmed" sweep. This is a **real non-load (case b)**, not a key mismatch and
not a pure parent cascade.

## Evidence

### 1. The key round-trips correctly - this is NOT the site-use bug

The account-site reference column is named and populated consistently end to end:

- Transform writes `CUST_SITE_ORIG_SYS_REF = PREFIXED(prefix, s.CUST_SITE_ORIG_SYS_REF)`
  (`db/packages/dmt_cust_transform_pkg.pkb.sql:884`) - non-null, e.g. `10063RT-ASITE-G2`.
- FBDI generator emits that value as field 5 of `HzImpAcctSitesT.csv`
  (`db/packages/dmt_cust_fbdi_gen_pkg.pkb.sql:408`).
- Reconciler matches on `WHERE CUST_SITE_ORIG_SYS_REF = r.orig_system_reference`
  (`db/packages/dmt_cust_results_pkg.pkb.sql:288`).
- The Fusion interface table's own key column is literally `CUST_SITE_ORIG_SYS_REF` and it holds
  the exact values DMT sent (live query below). So there is no null key and no name mismatch -
  unlike the party-site-use bug.

### 2. The account sites reached Fusion's interface table but never the base table

Live query of the account-site interface table (`fusion_bip_query.py`, cred fin_impl):

    CUST_SITE_ORIG_SYS_REF | CUST_ORIG_SYSTEM_REFERENCE | IMPORT_STATUS_CODE
    10063RT-ASITE-G1       | 10063RT-ACCT-G1            | W
    10063RT-ASITE-G2       | 10063RT-ACCT-G2            | W
    10063RT-ASITE-G3       | 10063RT-ACCT-G3            | E
    10063RT-ASITE-BAD1     | 10063RT-ACCT-NONEXIST      | W

(`SELECT ... FROM hz_imp_acctsites_t WHERE batch_id=10063`)

None are `S`. Confirming the base table is empty for them: `hz_orig_sys_references` for prefix
`10063%` contains rows only for `HZ_PARTIES`, `HZ_LOCATIONS`, `HZ_PARTY_SITES`, and
`HZ_CUST_ACCOUNTS` (G2/G3) - **no `HZ_CUST_ACCT_SITES_ALL` row at all**. And
`hz_cust_acct_sites_all` filtered to the two loaded account ids (100002536597489,
100002547631227) returns **zero rows**. So the account sites did not create base records - the
reconciler's "no base id" verdict is factually correct; it just can't say why.

### 3. Why they held/rejected (the batch-level reason)

`HZ_IMP_ERRORS` for batch 10063 shows exactly one real error on the account-site interface table:

    HZ_IMP_ACCTSITES_T | HZ_IMP_INVAL_VALUE_COMPARE | 1

That is the `E` row (ASITE-G3). The three `W` rows are held, not errored. The batch as a whole is
riddled with `HZ_IMP_ACTION_MISMATCH` on parties/accounts/locations/party-sites - the classic
"row is flagged INSERT but the party/account already exists from a prior demo run" behavior. When
parent tiers are held/mismatched, Fusion holds the dependent account sites (`W`).

### 4. This is not a clean cascade either

ASITE-G2's parent account (ACCT-G2) and parent party-site (PSITE-G2) both **LOADED**
(DMT_HZ_ACCOUNTS_TFM_TBL and DMT_HZ_PARTY_SITES_TFM_TBL, run 179, status LOADED with Fusion ids),
yet ASITE-G2 is still `W`. So "parent didn't load" does not fully explain it - the account-site
import genuinely held at the interface. The account site-uses (`DMT_HZ_ACCT_SITE_USES_TFM_TBL`) in
turn all FAILED because their parent account sites were never confirmed - that layer IS a true
cascade off this one.

### 5. The reporting gap that hides all of this

The Customers reconciliation data model (`bip/Customers/DMT_CUST_RECON_DM.xdm`) has:
- a BASE tier (positive proof) with a block for **all seven** record types (lines 16-49), but
- a NOT-LOADED / error tier with blocks for **only `Parties` and `Accounts`** (lines 59-87).

There is no error-tier block reading `HZ_IMP_ACCTSITES_T` (nor party-sites, party-site-uses,
locations, account-site-uses). So a held/rejected account site emits neither a base id nor an
error message; the reconciler (`PARSE_AND_UPDATE`) sees nothing for it and `SWEEP_UNACCOUNTED`
stamps the generic `[RECONCILE_ERROR] ... not confirmed`. The failure is real, but the operator is
told nothing actionable.

## Proposed fix

Two parts. The first makes the failure *reportable* (correctness, Rule #1); the second addresses
the underlying re-run data condition.

### Fix A (primary - reportable errors): extend the reconcile report's error tier to all child tiers

In `bip/Customers/DMT_CUST_RECON_DM.xdm`, add NOT-LOADED tier `UNION ALL` blocks for the five
missing interface tables, mirroring the existing `Parties`/`Accounts` blocks - most importantly
account sites, reading `HZ_IMP_ACCTSITES_T` keyed on `s.cust_site_orig_sys_ref`, emitting
`record_type='AccountSites'`, a NULL fusion_id, and an error_message that is NULL when
`import_status_code='S'` else text describing the `W` (held/warning) or `E` (rejected) status plus
the batch's `HZ_IMP_ERRORS.message_name` values for `interface_table_name='HZ_IMP_ACCTSITES_T'`.
Filter on `s.load_request_id = :P_LOAD_REQUEST_ID`.

Add matching blocks for `HZ_IMP_LOCATIONS_T`, `HZ_IMP_PARTYSITES_T`, `HZ_IMP_PARTYSITEUSES_T`, and
`HZ_IMP_ACCTSITEUSES_T`. The reconciler (`dmt_cust_results_pkg`) **already has FAILED-branch
handling for every record type** (lines 316-363) and keys account sites on `CUST_SITE_ORIG_SYS_REF`
(line 353), matching the interface column exactly - so no PL/SQL change is needed for the error
text to land on the right row. After this, ASITE-G1/G2/BAD1 read `... interface status 'W'
(held/warning)` and ASITE-G3 reads `... interface status 'E' (rejected by import) -- batch
messages: HZ_IMP_INVAL_VALUE_COMPARE`, instead of the opaque generic sweep. Deploy as a new version
to the DMT2 BIP folder (never overwrite - feedback_bip_version_not_overwrite).

### Fix B (the underlying non-load): eliminate the re-run ACTION_MISMATCH / held condition

The held/mismatch state comes from re-loading records that already exist in the demo pod from
prior runs (create-only action against pre-existing parties/accounts). Options, in order:

1. Use fresh, unique test data per run so parties/accounts/sites do not already exist - the prefix
   stamps ORIG_SYSTEM_REFERENCE, but verify the *natural* keys (party number, account number,
   party-site number) also vary by prefix, else Fusion still matches and holds.
2. Investigate the single genuine reject `HZ_IMP_INVAL_VALUE_COMPARE` on ASITE-G3 - a data problem
   in the account-site fixture (an attribute value failing Fusion's compare validation),
   independent of the re-run holds. Fix that fixture value.
3. Cross-check against the gold artifact: `gold_regression/objects/Customers/GOLD_README.md`
   documents a proven-live account-site load outside the pipeline - align the fixture's
   account-site fields and load action with that known-good recipe.

Fix A is the required correctness change (a held/rejected row must be reportable, per Rule #1).
Fix B is what actually gets GOOD account sites to LOADED.

## Run 180 confirmation

A fresh run 180 (prefix `10064`) is in progress. Once it reconciles, re-run the two live queries
above against `batch_id=10064` to confirm the same interface-held pattern on clean data, and - if
Fix A is deployed first - to confirm the account-site rows now carry the real `W`/`E` interface
status instead of the generic reconcile sweep.
