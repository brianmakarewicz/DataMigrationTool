# MiscReceipts — gold regression fixture (inventory miscellaneous receipts)

A standalone, reloadable FBDI fixture (2 good + 1 bad inventory *miscellaneous
receipt*) that loads directly into Oracle Fusion Inventory via the ERP
Integration SOAP service, then is swept into the base tables by the Inventory
Transaction Manager, with read-only BIP verification of the base and interface
tables. **This is an SCM object — the SOAP load and every BIP read use the
`scm_impl` credential.** No DMT tool code and no DMT database are in the load
path.

**What a "misc receipt" is here.** It adds quantity of an existing item into an
existing inventory organization + subinventory, with no PO or source document —
transaction type **"Miscellaneous Receipt"** (transaction_type_id 42),
source-type **"Inventory"**. It posts to the inventory base table
`INV_MATERIAL_TXNS` and raises on-hand.

**Portable (rules 6–8).** Nothing is hardcoded and the fixture never depends on
data we loaded earlier. At load time a read-only BIP query discovers, on the
target pod: an existing **inventory organization**, an existing **plain item**
(no lot, no serial control) that is stock/transaction/asset enabled **and that
already has a readable current cost** (so the receipt can be valued), the
**"Stores" subinventory**, and the item's **primary UOM name**. The new receipts
are created fresh (prefix-stamped on `TRANSACTION_REFERENCE`); the org / item /
subinventory / UOM references are borrowed from what already exists on the pod.

## The one CSV (FBDI, no header row, position-based)

- `InvTransactionsInterface.csv` — inventory transactions, **273 data columns**
  in the exact order of `objects/InvTransactions/InvTransactionsInterface.ctl`
  (the control file's first 8 fields `TRANSACTION_INTERFACE_ID`…`LOAD_REQUEST_ID`
  and the trailing `OBJECT_VERSION_NUMBER` constant are loader-supplied and are
  NOT in the CSV). A plain (no lot / no serial) item needs only this one member;
  the lots (`InvTransactionLotsInterface.csv`) and serials
  (`InvSerialNumbersInterface.csv`) members are omitted.

Three rows, keyed by a prefix-stamped `TRANSACTION_REFERENCE`:

| Row | TRANSACTION_REFERENCE | Item | Qty | Purpose |
|---|---|---|---|---|
| GOOD-1 | `${PREFIX}RT-INVRCPT-G1` | discovered (e.g. `AS55001`) | 7 | valid → base |
| GOOD-2 | `${PREFIX}RT-INVRCPT-G2` | discovered (e.g. `AS55001`) | 4 | valid → base |
| BAD-1  | `${PREFIX}RT-INVRCPT-BAD1` | `FAKE-ITEM-${PREFIX}-BAD` | 1 | rejected → interface |

**Only the columns a misc receipt needs are populated (all others blank):**

| CSV column | Value | Why |
|---|---|---|
| `ORGANIZATION_NAME` | `${ORG_NAME}` (discovered) | target inventory org |
| `PROCESS_FLAG` | `1` | pending — the manager will process it |
| `ITEM_NUMBER` | discovered (good) / `FAKE-ITEM-${PREFIX}-BAD` (bad) | the item to receive |
| `SUBINVENTORY_CODE` | `${SUBINV}` = `Stores` | where the stock lands |
| `TRANSACTION_QUANTITY` | 7 / 4 / 1 | quantity received |
| `TRANSACTION_UNIT_OF_MEASURE` | `${UOM_NAME}` (discovered, e.g. `Ea`) | the item's primary UOM name |
| `TRANSACTION_DATE` | `${TXN_DATE}` = now, `YYYY/MM/DD HH24:MI:SS` | open inventory period |
| `TRANSACTION_SOURCE_TYPE_NAME` | `Inventory` | misc-receipt source type |
| `TRANSACTION_TYPE_NAME` | `Miscellaneous Receipt` | the transaction type |
| `TRANSACTION_MODE` | `3` | background processing |
| `LOCK_FLAG` | `2` | not locked |
| `TRANSACTION_REFERENCE` | `${PREFIX}RT-INVRCPT-…` | our prefix-stamped natural key |
| `SOURCE_CODE` | `DMT` | source tag |
| `SOURCE_HEADER_ID` | `${PREFIX}` | NOT NULL — batch header |
| `SOURCE_LINE_ID` | `${PREFIX}01/02/03` | NOT NULL — unique per row |
| `USE_CURRENT_COST_FLAG` | `Y` | **critical** — value the units from the item's current cost |

**Critical layout / data facts (all learned live):**

- **`SOURCE_HEADER_ID` and `SOURCE_LINE_ID` are NOT NULL** on
  `INV_TRANSACTIONS_INTERFACE` (confirmed via `all_tab_columns` — the 13 not-null
  columns are TRANSACTION_INTERFACE_ID, SOURCE_CODE, SOURCE_LINE_ID,
  SOURCE_HEADER_ID, PROCESS_FLAG, TRANSACTION_MODE, the four audit columns,
  TRANSACTION_QUANTITY, TRANSACTION_DATE, OBJECT_VERSION_NUMBER). Leaving
  SOURCE_HEADER_ID / SOURCE_LINE_ID blank makes SQL*Loader reject every row with
  `ORA-01400: cannot insert NULL` and **0 rows reach the interface** (first live
  attempt, prefix 90250).
- **`USE_CURRENT_COST_FLAG` MUST be `Y`.** A miscellaneous receipt values the
  received units. If the flag is left NULL, the Transaction Manager rejects every
  row with `INV_MATRX_CURRENT_COST_NULL` — even for a cost-enabled item (prefixes
  90251–90255). Setting it to `Y` tells the manager to read the item's current
  (perpetual average) cost, which is why discovery must pick an item that already
  has one. Do **not** instead set `USE_CURRENT_COST_FLAG='N'` with a supplied
  `TRANSACTION_COST` — that path needs a costing worksheet the demo pod does not
  have and fails with `INV_MATRX_LINE_NUM_NOT_FOUND` (prefix 90253).
- **The bad row must reach the interface and be rejected there, not
  pre-validated.** `FAKE-ITEM-${PREFIX}-BAD` loads into the interface and the
  Transaction Manager rejects it with `INV_INVALID_ITEM` in
  `INV_TRANSACTIONS_INTERFACE.ERROR_CODE` (process_flag 3 = error).

## The exact call (ESS orchestration, in order)

`loadAndImportData` uploads the zip to UCM and runs the **InterfaceLoader** chain
(controller → async → SqlLdr import) which loads `INV_TRANSACTIONS_INTERFACE`.
On this pod that is **all** `loadAndImportData` does for this interface — the
`SingleTMEssJob` it is asked to chain runs with `#NULL` and processes nothing
(it needs a specific transaction batch). The rows sit at `PROCESS_FLAG=1`.

The rows are then swept into the base tables by a **separate downstream job, the
Inventory Transaction Manager poller `PollTMEssJob`** ("Manage Inventory
Transactions"), submitted with `submitESSJobRequest`. It scans for pending
(`PROCESS_FLAG=1`) rows, posts the valid ones to `INV_MATERIAL_TXNS`, and flags
the rejects (`PROCESS_FLAG=3` + `ERROR_CODE`). Verification runs after it
completes.

| Thing | Value |
|---|---|
| Endpoint | `{FUSION_URL}/fscmService/ErpIntegrationService` |
| Load operation | `loadAndImportData` |
| Auth | HTTP Basic, credential role **`scm_impl`** (connections.json) |
| UCM DocumentAccount | `scm/inventoryTransaction/import` |
| ContentType | `ZIP` |
| `<typ:interfaceDetails>` | `33` (the SCM Inventory-Transaction `ERP_INTERFACE_OPTIONS_ID` from `db/seed/dmt_erp_interface_options_tbl.sql`, CEMLI `MiscReceipts`) |
| `<erp:JobName>` (load's jobList) | `/oracle/apps/ess/scm/inventory/materialTransactions/txnManager,SingleTMEssJob` (seed stores it with a `;` before `SingleTMEssJob`; `loadAndImportData` needs the last `;` → `,`) |
| Load `<erp:ParameterList>` | `#NULL` |
| `<typ:notificationCode>` | `10` |
| **Downstream job** | `submitESSJobRequest` `/oracle/apps/ess/scm/inventory/materialTransactions/txnManager,PollTMEssJob`, ParameterList `#NULL`, auth `scm_impl` |

`loadAndImportData` returns the **Load ESS request id** in `<result>`. Poll it
with `getESSJobStatus` every 60s until terminal (SUCCEEDED). Then submit and poll
`PollTMEssJob`. Both are `scm_impl`. `LOAD_REQUEST_ID` is stamped on every
`INV_TRANSACTIONS_INTERFACE` row and is the selection key for the bad row.

## Discovery (run before build, read-only BIP, `scm_impl`)

One step returns the org, item, subinventory, and UOM in a single row. It picks a
plain, stock/transaction/asset-enabled item **that has already posted a
miscellaneous receipt (transaction_type_id 42) in the org**, ordered by the most
recent such posting — that is the portable, reliable signal that the item
currently carries a readable cost (so `USE_CURRENT_COST_FLAG='Y'` succeeds):

```sql
SELECT * FROM (
  SELECT hou.name AS ORG_NAME, p.organization_code AS ORG_CODE,
         e.item_number AS ITEM_NUMBER,
         sub.secondary_inventory_name AS SUBINV,
         u.unit_of_measure AS UOM_NAME,
         (SELECT MAX(t.transaction_date) FROM inv_material_txns t
           WHERE t.inventory_item_id = e.inventory_item_id
             AND t.organization_id  = e.organization_id
             AND t.transaction_type_id = 42) AS LAST_MISC
  FROM   egp_system_items_b e
  JOIN   inv_org_parameters p        ON p.organization_id = e.organization_id
  JOIN   hr_organization_units_f_tl hou
         ON hou.organization_id = p.organization_id AND hou.language = USERENV('LANG')
  JOIN   inv_units_of_measure_vl u   ON u.uom_code = e.primary_uom_code
  JOIN   inv_secondary_inventories sub
         ON sub.organization_id = e.organization_id
        AND sub.secondary_inventory_name = 'Stores'
  WHERE  p.organization_id <> p.master_organization_id
  AND    e.lot_control_code = 1 AND e.serial_number_control_code = 1
  AND    e.stock_enabled_flag = 'Y' AND e.mtl_transactions_enabled_flag = 'Y'
  AND    e.inventory_asset_flag = 'Y'
  AND    EXISTS (SELECT 1 FROM inv_material_txns t
                  WHERE t.inventory_item_id = e.inventory_item_id
                    AND t.organization_id  = e.organization_id
                    AND t.transaction_type_id = 42)
  ORDER BY (SELECT MAX(t.transaction_date) FROM inv_material_txns t
             WHERE t.inventory_item_id = e.inventory_item_id
               AND t.organization_id  = e.organization_id
               AND t.transaction_type_id = 42) DESC, e.item_number
) WHERE ROWNUM = 1
```

Tokens stamped into the good rows: `${ORG_NAME}`, `${ITEM_NUMBER}`, `${SUBINV}`,
`${UOM_NAME}`. `${TXN_DATE}` is today's timestamp (derived in `build_artifact`).

## Verification (read-only, via the BIP relay — direct single-table reads, `scm_impl`)

- **Good → base.** Direct read of `INV_MATERIAL_TXNS` by the prefix on the
  natural key: `WHERE source_code = 'DMT' AND transaction_reference LIKE
  '<prefix>RT-INVRCPT-%'`. Each good reference present with a real `TRANSACTION_ID`
  = pass. (There is no `TRANSACTION_ID` column on the interface table; base uses
  `TRANSACTION_ID`.)
- **Bad → interface + absent from base.** Direct read of
  `INV_TRANSACTIONS_INTERFACE` by `load_request_id`, reading `ERROR_CODE`
  (`PROCESS_FLAG=3`); and the base read above confirms the bad reference is
  absent from `INV_MATERIAL_TXNS`.

Tables: interface `INV_TRANSACTIONS_INTERFACE` (error in `ERROR_CODE`,
long text in `ERROR_EXPLANATION`), base `INV_MATERIAL_TXNS`, on-hand
`INV_ONHAND_QUANTITIES_DETAIL`.

## How to run it

```bash
cd gold_regression/harness
python run_object.py MiscReceipts --prefix <PREFIX>   # discover -> build -> load -> poll TM -> verify
# or step by step:
python build_artifact.py MiscReceipts <PREFIX>
python load_fbdi.py MiscReceipts ../objects/MiscReceipts/MiscReceipts_gold.zip --role scm_impl
python verify.py MiscReceipts <LOAD_REQUEST_ID> <PREFIX> --role scm_impl
```

The CSV template is regenerated (if ever needed) by
`harness/_gen_invtrx_template.py`, which reads the authoritative 273-column list
from `harness/_invtrx_cols.py` (extracted directly from the CTL).

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.** (SCM object; `scm_impl` for the SOAP load and
every BIP read.)

Standalone load path only (no DMT database / code in the load path);
verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `90256` |
| Load ESS request id (`loadAndImportData` result) | `9764272` |
| Load terminal status (`getESSJobStatus`) | `SUCCEEDED` |
| Downstream `PollTMEssJob` request id | `9764279` (SUCCEEDED) |
| Discovered org / item / subinventory / UOM | `Seattle` (`001`) / `AS55001` / `Stores` / `Ea` |

**Good rows → base table `INV_MATERIAL_TXNS` (2/2, transaction_type_id 42):**

| TRANSACTION_REFERENCE | TRANSACTION_ID | Qty |
|---|---|---|
| `90256RT-INVRCPT-G1` | `492176` | 7 |
| `90256RT-INVRCPT-G2` | `492175` | 4 |

On-hand for `AS55001` in `001`/`Stores` reflects the receipts (243 after this run).

**Bad row → interface rejection, absent from base (1/1):**

| TRANSACTION_REFERENCE | ERROR_CODE | Reaches base? |
|---|---|---|
| `90256RT-INVRCPT-BAD1` | `INV_INVALID_ITEM` | no |

The bad receipt (`FAKE-ITEM-90256-BAD`) landed in `INV_TRANSACTIONS_INTERFACE`
(load_request_id 9764272) at `PROCESS_FLAG=3` with `INV_INVALID_ITEM`
("The value provided for the Item attribute is invalid…") and no row in
`INV_MATERIAL_TXNS`. Gold zip `MiscReceipts_gold.zip` (last built at prefix
90256) kept in this directory.

**Debug path that got us here (all fixed):**
1. prefix 90250 — 0 interface rows: `ORA-01400` from NULL `SOURCE_HEADER_ID` /
   `SOURCE_LINE_ID` (both NOT NULL). Fixed by stamping them.
2. prefix 90251 — rows loaded but stuck at `PROCESS_FLAG=1`: `loadAndImportData`
   ran only the InterfaceLoader; the chained `SingleTMEssJob` with `#NULL`
   processed nothing. Fixed by adding the `PollTMEssJob` downstream sweep.
3. prefixes 90252/90254/90255 — `INV_MATRX_CURRENT_COST_NULL`: the receipt was
   not valued. Fixed by `USE_CURRENT_COST_FLAG='Y'` + discovery restricted to an
   item that already posted a misc receipt (proven cost-enabled).
4. prefix 90253 — `USE_CURRENT_COST_FLAG='N'` + supplied `TRANSACTION_COST`
   failed with `INV_MATRX_LINE_NUM_NOT_FOUND` (needs a costing worksheet). Not
   used.
