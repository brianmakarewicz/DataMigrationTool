# Run 234 — Customers "Party Site Uses" UNACCOUNTED investigation (READ-ONLY)

Run 234, prefix `10115`, object Customers, record type PartySiteUses.
Fusion HZ import batch **5001**, load_request_id **9773467**.
All queries were read-only (live Fusion via `scripts/fusion_bip_query.py --cred fin_impl`;
local DMT via SQLcl `dmt_owner@//localhost:1523/FREEPDB1`). No code changed, no pipeline
or reconciliation was re-run.

## Summary counts

| Outcome | Count | Records |
|---------|-------|---------|
| LOADED (proven in `HZ_PARTY_SITE_USES`, status A) | 2 | 362, 363 |
| FAILED (real Fusion interface reject) | 1 | 364 (INVALID_USE) |
| Held / not-created — parent held for CDM duplicate review | 1 | 361 (BILL_TO on G1) |
| Genuinely absent (nowhere in Fusion) | 0 | — |

**The owner's claim holds: none of the four are genuinely nowhere.** Every one of the
four DMT rows has a matching interface row in `HZ_IMP_PARTYSITEUSES_T` under batch 5001,
and two of them are confirmed in the base table. The reconciler swept all four to
UNACCOUNTED because of a **key-propagation defect plus a report-coverage gap**, not
because the data is missing.

## Per-record outcomes

The four DMT TFM rows (`dmt_hz_party_site_uses_tfm_tbl`, run_id 234). Note the DMT
business key is stored in `SITEUSE_ORIG_SYSTEM_REF` and is **populated** in the TFM
(`10115361-1419` etc.); what is NULL is the companion `SITEUSE_ORIG_SYSTEM` column, and —
critically — the `SITEUSE_ORIG_SYSTEM_REF` value was **never written into Fusion** (it is
NULL on every interface row). Matched to Fusion by the parent `SITE_ORIG_SYSTEM_REFERENCE`
(`10115RT-PSITE-Gn`) + `SITE_USE_TYPE`.

- **Record 361 — BILL_TO on 10115RT-PSITE-G1** | OUTCOME: **NOT-CREATED / held-warning.**
  Interface row `HZ_IMP_PARTYSITEUSES_T` PARTY_SITE_USE_ID 100002550113681,
  `IMPORT_STATUS_CODE = 'W'`. Its parent party `10115RT-CUST-G1` is `W` in
  `HZ_IMP_PARTIES_T` (held for Fusion CDM potential-duplicate review) and its parent site
  `10115RT-PSITE-G1` was never created in `HZ_PARTY_SITES` (only G2/G3 exist). With no base
  parent site, the BILL_TO use is held and did not reach `HZ_PARTY_SITE_USES`. Real Fusion
  signal: interface status `W`; no per-row `HZ_IMP_ERRORS` text (batch-level only).

- **Record 362 — BILL_TO on 10115RT-PSITE-G2** | OUTCOME: **LOADED (site_use_id
  100002550113684).** Interface `IMPORT_STATUS_CODE = 'S'`; confirmed in base
  `HZ_PARTY_SITE_USES` (party_site_use_id 100002550113684, SITE_USE_TYPE BILL_TO,
  STATUS A). This is a genuine successful load the reconciler failed to credit.

- **Record 363 — BILL_TO on 10115RT-PSITE-G3** | OUTCOME: **LOADED (site_use_id
  100002550113683).** Interface `IMPORT_STATUS_CODE = 'S'`; confirmed in base
  `HZ_PARTY_SITE_USES` (party_site_use_id 100002550113683, SITE_USE_TYPE BILL_TO,
  STATUS A). Genuine success the reconciler failed to credit.

- **Record 364 — INVALID_USE on 10115RT-PSITE-G1** | OUTCOME: **FAILED (real Fusion
  reject).** Interface row PARTY_SITE_USE_ID 100002550113682, `IMPORT_STATUS_CODE = 'E'`.
  Batch 5001 `HZ_IMP_ERRORS` on `HZ_IMP_PARTYSITEUSES_T` carries **`HZ_API_INVALID_LOOKUP`**
  (invalid site-use lookup code — `INVALID_USE` is not a valid `SITE_USE_TYPE`). This is the
  intended BAD row; it correctly rejected in the interface and never reached the base. The
  resolved `ERROR_MSG_TEXT` is blank on this instance, so `MESSAGE_NAME`
  (`HZ_API_INVALID_LOOKUP`) is the reportable signal.

(Batch 5001 is reused across many regression prefixes, so the batch-level
`HZ_IMP_ERRORS` counts — 51 `HZ_API_INVALID_LOOKUP`, one per INVALID_USE row across all
prefixes — cannot be attributed to a single record by batch alone. Per-record attribution
comes from the interface row's own `IMPORT_STATUS_CODE` + `SITE_ORIG_SYSTEM_REFERENCE`.)

## Why the reconciler could not match — root cause

Two independent defects, both in the Customers reconciler/BIP report, combine to make
every PartySiteUses row UNACCOUNTED even when it loaded or has a real reject:

### 1. The site-use business key never propagates to Fusion (the null the prompt flagged)
The reconciler matches on `SITEUSE_ORIG_SYSTEM_REF = <report>.orig_system_reference`
(`dmt_cust_results_pkg.pkb.sql` lines 219-223, 281-286). The base-tier BIP query
(`bip/Customers/DMT_CUST_RECON_DM.xdm` lines 31-34) reads the site-use key from
`HZ_ORIG_SYS_REFERENCES` where `owner_table_name='HZ_PARTY_SITE_USES'` and
`orig_system_reference LIKE :P_PREFIX||'%'`.

Live check: `HZ_ORIG_SYS_REFERENCES` has **zero** `HZ_PARTY_SITE_USES` rows for `10115%`
(and zero site-use rows for the batch at all), because the site-use
`SITEUSE_ORIG_SYSTEM_REF` was written NULL into `HZ_IMP_PARTYSITEUSES_T` for every row.
So even the two genuinely-LOADED uses (362, 363) return no base-tier hit — the base tier
can never find a site use, and never populates a `FUSION_ID` for the reconciler to match.
This is a **DMT-side FBDI generation defect**: the PartySiteUses CSV is not carrying the
`SITEUSE_ORIG_SYSTEM` / `SITEUSE_ORIG_SYSTEM_REF` columns into the load, so TCA has no
external reference to register.

### 2. The report has no error-tier query for PartySiteUses
The NOT-LOADED / error tier of the BIP data model (`DMT_CUST_RECON_DM.xdm` lines 59-85)
only covers **Parties** (`HZ_IMP_PARTIES_T`) and **Accounts** (`HZ_IMP_ACCOUNTS_T`). There
is **no** UNION-ALL branch reading `HZ_IMP_PARTYSITEUSES_T`. So a site-use row that failed
(record 364, `E` / `HZ_API_INVALID_LOOKUP`) or is held (record 361, `W`) can never be
surfaced as REJECTED either. It has no base-tier row (defect 1) and no error-tier row
(this gap), so it falls straight through to UNACCOUNTED. This gap exists for
Locations, PartySites, AccountSites and AccountSiteUses too — only Parties and Accounts
are error-covered.

### What the correct match key should be
Two fixes, matching how Parties/Accounts already work:

1. **Make DMT stamp the site-use external reference into the FBDI.** Populate
   `SITEUSE_ORIG_SYSTEM` (a TCA-registered orig_system, e.g. `LEG1`) and
   `SITEUSE_ORIG_SYSTEM_REF` (`10115NNN-1419`) in the HzImpPartySiteUsesT CSV so TCA
   registers them in `HZ_ORIG_SYS_REFERENCES`. Then the existing base-tier query resolves a
   real `party_site_use_id` per DMT key and the LOADED match works with no reconciler
   change. (Same root cause family as the historical `PARTY_ORIG_SYSTEM='DMT'` rejection —
   an orig-system/reference propagation problem.)
2. **Add a PartySiteUses (and the other three missing record types) error-tier branch** to
   `DMT_CUST_RECON_DM.xdm`, keyed on `load_request_id = :P_LOAD_REQUEST_ID`, emitting
   `SITE_ORIG_SYSTEM_REFERENCE || '/' || SITE_USE_TYPE` (or the propagated
   `SITEUSE_ORIG_SYSTEM_REF` once fix 1 lands) as `ORIG_SYSTEM_REFERENCE` and the row's
   `IMPORT_STATUS_CODE` + batch `MESSAGE_NAME` as `ERROR_MESSAGE`, so `W`/`E` rows report
   instead of sweeping to UNACCOUNTED.

Interim reconciliation key while fix 1 is pending: match on the parent
`SITE_ORIG_SYSTEM_REFERENCE` + `SITE_USE_TYPE` pair (both present on the interface row and
on the TFM row), since the site-use's own reference is unavailable in Fusion.

## Fix roadmap

1. FBDI generator (`db/packages/dmt_cust_fbdi_gen_pkg`): emit `SITEUSE_ORIG_SYSTEM` +
   `SITEUSE_ORIG_SYSTEM_REF` (and confirm the same for AccountSiteUses) into the
   PartySiteUses CSV, using a TCA-registered orig_system. This is the primary fix — it
   makes LOADED site uses (like 362/363) reconcilable and self-registers the base key.
2. BIP report (`DMT_CUST_RECON_DM.xdm`): add error-tier UNION-ALL branches for
   PartySiteUses, Locations, PartySites, AccountSites, AccountSiteUses so `W`/`E` interface
   rows are reported as FAILED with the real `MESSAGE_NAME` (e.g. `HZ_API_INVALID_LOOKUP`)
   rather than dropped to UNACCOUNTED.
3. Regression data: the parent party `10115RT-CUST-G1` sits in CDM potential-duplicate
   review (`W`), which cascades to record 361. That is a data-quality / dedup-config issue
   separate from these two code defects.

## Evidence appendix (all read-only)

- DMT TFM rows: `dmt_hz_party_site_uses_tfm_tbl` run_id 234 — 4 rows, all `TFM_STATUS =
  UNACCOUNTED`, `SITEUSE_ORIG_SYSTEM_REF` populated (`10115361-1419`..`10115364-1419`),
  `SITEUSE_ORIG_SYSTEM` NULL, `FUSION_PARTY_SITE_USE_ID` NULL, `BATCH_ID` 5001.
- Work queue: `dmt_work_queue_tbl` run_id 234 Customers — `WORK_STATUS = FAILED`,
  load/import ESS job ids NULL (never captured); error_message: "4 record(s) unaccounted …
  (9 loaded, 15 errored)."
- Fusion `HZ_ORIG_SYS_REFERENCES` LIKE '10115%': Parties G2/G3, Locations G1/G2/G3,
  PartySites G2/G3, Accounts G2/G3 — **no HZ_PARTY_SITE_USES rows at all.**
- Fusion `HZ_IMP_PARTIES_T` 10115RT: G1=`W`, G2=`S`, G3=`S`, BAD1=`E`, batch 5001,
  load_request_id 9773467.
- Fusion `HZ_IMP_PARTYSITEUSES_T` batch 5001, 10115RT sites: PSITE-G1/BILL_TO=`W`
  (100002550113681), PSITE-G1/INVALID_USE=`E` (100002550113682), PSITE-G2/BILL_TO=`S`
  (100002550113684), PSITE-G3/BILL_TO=`S` (100002550113683); `SITEUSE_ORIG_SYSTEM_REF` NULL
  on all.
- Fusion base `HZ_PARTY_SITE_USES`: 100002550113683 (BILL_TO, A) and 100002550113684
  (BILL_TO, A) present; the `W` and `E` ids are absent.
- Fusion `HZ_IMP_ERRORS` batch 5001 `HZ_IMP_PARTYSITEUSES_T`: `HZ_API_INVALID_LOOKUP` x51,
  `HZ_IMP_ACTION_MISMATCH` x3 (batch-level, resolved `ERROR_MSG_TEXT` blank).
