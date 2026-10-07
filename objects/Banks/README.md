# Banks

## Overview
Cash Management bank records representing financial institutions. This is the top level of a three-level hierarchy: Bank > Branch > Account.

## Load Method
REST API
- Endpoint: `POST /fscmRestApi/resources/11.13.18.05/cashBanks`
- Pipeline: REST pipeline (CEMLI_CODE `CashBanks`, runner `DMT_CE_BANK_RUNNER_PKG`)

## Parent/Child
- Parent: None (standalone, top of hierarchy)
- Linkage: N/A (parent to BankBranches via SOURCE_GROUP_ID)

## Staging Tables
- STG: `DMT_CE_BANK_STG_TBL`
- TFM: `DMT_CE_BANK_TFM_TBL`

## Key Columns
- BANK_NAME
- BANK_NUMBER
- COUNTRY_CODE

## Reconciliation
Base-table BIP report (`DMT_CEBANK_RECON_RPT`), not the REST response. A bank is
marked LOADED only when it is found in `CE_BANKS_V`, with `FUSION_BANK_PARTY_ID`
set to the real `BANK_PARTY_ID`. A bank whose POST returned a real Fusion error
and is not found in the base view is marked FAILED on that error.

## Status
BUILT — REST pipeline. The runner transforms, promotes STAGED TFM rows to
GENERATED, POSTs each bank to the `cashBanks` resource, then reconciles against
`CE_BANKS_V`. The old FBL flat-file generator was retired (backlog #39).

## Run prefix (2026-10-06, owner decision)
Like every other DMT data object, CashBanks applies the run prefix to its user-facing
unique keys (`DMT_CE_BANK_TRANSFORM_PKG`), so each run creates its own records instead of
colliding with earlier runs (run 236's GOOD bank failed only because `Bank of America`
already existed: CE-660205).
- Bank: `BANK_NAME` (Fusion limit 360) → `93300Bank of America`.
- Branch: the parent `BANK_NAME` FK carries the same prefix; the branch name is unique
  within that new bank, so it is unchanged.
- Account: the parent `BANK_NAME` FK and `ACCOUNT_NAME` (limit 80) carry the prefix.
- A key that cannot carry the full prefix within its limit is not truncated; the row is
  recorded FAILED with a `[TRANSFORM_ERROR]` naming the limit.
The base-table report is unchanged: it is driven by the TFM names, so it matches on the
same prefixed values.

## Children of a parent that was not created (revised 2026-10-07)
A branch whose parent bank was not created (or an account whose parent branch was not
created) is never sent to Fusion. Fusion therefore returns no error for it, so no error text
is written: the row stays GENERATED and the shared sweep marks it UNACCOUNTED.
PR #592 (2026-10-06) briefly stamped such rows `[PARENT_FAILED] ... parent bank "<name>" was
not created in Fusion ...` and marked them FAILED. That is a composed sentence, not a Fusion
error for the row, which the design document forbids, so it was removed. The design
document's whole-document rule allows a child to quote its parent's real Fusion error in the
shared format `[FUSION_ERROR] Rejected with document: <grain> <key>: <real msg>`; that waits
for the shared formatter `DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR` (separate PR).
