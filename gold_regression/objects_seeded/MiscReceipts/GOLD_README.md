# MiscReceipts — Gold Regression Fixture (v2 seeded, LIVE-PROVEN)

Inventory *miscellaneous receipts* loaded via FBDI. A misc receipt adds quantity of an
existing item into an existing inventory organization + subinventory, with no PO or source
document — transaction type **"Miscellaneous Receipt"** (transaction_type_id 42), source
type **"Inventory"**. Rows land in the interface table `INV_TRANSACTIONS_INTERFACE`, are
swept by the Inventory Transaction Manager into the base table `INV_MATERIAL_TXNS`, and
raise on-hand.

**This is an SCM object — the SOAP load AND the read-only BIP verify both use the
`scm_impl` credential.** Financials `fin_impl` cannot see the SCM inventory tables and
cannot submit the transaction-manager jobs.

This is the **v2 seeded** version of `../../objects/MiscReceipts/` (v1, FROZEN). It is
identical except that v1's load-time discovery of the org / item / subinventory / UOM has
been replaced with the literal seeded values that discovery resolved to. There is **no
discovery block** and nothing (other than the run prefix and today's transaction date) is
computed at run time.

Standalone load path only: the harness assembles the FBDI zip and calls the Fusion ERP
Integration SOAP service directly. No DMT database, no DMT pipeline PL/SQL is in the load
path. Verification is the read-only BIP ephemeral-relay only (direct single-table reads).

## The seeded references (v1 discovery replaced by literals)

v1 discovered four references at load time; all four are standard seeded demo data that
ships in every pod and that we did **not** load ourselves (none carries a prefix). Confirmed
present unprefixed on this pod via a read-only `scm_impl` BIP read before conversion (org
`001` join to item `AS55001`, subinventory `Stores`, UOM `Ea` all returned one row):

| CSV column | Seeded literal | What it is |
|---|---|---|
| `ORGANIZATION_NAME` | `Seattle` | Seattle inventory organization (org code `001`) |
| `ITEM_NUMBER` (good rows) | `AS55001` | A seeded, cost-carrying, plain (no lot / no serial) stock item in Seattle |
| `SUBINVENTORY_CODE` | `Stores` | The `Stores` subinventory where the stock lands |
| `TRANSACTION_UNIT_OF_MEASURE` | `Ea` | The item's primary UOM name |

Why `AS55001` specifically: a miscellaneous receipt must value the received units. With
`USE_CURRENT_COST_FLAG = Y`, the Transaction Manager reads the item's current (perpetual
average) cost, so the item must already carry a readable cost. `AS55001` in `Seattle` /
`Stores` has posted misc receipts before (v1 proved this at prefix 90256, and v2 proves it
again below), so it carries a cost and the good rows value cleanly.

Only two placeholders remain:

- `${PREFIX}` — stamped fresh onto the natural key `TRANSACTION_REFERENCE` (and the batch
  `SOURCE_HEADER_ID` / `SOURCE_LINE_ID`) so re-runs never collide.
- `${TXN_DATE}` — today's timestamp (`YYYY/MM/DD HH24:MI:SS`, derived in
  `build_artifact.derived_tokens`) so every receipt lands in an **open** inventory
  accounting period. A hard-coded date would fall in a closed period and be rejected.

The bad row's item `FAKE-ITEM-${PREFIX}-BAD` is a deliberate literal defect (an item that
does not exist), not a seeded reference.

## Critical data-quality facts (carried from v1, all learned live)

- **`SOURCE_HEADER_ID` and `SOURCE_LINE_ID` are NOT NULL** on
  `INV_TRANSACTIONS_INTERFACE`. They are stamped `${PREFIX}` and `${PREFIX}01/02/03`. Leaving
  them blank makes SQL*Loader reject every row with `ORA-01400` and 0 rows reach the
  interface.
- **`USE_CURRENT_COST_FLAG` MUST be `Y`.** If NULL, the Transaction Manager rejects every
  row with `INV_MATRX_CURRENT_COST_NULL`. Do NOT instead set it to `N` with a supplied
  `TRANSACTION_COST` — that path needs a costing worksheet the demo pod does not have and
  fails with `INV_MATRX_LINE_NUM_NOT_FOUND`.
- **The bad row must reach the interface and be rejected there, not pre-validated.**
  `FAKE-ITEM-${PREFIX}-BAD` loads into the interface and the Transaction Manager rejects it
  with `INV_INVALID_ITEM` in `INV_TRANSACTIONS_INTERFACE.ERROR_CODE` (process_flag 3).

## The object

One object = one FBDI zip = one ESS load job. MiscReceipts ships a **single CSV**,
`InvTransactionsInterface.csv` (interface table `INV_TRANSACTIONS_INTERFACE`, **273
positional columns, no header row**, in the order of
`objects/InvTransactions/InvTransactionsInterface.ctl`). A plain (no lot / no serial) item
needs only this member; the lots and serials members are omitted.

Three rows, keyed by a prefix-stamped `TRANSACTION_REFERENCE`:

| Row | TRANSACTION_REFERENCE | Item | Qty | Purpose |
|---|---|---|---|---|
| GOOD-1 | `${PREFIX}RT-INVRCPT-G1` | `AS55001` | 7 | valid → base |
| GOOD-2 | `${PREFIX}RT-INVRCPT-G2` | `AS55001` | 4 | valid → base |
| BAD-1  | `${PREFIX}RT-INVRCPT-BAD1` | `FAKE-ITEM-${PREFIX}-BAD` | 1 | rejected → interface |

## Exact web-service call (ESS orchestration, in order)

`loadAndImportData` uploads the zip to UCM and runs the InterfaceLoader chain, loading
`INV_TRANSACTIONS_INTERFACE` at `PROCESS_FLAG=1`. On this pod that is all it does for this
interface — the `SingleTMEssJob` it chains runs with `#NULL` and processes nothing. The rows
are then swept into the base table by a **separate downstream job**, the Inventory
Transaction Manager poller `PollTMEssJob` ("Manage Inventory Transactions"), submitted with
`submitESSJobRequest`. It posts the valid rows to `INV_MATERIAL_TXNS` and flags the reject
(`PROCESS_FLAG=3` + `ERROR_CODE`). Verification runs after it completes.

| Thing | Value |
|---|---|
| Endpoint | `{FUSION_URL}/fscmService/ErpIntegrationService` |
| Load operation | `loadAndImportData` |
| Auth | HTTP Basic, credential role **`scm_impl`** |
| UCM DocumentAccount | `scm/inventoryTransaction/import` |
| `interfaceDetails` | `33` |
| `<JobName>` (comma form) | `/oracle/apps/ess/scm/inventory/materialTransactions/txnManager,SingleTMEssJob` |
| Load `<ParameterList>` | `#NULL` |
| **Downstream job** | `submitESSJobRequest` `/oracle/apps/ess/scm/inventory/materialTransactions/txnManager,PollTMEssJob`, ParameterList `#NULL`, auth `scm_impl` |

## Verification (read-only BIP, direct single-table reads)

- **Good → base `INV_MATERIAL_TXNS`** by the prefix on the natural key:
  `WHERE source_code = 'DMT' AND transaction_reference LIKE '<prefix>RT-INVRCPT-%'`. Each
  good reference present with a real `TRANSACTION_ID` = pass.
- **Bad → interface + absent from base.** Read `INV_TRANSACTIONS_INTERFACE` by
  `load_request_id` for `ERROR_CODE` (`PROCESS_FLAG=3`); the base read above confirms the bad
  reference is absent from `INV_MATERIAL_TXNS`.

## Last live-proven evidence (v2 seeded)

**2026-07-20 — LIVE-PROVEN. PASS (both directions).** Standalone load path only (no DMT
database / code in the load path); verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-20 |
| Prefix | `87068` |
| Load ESS request id (`loadAndImportData` result) | `9766441` (terminal SUCCEEDED) |
| Downstream `PollTMEssJob` request id | `9766467` (SUCCEEDED) |
| Seeded org / item / subinventory / UOM | `Seattle` (`001`) / `AS55001` / `Stores` / `Ea` |

**Good rows → base table `INV_MATERIAL_TXNS` (2/2):**

| TRANSACTION_REFERENCE | TRANSACTION_ID | Qty |
|---|---|---|
| `87068RT-INVRCPT-G1` | `493175` | 7 |
| `87068RT-INVRCPT-G2` | `493174` | 4 |

**Bad row → interface rejection, absent from base (1/1):**

| TRANSACTION_REFERENCE | ERROR_CODE | Reaches base? |
|---|---|---|
| `87068RT-INVRCPT-BAD1` | `INV_INVALID_ITEM` | no |

The bad receipt (`FAKE-ITEM-87068-BAD`) landed in `INV_TRANSACTIONS_INTERFACE`
(load_request_id 9766441) at `PROCESS_FLAG=3` with `INV_INVALID_ITEM` and no row in
`INV_MATERIAL_TXNS`. Gold zip `MiscReceipts_gold.zip` kept in this directory (last built at
prefix 87068).

## Files

- `recipe.json` — self-contained recipe, **no discovery block**; seeds are literals in the CSV.
- `artifact/InvTransactionsInterface.csv` — the templated 273-column CSV (2 good + 1 bad).
  Only `${PREFIX}` and `${TXN_DATE}` are placeholders; org / item / subinventory / UOM are
  seeded literals.
- `MiscReceipts_gold.zip` — last assembled artifact (frozen at prefix 87068).

## Re-run

```
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py MiscReceipts
```
