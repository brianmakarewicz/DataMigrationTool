# Misc Receipts (On Hand Qty)

## Overview
On-hand inventory quantities migrated into Fusion via miscellaneous receiving receipts.
Dual-table CEMLI: receipt headers + receipt transactions.

## Load Method
FBDI
- Template: RcvHeadersInterface.xlsm
- Interface Tables: RCV_HEADERS_INTERFACE, RCV_TRANSACTIONS_INTERFACE
- Pipeline: Standard FBDI pipeline via run_one_object_type

## Parent/Child
- Parent: Items (items must exist in Fusion before receipts reference them)
- Linkage: ITEM_NUMBER in transactions references imported items

## Staging Tables (the live Inventory-Transactions pipeline)
The generator writes the INV_TRX tables, NOT the (now-dropped) RCV tables.
- STG (Transactions): `DMT_INV_TRX_STG_TBL`
- STG (Lots): `DMT_INV_TRX_LOTS_STG_TBL`
- STG (Serials): `DMT_INV_TRX_SERIALS_STG_TBL`
- TFM (Transactions): `DMT_INV_TRX_TFM_TBL`
- TFM (Lots): `DMT_INV_TRX_LOTS_TFM_TBL`
- TFM (Serials): `DMT_INV_TRX_SERIALS_TFM_TBL`

The orphan `DMT_RCV_HEADERS_*` / `DMT_RCV_TRANSACTIONS_*` STG/TFM tables and
their sequences were dropped in backlog #25
(`db/migrations/2026-10-02_drop_orphan_rcv_tables.sql`).

## Code References
- Validator: `packages/validators/dmt_misc_receipt_validator_pkg`
- Transformer: `packages/transformers/dmt_misc_receipt_transform_pkg`
- FBDI Generator: `packages/generators/fbdi/receiving/dmt_misc_receipt_fbdi_gen_pkg`
  - Outputs 2 CSVs in single ZIP: `RcvHeadersInterface.csv` + `RcvTransactionsInterface.csv`
- Results/Reconciliation: `packages/reconciliation/dmt_misc_receipt_results_pkg`
- Loader wiring: `dmt_loader_pkg.RUN_MISC_RECEIPTS` -> `run_one_object_type('MiscReceipts')`

## Pipeline Configuration
- CEMLI Code: `MiscReceipts`
- Orchestration: P2P (runs last, after Requisitions)
- UCM Account: prc/receiving/import
- ESS Job: RcvTxnProcessorJob (ERP_INTERFACE_OPTIONS_ID=32)
- ParameterList: `NULL`
- Auth User: calvin.roth

## Reference Files
- `RcvHeadersInterface.ctl` -- CTL file for RCV_HEADERS_INTERFACE loader
- `RcvTransactionsInterface.ctl` -- CTL file for RCV_TRANSACTIONS_INTERFACE loader

## BIP Artifacts
- Reconciliation data model (registered): `bip/MiscReceipts/DMT_INV_TRX_RECON_V2_DM.xdm`
  + `DMT_INV_TRX_RECON_V2_RPT.xdo`, deployed to `/Custom/DMT2/MiscReceipts/` alongside V1
  (`DMT_INV_TRX_RECON_DM`, never overwritten). `bip/MiscReceipts/query.sql` mirrors V2.
- Legacy: `MISC_RECEIPT_DM.xdm` / `MISC_RECEIPT_RPT.xdo` (not registered).

## Reconciliation by Fusion job id (recon V2, 2026-10-07, backlog #262)

V2 finds rows only by the work item's Fusion load job id:

- Posted transactions: `INV_MATERIAL_TXNS.LOAD_REQUEST_ID` = the load job.
- Rejections: `INV_TRANSACTIONS_INTERFACE.LOAD_REQUEST_ID` = the load job and
  `PROCESS_FLAG = 3` (the real error is inline on the row).
- Serials: `INV_SERIAL_NUMBERS` whose `LAST_TRANSACTION_ID` is a transaction of that load.

Why the load id and not the import id: the work item records the `PollTMEssJob` request it
submits as its import id, but Fusion stamps `REQUEST_ID` on the transactions with the
`SingleTMEssJob` child that `PollTMEssJob` spawns (run 272: recorded 10075703, rows stamped
10075704, parent 10075703). `PollTMEssJob` also processes every pending interface row on the
pod, not only this load's. `LOAD_REQUEST_ID` is kept on both the posted and the rejected rows
and is exact per work item. V1 selected rows by the `'DMT-' || run id` transaction reference;
that is gone, and `SOURCE_LINE_ID` / the serial number are only the `RECORD_KEY`.

Proof run 272 (prefix 93328, scenario RegressionTest2610071920, STANDALONE:MiscReceipts):
load 10075692 is the `LOAD_REQUEST_ID` on all four transactions in Fusion. Same result as run
238: three receipts LOADED (with the lot and both serials), FAKE-ITEM-REGRESSION-BAD FAILED
with Fusion's own `INV_INVALID_ITEM` error, 0 UNACCOUNTED, quantity 11 staged = 10 loaded + 1
failed (the rows carry no cost). A reconcile-only rerun left every TFM row byte-identical;
regression harness 0 failures (its only review items are the pre-existing "no REST lookup
configured" notes for this object); Playwright click-through PASS.

## Rejected transaction carries its error to its lots and serials (2026-10-08, backlog #167)

A transaction and its lot/serial detail stand or fall together. When Fusion rejects a
transaction (PROCESS_FLAG 3, real error inline on the interface row, a lot/serial defect
included), `DMT_MISC_RECEIPT_RESULTS_PKG.PROPAGATE_DOCUMENT_ERRORS` marks every not-LOADED
lot and serial of that transaction FAILED quoting it:
`[FUSION_ERROR] Rejected with document: transaction <SOURCE_LINE_ID>: <real error>`.
Children link to the parent by the parent's TFM id (backlog #552, 2026-10-09): the transform
reads the staged link once (child STG `SOURCE_ID` = parent `STG_SEQUENCE_ID`) and stamps the
parent transaction's `TFM_SEQUENCE_ID` into the lot's and the serial's `SOURCE_LINE_ID` (new
column on the serials TFM table). The generator, the lot LOADED cascade and this document
roll-up all join `child.SOURCE_LINE_ID = parent.TFM_SEQUENCE_ID`; before, the lot cascade
joined on the lot/serial interface number and the roll-up and generator on the STG link.
Serials of a rejected transaction used to end UNACCOUNTED.
Regression cross-grain rows (scenario RegressionTest2610081756): `RT-MR-XG-SER-BAD`
(AS88000 + serial DMT-SER-XG-001..002) and `RT-MR-XG-LOT-BAD` (RA-100-4935-LOT + lot
DMT-REG-LOT-XG), both on the nonexistent subinventory `XGNOSUB`. Proof run 315 (prefix
93370): both transactions FAILED with `INV_INSTP_CNTXT_SYS_DEFINED ... SUBINVENTORY_CODE`,
the lot and serial FAILED quoting it, GOOD rows LOADED, 0 UNACCOUNTED.

**Child-grain-only defects (backlog #551, 2026-10-09).** Scenario RegressionTest261009080330
adds two documents whose transaction is valid and only the detail is wrong:
`RT-MR-XL-LOT-BAD` (qty-3 receipt of RA-100-4935-LOT, its one lot `DMT-REG-LOT-XL` carries 5) and
`RT-MR-XS-SER-BAD` (qty-2 receipt of AS88000, serial range DMT-SER-XS-001..003). Fusion writes the
detail error inline on the transaction row. Proof run 372 (prefix 93415, STANDALONE:Items +
MiscReceipts): the transactions FAILED with `INV_LOTSR_LOT_QTY` and
`INV_MATRX_INVALID_SERIAL_RANGE`, the lot and serial FAILED quoting them, every GOOD row (lot and
serial included) LOADED, all 14 listed rows met, 0 UNACCOUNTED, harness PASS.

## A failed load fails every record type of the zip (2026-10-09, backlog #633)

One MiscReceipts zip carries the transaction, lot and serial CSVs and goes through one load
job. When `RUN_MISC_RECEIPTS` sees that load job fail, it calls
`DMT_MISC_RECEIPT_FBDI_GEN_PKG.FAIL_GENERATED_ROWS`, which sets every GENERATED transaction,
lot and serial row of the run FAILED with the same `[LOAD_ERROR]` text. Before, only the
transaction rows were marked and the lots and serials stayed GENERATED until the sweep made
them UNACCOUNTED. A load failure cannot honestly be produced from data on this pod (bad rows
make the load end WARNING, not ERROR), so the proof is the rolled-back unit test
`test/unit/test_misc_receipt_load_failure.sql` (synthetic runs and rows only).

## Status
WIRED INTO PIPELINE. Code built. Now in P2P scheduler sequence (last position).
Needs first E2E test with real data.

## History
- 2026-03-25: Added to scope for On Hand Qty migration via Misc Receipts.
- Code built: validator, transformer, FBDI gen, reconciliation.
- Wired into dmt_loader_pkg (RUN_MISC_RECEIPTS) and scheduler dispatch.
- 2026-05-21: Added to P2P scheduler sequence (was only in individual dispatch).

## Known-good receive-against items & mapping (2026-07-15)

### Real Fusion state (queried read-only as scm_impl on the demo instance)

The on-hand table in this Fusion release is `INV_ONHAND_QUANTITIES_DETAIL`
(NOT `INV_ON_HAND_QUANTITIES_DETAIL` — that name does not exist and returns ORA-00942).
Serial detail is `INV_SERIAL_NUMBERS`, which keys on `CURRENT_ORGANIZATION_ID` and
`CURRENT_SUBINVENTORY_CODE` (NOT `ORGANIZATION_ID`/`SUBINVENTORY_CODE`).

Verified known-good, currently in stock in the Seattle inventory org:

| Kind | Item number | Org code | Subinventory | Control code | Lot / Serial in stock | UOM |
|---|---|---|---|---|---|---|
| Lot-controlled | `RA-100-4935-LOT` | `001` (Seattle) | `Stores` | lot_control_code=2 | real lots e.g. `RA100000`..`RA100004` (qty 2 each), plus our `DMT-REG-LOT-001` (qty 3, posted many times) | `zzu` = "Ea" |
| Serial-controlled | `AS88000` | `001` (Seattle) | `Stores` | serial_number_control_code=5 (at receipt) | real serials e.g. `SN10034` (status 3), plus our `DMT-REG-SER-001`/`002` (status 3 = already in stores) | `zzu` = "Ea" |
| Plain | `AS55001` | `001` (Seattle) | `Stores` | none | n/a | `zzu` = "Ea" |

All three items' primary UOM code is `zzu`, whose unit name is "Ea". Our seed sends the
UOM as the literal `'Each'`. That string is accepted for the lot and plain items (their
receipts post), so UOM is not the blocker here.

### What our seed uses today (scripts/insert_regression_test_data.py, section 33)

- Plain: `AS55001`, org name `Seattle`, subinv `Stores`, qty 5, UOM `Each`. Posts fine.
- Lot: `RA-100-4935-LOT`, `Seattle`/`Stores`, qty 3, child lot number literal
  `DMT-REG-LOT-001`. Posts fine and repeatedly (a lot receipt can keep adding quantity
  to the same lot number — lot numbers are not unique per unit).
- Serial: `AS88000`, `Seattle`/`Stores`, qty 2, child serials literal `DMT-REG-SER-001`
  through `DMT-REG-SER-002`. THIS IS THE FAILURE.

### Root cause of the run-155 unaccounted serial rows

`DMT-REG-SER-001` and `DMT-REG-SER-002` already exist in Fusion `INV_SERIAL_NUMBERS`
at `CURRENT_STATUS = 3` (resides in stores) from earlier regression runs. A Miscellaneous
Receipt of a serial-controlled item CREATES new serial numbers, and a serial number must
be globally unique. Re-receiving a serial that is already on hand is rejected by Fusion
as a duplicate serial. The transformer (`dmt_misc_receipt_transform_pkg`) passes
`FM_SERIAL_NUMBER`/`TO_SERIAL_NUMBER` straight through from staging; it does NOT make
the serial values unique per run. The numeric run prefix disambiguates STG/TFM row
identity but does not change the serial number VALUE, so every run after the first
re-sends the same two serials and they collide. That is the 2 unaccounted records.

The lot case does NOT have this problem because a lot number is a batch label, not a
unique unit id — repeated receipts against `DMT-REG-LOT-001` just add quantity (confirmed:
that lot shows multiple qty-3 rows on hand from prior runs).

### Precise test-data change needed (propose only — do not edit the seed here)

Make each regression run's serial numbers UNIQUE per run so they can be received as NEW.
The item/org/subinventory are already correct (`AS88000` / `Seattle` / `Stores`).
Change only the serial VALUES in `DMT_INV_TRX_SERIALS_STG_TBL`:

- Replace the fixed literals `'DMT-REG-SER-001'` / `'DMT-REG-SER-002'` with values that
  embed the run/prefix (or scenario id / a sequence), e.g.
  `FM_SERIAL_NUMBER = 'DMT-SER-' || :prefix || '-001'` and
  `TO_SERIAL_NUMBER = 'DMT-SER-' || :prefix || '-002'`.
- Keep quantity 2, and keep the FM..TO range width equal to the quantity (2 serials).
- No change needed for the lot child (`DMT-REG-LOT-001` is fine to reuse) or for the
  plain `AS55001` row.

After that change, the serial receipt creates two brand-new serials each run and posts
to inventory base (`INV_SERIAL_NUMBERS` at status 3 and an on-hand increase for
`AS88000` in `001`/`Stores`), satisfying Rule #1 for the serial case.

Uncertainty: this was diagnosed entirely from read-only Fusion state plus the seed/
transformer code; it was not re-run through the pipeline (per task constraints). It is
possible AS88000 also needs the serial-generation/receipt setup left as-is (it is
`serial_number_control_code=5`, "at receipt", which is the correct code for receiving
new serials, so this should be fine). If a run still leaves the serial rows unaccounted
after making serials unique, next check the ESS/reconciliation log for the specific
Fusion error rather than assuming duplicate serial.

### Reusable read-only queries (scm_impl)

Lot on-hand joined to item/org (real known-good):
```
SELECT p.organization_code ORGC, e.item_number ITEMNO, d.subinventory_code SUBINV,
       d.lot_number LOT, d.primary_transaction_quantity QTY
FROM INV_ONHAND_QUANTITIES_DETAIL d
JOIN INV_ORG_PARAMETERS p ON p.organization_id = d.organization_id
JOIN EGP_SYSTEM_ITEMS_B e  ON e.inventory_item_id = d.inventory_item_id
                          AND e.organization_id  = d.organization_id
WHERE p.organization_code='001' AND d.lot_number IS NOT NULL
  AND d.primary_transaction_quantity>0 AND ROWNUM<=8
```

Serials already in stock (would collide with a new receipt) — note CURRENT_* columns:
```
SELECT e.item_number ITEMNO, s.current_subinventory_code SUBINV,
       s.serial_number SERIAL, s.current_status STAT
FROM INV_SERIAL_NUMBERS s
JOIN INV_ORG_PARAMETERS p ON p.organization_id = s.current_organization_id
JOIN EGP_SYSTEM_ITEMS_B e  ON e.inventory_item_id = s.inventory_item_id
                          AND e.organization_id  = s.current_organization_id
WHERE p.organization_code='001' AND e.item_number='AS88000'
  AND s.current_status=3 AND ROWNUM<=8
```

Item control codes / UOM:
```
SELECT e.item_number ITEMNO, e.lot_control_code LOTCTL,
       e.serial_number_control_code SERCTL, e.primary_uom_code UOM
FROM EGP_SYSTEM_ITEMS_B e
JOIN INV_ORG_PARAMETERS p ON p.organization_id=e.organization_id
WHERE p.organization_code='001'
  AND e.item_number IN ('RA-100-4935-LOT','AS88000','AS55001') AND ROWNUM<=8
```

## Table-name vs FBDI-tab audit (backlog #90, 2026-10-01)

Backlog #90 asks whether every STG/TFM table name mirrors the FBDI CSV tab
(record type) it loads. The rule is "one object = one FBDI zip = one tab per
record type". MiscReceipts (on-hand quantity) is the **Inventory Transactions
FBDI: one zip carrying 1–3 CSVs** — the transaction, plus lot and serial tabs
emitted only when lot/serial rows exist. All three are submitted under one load.

**The mapping (from `DMT_MISC_RECEIPT_FBDI_GEN_PKG` + the Inv*Interface.ctl):**

| FBDI tab / CSV | Interface table | Source STG table | Source TFM table | Verdict |
|---|---|---|---|---|
| InvTransactionsInterface.csv | INV_TRANSACTIONS_INTERFACE | DMT_INV_TRX_STG_TBL | DMT_INV_TRX_TFM_TBL | NAME-SHORTENED (TRX = Transactions), model correct |
| InvTransactionLotsInterface.csv | INV_TRANSACTIONS_LOTS_INTERFACE | DMT_INV_TRX_LOTS_STG_TBL | DMT_INV_TRX_LOTS_TFM_TBL | NAME-SHORTENED, model correct |
| InvSerialNumbersInterface.csv | INV_SERIAL_NUMBERS_INTERFACE | DMT_INV_TRX_SERIALS_STG_TBL | DMT_INV_TRX_SERIALS_TFM_TBL | NAME-SHORTENED, model correct |

Each DMT table maps 1:1 to its tab; the only drift is the abbreviation `TRX`
for "Transactions" and `SERIALS` for "Serial Numbers" — same record type,
shortened label. No wrong-record-type defect.

**Findings:**
1. **DOCUMENTED FINDING — stale Receiving (`RCV_*`) artifacts in this object.**
   `objects/MiscReceipts/` ships two CTL files — `RcvHeadersInterface.ctl` and
   `RcvTransactionsInterface.ctl` — and the schema carries `DMT_RCV_HEADERS_*`
   and `DMT_RCV_TRANSACTIONS_*` STG/TFM tables. These belong to a *Receiving*
   (RCV) import path, NOT the Inventory-Transactions path the live generator
   actually uses. The catalog (db/seed/dmt_cemli_catalog_tbl.sql) confirms
   MiscReceipts reads the `INV_TRX` pipeline tables and notes "the orphaned
   `RCV_*` tables are a sweep candidate". So the Rcv* CTLs and DMT_RCV_* tables
   are leftover/unused relative to the modeled path. This is flagged as a finding
   (not renamed, not deleted under this doc-only item) — a future sweep should
   either wire the RCV path or retire the orphaned CTLs and tables.

   **Update (backlog #25 registry-leftovers pass, 2026-10-02).** Verified on
   `dmt2-local` and by a blind reviewer that **no package writes the RCV STG/TFM
   tables** — `DMT_RCV_HEADERS_TFM_TBL` has 0 rows while `DMT_INV_TRX_TFM_TBL` has
   163 after a real run. The RCV tables are therefore permanently empty at runtime.
   The hazard is that eight committed views still map the `MiscReceipts` CEMLI to
   the empty RCV tables, so MiscReceipts drill-through, record detail, and run/status
   counts read zero rows while the real data sits in `DMT_INV_TRX_*`:
   `db/views/dmt_v_cemli_tfm_tables.sql` (43-44), `dmt_object_detail_v.sql`
   (184-190), `dmt_record_detail_v.sql` (586-611), `dmt_run_records_v.sql` (182-185),
   `dmt_run_status_v.sql` (207-212), `dmt_v_cemli_status.sql` (104-106),
   `dmt_scenario_summary_v.sql` (133-137, STG tables), plus the two RCV detail views.
   The correct fix is to repoint those views from `DMT_RCV_*` to `DMT_INV_TRX_*` and
   THEN drop the RCV STG/TFM tables, sequences, detail views, and the `Rcv*.ctl`
   files. It is NOT a table-name swap: the Fusion-id column changes
   (`FUSION_RECEIPT_HEADER_ID NUMBER` -> `FUSION_ID VARCHAR2`, drop the `TO_CHAR`),
   the RCV business columns (`RECEIPT_NUM`, `INTERFACE_LINE_NUM`, `ITEM_NUM`,
   `HEADER_INTERFACE_NUM`) have no INV_TRX equivalents and must be remapped (e.g.
   `ITEM_NUMBER`), and the grain changes from header + transactions (2 sub-objects)
   to transactions + lots + serials (3 sub-objects). Because that rewrites a live
   reconciliation/drill-through surface, it must land as one regression-verified PR
   (full regression was out of scope for the #25 naming pass). Dropping the tables
   without the repoint would invalidate the eight views (fails the 0-invalid gate);
   repointing without a regression run would be an unverified UI change — so the
   #25 pass left both halves for a dedicated follow-up and recorded them here.

   **RESOLVED (backlog #25 finish, 2026-10-02, branch `fix/25-rcv-repoint`).**
   All eight views were repointed from `DMT_RCV_*` to `DMT_INV_TRX_*` and the four
   orphan RCV STG/TFM tables plus their four sequences were dropped via a guarded,
   idempotent migration (`db/migrations/2026-10-02_drop_orphan_rcv_tables.sql`, runs
   twice cleanly). The two drill views `DMT_RCV_HEADERS_DETAIL_V` /
   `DMT_RCV_TRANSACTIONS_DETAIL_V` keep their names (so app-500 page 4 is unchanged)
   but now read INV_TRX: headers = the transaction grain, transactions = the lot and
   serial children. `DMT_RECORD_DETAIL_V` / `DMT_OBJECT_DETAIL_V` /
   `DMT_V_CEMLI_TFM_TABLES` now break MiscReceipts into the three catalog sub-objects
   (Inventory Transactions / Transaction Lots / Transaction Serials). Verified on
   `dmt2-local` as DMT_OWNER: 0 invalid objects after the drop; the MiscReceipts drill
   now returns the real loaded rows (run 198 shows 12 transactions = 7 LOADED /
   5 FAILED, 3 lots LOADED, 1 serial LOADED) where it previously read zero. The RCV
   `Rcv*.ctl` reference files under this folder are now dead and may be removed by a
   later housekeeping sweep (left in place here to keep this PR to the view/table scope).
2. **No physical rename needed** for the three Inv_* tables — they already mirror
   their tabs; the `TRX`/`SERIALS` shortenings are consistent and unambiguous.

## Reconciliation report pages by header (2026-10-09, backlog #689)

The registered report is now `bip/MiscReceipts/DMT_INV_TRX_RECON_V3_DM.xdm`, deployed alongside `DMT_INV_TRX_RECON_V2_DM` (never overwritten).
It pages on header boundaries (owner decision 2026-10-09, design section 5, "Reconciliation
fetches page on header boundaries"): a page is the next BIP_CHUNK_SIZE headers, keyed by the receipt source line id,
plus every base and interface row that belongs to them, and each row carries that header key in
the tenth column `PAGE_KEY`. `DMT_RECON_CONTRACT_PKG.FETCH_ROWS` counts headers, sends the last
header key back as `P_AFTER_KEY`, has no page cap, and fails the fetch with an error if a page
does not advance. Row selection (job ids only), RECORD_KEYs, FUSION_IDs and error text are the
same as in `DMT_INV_TRX_RECON_V2_DM`.
