# Finding: Customer child-record (site / site-use) reconciliation gaps in run 179

**Date:** 2026-07-20 (run 179 analysis)
**Object:** Customers (single batch 10063 — NOT the multi-batch sweep bug)
**Status:** party-site-use cause confirmed at source; account-tier cause needs one more pass

Customers loaded 9 of 28 records. The customer object has seven record tiers (parties, locations,
party sites, party site-uses, accounts, account sites, account site-uses). The parent parties
mostly loaded (some held by Fusion CDM duplicate review — a real instance behavior). The failures
are concentrated in the child tiers. Findings per tier:

## 1. Party site-uses — ALL fail — CONFIRMED root cause (source/seed)

`DMT_HZ_PARTY_SITE_USES_TFM_TBL.SITEUSE_ORIG_SYSTEM_REF` is **NULL** for every row. Chain:

- The source STG rows (`DMT_HZ_PARTY_SITE_USES_STG_TBL`) have `SITEUSE_ORIG_SYSTEM` and
  `SITEUSE_ORIG_SYSTEM_REF` both NULL.
- The transform sets the TFM value as `PREFIXED(prefix, s.SITEUSE_ORIG_SYSTEM_REF)`
  (`dmt_cust_transform_pkg.pkb.sql:610`) — prefixing NULL yields NULL.
- The FBDI generator emits that NULL as the site-use `OrigSystemReference`
  (`dmt_cust_fbdi_gen_pkg.pkb.sql:297`) — so Fusion receives an **empty** reference.
- The reconciler matches on `WHERE SITEUSE_ORIG_SYSTEM_REF = r.orig_system_reference`
  (`dmt_cust_results_pkg.pkb.sql:274`) — a NULL key can never match, so every site-use is swept
  to `[RECONCILE_ERROR] ... not confirmed`, whether or not it actually loaded.

**Fix — owner decision:**
- (a) Seed fix: populate `SITEUSE_ORIG_SYSTEM_REF` in `scripts/insert_regression_test_data.py`.
  Makes the regression pass but does not help real EBS data that lacks a per-site-use reference.
- (b) Code fix (more robust, recommended): when the source site-use reference is null, synthesize
  a deterministic one — e.g. `SITE_ORIG_SYSTEM_REFERENCE || '-' || SITE_USE_TYPE` — used
  identically by the FBDI generator and the reconciler so the key round-trips. Fusion needs a
  unique OrigSystemReference per site-use to address/reconcile it; real source systems often do
  not carry one, so DMT should derive it.

## 2. Party sites — mostly work, one good row unexplained

`RT-PSITE-G2` and `RT-PSITE-G3` (good) LOADED with Fusion ids; `RT-PSITE-G1` (good) FAILED with the
same key convention and system (LEG1). Since G2/G3 matched, the key convention is sound, so G1 is
either a per-row data problem or was not returned by the report. Needs a live Fusion query of
`HZ_ORIG_SYS_REFERENCES` / `HZ_PARTY_SITES` for `10063RT-PSITE-G1` to decide. Low priority relative
to the site-use cause.

## 3. Account sites / account site-uses — cascade, root cause not yet pinned

All four account sites (`DMT_HZ_ACCT_SITES_TFM_TBL`) FAILED with no Fusion id. The account
site-uses DO carry populated keys (`10063RT-SITEUSE-G1/G2/G3/BAD1`) yet also all FAILED — i.e. they
cascade from their parent account sites not being confirmed. The account-site failure itself is not
yet root-caused (needs the correct `CUST_SITE_ORIG_SYS_REF` column checked and a live Fusion query
to tell "did not load" from "key mismatch"). Next investigation pass.

## Bystander note

The party-site-use STG table also shows duplicate rows (several identical `RT-PSITE-G2 / BILL_TO`
rows in mixed FAILED/TRANSFORMED status) — the separately-known "duplicate STG rows" regression-data
issue, not a cause of the reconcile failures above.
