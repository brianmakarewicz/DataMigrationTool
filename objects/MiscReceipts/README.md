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

## Staging Tables
- STG (Headers): `DMT_RCV_HEADERS_STG_TBL` (DDL: `schema/tables/92_dmt_rcv_headers_stg_tbl.sql`)
- STG (Transactions): `DMT_RCV_TRANSACTIONS_STG_TBL` (DDL: `schema/tables/93_dmt_rcv_transactions_stg_tbl.sql`)
- TFM (Headers): `DMT_RCV_HEADERS_TFM_TBL` (DDL: `schema/tables/94_dmt_rcv_headers_tfm_tbl.sql`)
- TFM (Transactions): `DMT_RCV_TRANSACTIONS_TFM_TBL` (DDL: `schema/tables/95_dmt_rcv_transactions_tfm_tbl.sql`)

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
- Data Model: `bip/MiscReceipts/MISC_RECEIPT_DM.xdm`
- Report: `bip/MiscReceipts/MISC_RECEIPT_RPT.xdo`
- Query: `bip/MiscReceipts/query.sql`
- Deployed to `/Custom/DMT/MiscReceipts/`

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
