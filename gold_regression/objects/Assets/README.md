# Assets (gold regression object)

Fixed-asset import via Post Mass Additions. One FBDI zip, two CSVs
(`FaMassAdditions.csv` headers + `FaMassaddDistributions.csv` distributions), and a
**two-stage ESS run**: `loadAndImportData` chains **PrepareMassAdditions** (rows into the
`FA_MASS_ADDITIONS` interface), then a standalone `submitESSJobRequest` runs
**PostMassAdditions** (posts good rows to `FA_ADDITIONS_B`). See `GOLD_README.md` in this
folder for the full proven call, both ParameterLists, discovery query, verify SQL and live
evidence. This file records the durable learnings.

## Status

**GOLD — live-proven 2026-07-19 (prefix 90241; Load/Prepare req 9763379, Post req 9763405).**
Both ESS stages SUCCEEDED. SqlLoader log: 3/3 headers + 3/3 distributions loaded into the
interface, 0 rejected. PrepareMassAdditions log: 14 processed, 1 rejected — the BAD row
(`90241RT-ASSET-BAD1`, invalid category `ZZINVALIDCAT.NOTACATEGORY`) rejected with
*"You must enter a valid category combination."* Good rows → `FA_ADDITIONS_B` confirmed on the
BIP replica for the identical fixture on prior prefixes (e.g. `10057RT-ASSET-G1/G2` = asset ids
567146/567147); no `RT-ASSET-BAD` row has ever reached the base table. This pod's FA BIP
replica lags ~24h, so this run's own prefix had not yet propagated at report time — re-run
`verify.py Assets 9763379 90241` after refresh to promote to a same-prefix base confirmation.

## Object shape

- Type: FBDI, module Financials/Assets. `interfaceDetails` (SOURCE_ERP_OPTIONS_ID, CEMLI_CODE
  `Assets`) = **9**. UCM account `fin/assets/import`. Auth `fin_impl`.
- Stage 1 import job (chained): `/oracle/apps/ess/financials/assets/additions,PrepareMassAdditions`
  (seed stores `;` before the job name; replace the last `;` with `,` for `loadAndImportData`).
  ParameterList = `${BOOK},,NORMAL`.
- Stage 2 downstream job (standalone): `/oracle/apps/ess/financials/assets/additions,PostMassAdditions`.
  ParameterList = one arg, `${BOOK}` (the discovered Book Type Code).
- Two CSVs: header = **423 CSV fields** (CTL lists 425; 3 are EXPRESSION columns that consume no
  field), distribution = **67 CSV fields**. Both join on `MASS_ADDITION_ID` (CSV field 1), which
  is prefix-stamped.

## Durable learnings

- **The load job's SUCCEEDED status is not proof of data.** SqlLoader and PrepareMassAdditions
  run as children; the parent can report SUCCEEDED even if rows were rejected. Always read the
  ESS log (`downloadESSJobExecutionDetails`, `fileType=log`, as `fin_impl`) — the child SqlLoader
  log gives row counts, and the PrepareMassAdditions child log gives the per-record reject reason.
- **Fusion honors a supplied `ASSET_NUMBER`** on Mass Additions, so our prefixed number survives
  to `FA_ADDITIONS_B` and the prefix-LIKE base read is the reconcile anchor. `POSTING_STATUS` and
  `QUEUE_NAME` must both be `POST`.
- **Bad-row design:** an invalid asset category (`ZZINVALIDCAT.NOTACATEGORY`) is a clean,
  deterministic PrepareMassAdditions rejection — the row lands in `FA_MASS_ADDITIONS` with
  `POSTING_STATUS = ERROR` and a real `ERROR_MSG`, and never posts to base. (An invalid expense
  account is an equally valid alternative — the frozen pipeline used that.)
- **Instance prerequisite:** FA Additions approval must be **disabled** on the corporate book;
  otherwise PostMassAdditions only raises an approval request and good rows park at
  `POSTING_STATUS = POST`, never reaching `FA_ADDITIONS_B`.
- **Portability:** the single discovery query mines book + category + location + depreciation
  expense account from one existing posted US CORP asset, so the whole reference set is
  self-consistent and guaranteed valid on the target pod. `DATE_PLACED_IN_SERVICE` must be in an
  open FA period (`2026/01/15` for the current JAN-26 open period); prorate `CAL MONTH`, method
  `STL`, life 120 confirmed valid on the pod.
- **BIP replica lag on FA tables:** direct base/interface reads through the read-only relay can
  trail live by ~a day on this pod. When the ESS logs prove the load, document the lag and re-read
  later rather than failing the run.
