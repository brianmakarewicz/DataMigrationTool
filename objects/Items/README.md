# Items

## Overview
Inventory items migrated into Fusion Product Information Management. Each row represents an item-organization combination with approximately 130 business columns covering UOM, planning, purchasing, and order management attributes.

## Load Method
FBDI
- Template: EgpItemImportTemplate.xlsm (EGP_SYSTEM_ITEMS_INTERFACE)
- Pipeline: Standard FBDI pipeline via run_one_object_type

## Parent/Child
- Parent: None (standalone)
- Linkage: N/A

## Staging Tables
- STG: `DMT_ITEMS_STG_TBL` (DDL: `schema/tables/190_dmt_egp_item_stg_tbl.sql`)
- TFM: `DMT_ITEMS_TFM_TBL` (DDL: `schema/tables/191_dmt_egp_item_tfm_tbl.sql`)
- TFM status column: `TFM_STATUS` (not STATUS)

## Key Columns
- ITEM_NUMBER
- ORGANIZATION_CODE
- DESCRIPTION
- PRIMARY_UOM_CODE
- ITEM_CLASS_NAME
- SOURCE_SYSTEM_CODE

## Code References
- Validator: `packages/validators/dmt_egp_item_validator_pkg`
- Transformer: `packages/transformers/dmt_egp_item_transform_pkg`
- FBDI Generator: `packages/generators/fbdi/inventory/dmt_egp_item_fbdi_gen_pkg`
- Results/Reconciliation: `packages/reconciliation/dmt_egp_item_results_pkg`
- Runner (standalone dev/test): `packages/runners/dmt_egp_item_runner_pkg`
- Loader wiring: `dmt_loader_pkg.RUN_ITEMS` -> `run_one_object_type('Items')`

## Pipeline Configuration
- CEMLI Code: `Items`
- Orchestration: P2P (runs first, before ItemCategories and Suppliers)
- UCM Account: pim/import
- ESS Job: ItemImportJobDef
- ParameterList (7 args):
  1. `argument1` — Batch ID (Number, required) — set to INTEGRATION_ID
  2. `argument2` — Organization (LOV, optional) — `null` (literal string) when Process All Orgs = Y
  3. `argument3` — Process Only — `CREATE` | `SYNC` | `UPDATE`
  4. `argument4` — Process All Organizations — `Y` | `N`
  5. `argument5` — Delete Processed Rows — `ORA_ER` (Error Rows) | `ORA_ALL` | `ORA_COMP`
  6. `argument6` — Reprocess Error — `N` | `Y`
  7. `argument7` — Process Sequentially — `Y` | `N`
- Default ParameterList: `BATCH_ID,null,CREATE,null,null,N,Y`
  (arg4 Process All Organizations and arg5 Delete Processed Rows are sent as
  `null`, not `Y`/`ORA_ER` — matches the live loader submission in
  `dmt_loader_pkg.RUN_ITEMS`)
- Discovery: Request ID 9542220, fin_impl, 2026-05-21
- Note: Item Categories (EgpItemCategoriesImportTemplate.csv) loads in the same ZIP — not a separate ESS job

## FBDI ZIP Contents
This job bundles two CSVs in one ZIP:
1. `EgpItemImportTemplate.csv` — items (EGP_SYSTEM_ITEMS_INTERFACE)
2. `EgpItemCategoriesImportTemplate.csv` — item categories (EGP_ITEM_CATEGORIES_INTERFACE)

Both are submitted under `ItemImportJobDef` in a single ESS call.

## Fusion batch id (backlog #411, 2026-10-08)
Owner decision 2026-10-07 (the Customers rule, PR #657): the Item Import batch id DMT sends is
the run prefix followed by the source `BATCH_ID` (prefix 93460 + source 8101 = 934608101), the
prefix followed by the work-queue id when the source has none, and the source value unchanged
when USE_PREFIX = N. Both transforms (items and categories) use the same expression, so a
batch's items and categories stay together. Before this the seed's 8101 / 8102 went to Fusion
unchanged every run, and EGP_SYSTEM_ITEMS_INTERFACE held hundreds of leftover rows under those
two numbers from earlier loads; a new run's Item Import (argument 1 = the batch) could pick
them up. The source batch still partitions the loads (one child work item per batch), and the
chained Item Import is still found by this batch's id. The report needs no change: it already
selects by the Item Import REQUEST_ID and the load LOAD_REQUEST_ID (V3).

## Category rows use this run's item (backlog #610, 2026-10-09)
Each category TFM row links by id to the item row of the same run
(`DMT_EGP_ITEM_CAT_TFM_TBL.ITEM_TFM_SEQUENCE_ID` = the item's `TFM_SEQUENCE_ID`, matched on the
source item number + organization) and copies that row's run-prefixed ITEM_NUMBER. Before this the
category transform called `DMT_XREF_PKG.ITEM_NUMBER`, which returned the newest already-LOADED
item, i.e. the previous run's, so every run assigned its categories to the previous run's item.
When the item is not in the run the source item number is used unchanged. Details in
objects/ItemCategories/README.md.

## Partition ordering (backlog #610, 2026-10-09)
Items spawns one child work item per batch. When a batch's category rows belong to items in a
different batch, that batch must not import first. `DMT_EGP_ITEM_RESULTS_PKG.GET_PARTITION_KEYS`
adds an `AFTER` array of those item batch ids to the batch token, for example
`{"BATCH_ID":"934608102","AFTER":["934608101"]}`. `DMT_QUEUE_WORKER_PKG.EXECUTE_ONE` stores the
token without `AFTER`, inserts the child PENDING, and appends `QUEUE_ID:<sibling queue id>` to its
DEPENDS_ON. `DMT_QUEUE_PKG` promotes it once that sibling is DONE (HALT) or DONE/FAILED
(CONTINUE), and under HALT skips it if the sibling fails. A wait that would close a cycle is not
recorded (logged WARN). A batch whose categories ride with their own items has no `AFTER`, so its
token is unchanged.

## Reconciliation
Contract v1 report `/Custom/DMT2/Items/DMT_ITEM_RECON_V3_DM.xdm` (since 2026-10-07; V1 and V2
stay deployed). One report returns both record types (`Item`, `ItemCategory`). It is called once
per item batch (one child work item = one load = one Item Import) with that batch's own load id
and Item Import id, and finds rows only by those job ids:
- base items: `EGP_SYSTEM_ITEMS_B.REQUEST_ID` = the Item Import id;
- base category assignments: `EGP_ITEM_CATEGORIES.REQUEST_ID` = the Item Import id;
- interface rows and `EGP_IMPORT_ERRORS`: `LOAD_REQUEST_ID` = the load id or `REQUEST_ID` = the
  import id (Fusion stamps both).
The run prefix is never a search value. Match keys (RECORD_KEY = TFM RECON_KEY):
ITEM_NUMBER~ORGANIZATION_CODE and ITEM_NUMBER~ORGANIZATION_CODE~CATEGORY_SET_NAME~CATEGORY_CODE.

Caveat: Fusion rewrites `EGP_SYSTEM_ITEMS_B.REQUEST_ID` when a later import touches the item (a
category assignment does). A row already LOADED is never re-read, so this only matters if an item
is touched by another import before its own batch is reconciled.

### Settle + re-read before failing a late-committing item (Backlog #147)

Item Import can report its ESS job finished (SUCCEEDED/WARNING) a short moment
before a just-created item row becomes visible in the base table
`EGP_SYSTEM_ITEMS_B` that the reconcile reads — a commit/visibility lag, not a
missing wait (the import is already polled to terminal and every
InterfaceLoaderController request is already reconciled). First seen in run 205:
GOOD item `RT-PLAIN-001` was marked FAILED ("not created in base table") yet a
REST re-check confirmed it was present in Fusion.

This is now handled by a **shared** reconcile settle + re-read that protects every
object, not just Items. Before the unaccounted sweep finalizes a row, the shared
reconcile waits `RECONCILE_SETTLE_SECONDS` (default 30) and re-reads the base
table for rows still awaiting confirmation, up to `RECONCILE_MAX_RETRIES`
(default 2) times — but only after a SUCCEEDED/WARNING import, and never for a row
that already carries a real per-row rejection. It never fabricates LOADED. See
`docs/CONTRACT_V1_CONFORMANCE_PLAN.md` ("Shared reconcile settle + re-read") and
`DMT_QUEUE_WORKER_PKG.RECONCILE_ONE` / `SETTLE_AND_REREAD`.

## Status
WIRED INTO PIPELINE. Packages built. Loader + scheduler dispatch added.
BIP artifacts created. Needs E2E test with real data.

## Known-good lot/serial items & mapping (2026-07-15)

**Headline finding: our lot- and serial-controlled test items ALREADY reach the Fusion
base table `EGP_SYSTEM_ITEMS_B` with the correct control codes.** A read-only query of
the live demo instance (scm_impl) found all six of our regression items present in org
`000` (the item master), created 2026-05-25, with the exact control codes our seed sets:

| Item (base table) | ORG | LOT_CONTROL_CODE | SERIAL_NUMBER_CONTROL_CODE | PRIMARY_UOM_CODE | Created |
|---|---|---|---|---|---|
| DMT-RT-PLAIN-001            | 000 | 1 | 1 | ECH | 2026-05-25 03:24 |
| DMT-RT-SERIAL-001           | 000 | 1 | 5 | ECH | 2026-05-25 03:24 |
| DMT-RT-LOT-001              | 000 | 2 | 1 | ECH | 2026-05-25 03:24 |
| DMT-RT-PLN-05242331 (prefixed) | 000 | 1 | 1 | ECH | 2026-05-25 03:34 |
| DMT-RT-SER-05242331 (prefixed) | 000 | 1 | 5 | ECH | 2026-05-25 03:34 |
| DMT-RT-LOT-05242331 (prefixed) | 000 | 2 | 1 | ECH | 2026-05-25 03:34 |

So the premise that our lot item (`LOT_CONTROL_CODE=2`) and serial item
(`SERIAL_NUMBER_CONTROL_CODE=5`) never reached `EGP_SYSTEM_ITEMS_B` is not supported by
the live data — they are there, in the same org as the plain item, with correct codes.
Whatever regression run 155 observed as a "failure" is downstream of item creation
(most likely BIP reconciliation not matching, or a re-run where Item Import treats an
already-existing item differently), not a missing control attribute on the item itself.

### Real controlled items on the demo instance (for reference / mimicking)

Both real items live in org `000` — the same master org our test data uses — and, like
ours, carry NO auto-number start value and NO alpha prefix on the base row. Control is a
single code; the generation/prefix attributes are optional and empty on real items too.

Real LOT-controlled item — **HP5001**, org `000`:
- `LOT_CONTROL_CODE = 2`
- `START_AUTO_LOT_NUMBER` = empty, `AUTO_LOT_ALPHA_PREFIX` = empty
- `CHILD_LOT_FLAG = N`, `LOT_DIVISIBLE_FLAG = Y`
- `PRIMARY_UOM_CODE = zzu`
- Other real lot examples: WT001136 (org 102), CM4751124 (org 002), HP5001 also in HC01/HC02/HC03.

Real SERIAL-controlled item — **AS88003**, org `000`:
- `SERIAL_NUMBER_CONTROL_CODE = 5` (predefined at receipt) — same code our serial item uses
- `START_AUTO_SERIAL_NUMBER` = empty, `AUTO_SERIAL_ALPHA_PREFIX` = empty
- `PRIMARY_UOM_CODE = zzu`
- Other real serial examples: RACK0001, HPR0001 (org 000, SER=5); AS4751500 (org 000,
  SER=2, and this one DOES have `START_AUTO_SERIAL_NUMBER=31001`, `AUTO_SERIAL_ALPHA_PREFIX=AS475-`);
  AS88001 (org 001, SER=7), AS88004 (org 000, SER=5), Conveyor (org M001, SER=5).

### What our test items already match (nothing to change on control attributes)
- Org: ours load into `000`, same as HP5001 and AS88003. Org 000 is enabled for lot/serial.
- Lot: ours `LOT_CONTROL_CODE=2` == HP5001. No start-number/prefix required for code 2.
- Serial: ours `SERIAL_NUMBER_CONTROL_CODE=5` == AS88003. No start-number/prefix required for code 5.
- Our `EgpSystemItemsInterface.ctl` DOES carry the relevant columns
  (`LOT_CONTROL_CODE`, `SERIAL_NUMBER_CONTROL_CODE`, `START_AUTO_LOT_NUMBER`,
  `START_AUTO_SERIAL_NUMBER`, `AUTO_LOT_ALPHA_PREFIX`, `AUTO_SERIAL_ALPHA_PREFIX`,
  `CHILD_LOT_FLAG`, etc.), so no CTL column is missing.

### One cosmetic difference (not the cause of any failure)
Real items use `PRIMARY_UOM_CODE = zzu`; ours use `ECH` (both are "Each"). Our plain,
lot, and serial items all loaded with `ECH`, so `ECH` is accepted — no change needed.

### Reusable read-only queries (scm_impl)
Find real lot items:
`SELECT b.ITEM_NUMBER ITEM, p.ORGANIZATION_CODE ORG, b.LOT_CONTROL_CODE LOT FROM EGP_SYSTEM_ITEMS_B b JOIN INV_ORG_PARAMETERS p ON p.ORGANIZATION_ID=b.ORGANIZATION_ID WHERE b.LOT_CONTROL_CODE > 1 AND ROWNUM<=8`

Find real serial items:
`SELECT b.ITEM_NUMBER ITEM, p.ORGANIZATION_CODE ORG, b.SERIAL_NUMBER_CONTROL_CODE SER, b.START_AUTO_SERIAL_NUMBER STARTSER, b.AUTO_SERIAL_ALPHA_PREFIX SALPHA FROM EGP_SYSTEM_ITEMS_B b JOIN INV_ORG_PARAMETERS p ON p.ORGANIZATION_ID=b.ORGANIZATION_ID WHERE b.SERIAL_NUMBER_CONTROL_CODE > 1 AND p.ORGANIZATION_CODE='000' AND ROWNUM<=4`

Confirm OUR items reached the base table:
`SELECT b.ITEM_NUMBER ITEM, b.LOT_CONTROL_CODE LOT, b.SERIAL_NUMBER_CONTROL_CODE SER, b.PRIMARY_UOM_CODE PUOM, TO_CHAR(b.CREATION_DATE,'YYYY-MM-DD HH24:MI') CREATED FROM EGP_SYSTEM_ITEMS_B b JOIN INV_ORG_PARAMETERS p ON p.ORGANIZATION_ID=b.ORGANIZATION_ID WHERE b.ITEM_NUMBER LIKE 'DMT-RT-%' AND p.ORGANIZATION_CODE='000' AND ROWNUM<=10`

Note: `EGP_SYSTEM_ITEMS_B` has NO `AUTO_LOT_NUMBER_TYPE`, `LOT_NUMBER_GENERATION`,
`AUTO_SERIAL_NUMBER_TYPE`, `SERIAL_NUMBER_GENERATION`, or `ITEM_CLASS_ID` columns — those
names error with ORA-00904. Use `START_AUTO_LOT_NUMBER` / `START_AUTO_SERIAL_NUMBER` and
`AUTO_LOT_ALPHA_PREFIX` / `AUTO_SERIAL_ALPHA_PREFIX` instead.

### Proposed change to test data / pipeline
NONE required on the item control attributes — our seed is correct and the items load. If
run 155 flagged the lot/serial items, the investigation should move to the Items BIP
reconciliation (`ITEM_DM.xdm`, matches `EGP_SYSTEM_ITEMS_INTERFACE` PROCESS_FLAG by
BATCH_ID + ITEM_NUMBER + ORGANIZATION_CODE) and to re-run behavior: on a re-run the items
already exist in the base table, so `Process Only = CREATE` may skip them and leave the
interface row in a state the reconciler reads as "not loaded." Verify the interface
PROCESS_FLAG for those specific rows in run 155 before treating this as an item-attribute bug.

## History
- 2026-10-07: recon report V3 (backlog #241) finds rows only by each work item's own Fusion
  job ids (see Reconciliation). Proof run 265 (prefix 93321, scenario RegressionTest2610071920):
  batch 8101 load 10075509 / import 10075520, batch 8102 load 10075506 / import 10075515, each
  matching what Fusion stamped; items 3 LOADED + 1 FAILED (bad org), categories 2 LOADED + 2
  FAILED (bad category set; non-leaf category), 0 UNACCOUNTED, same as run 238. A
  reconcile-only rerun left both TFM tables byte-identical. The non-leaf category row
  (`eCom_Bus_Prod`) is a real Fusion rejection of the test data and still shows as a
  GOOD-FAILED in dmt_regression_run.py, as it did before.
- DDL deployed initially.
- 2026-05-21: All packages built (validator, transformer, FBDI gen, results, runner).
- 2026-05-21: Wired into dmt_loader_pkg + dmt_scheduler_pkg P2P sequence.
  Added BIP reconciliation (RECONCILE_BATCH) to results package.

## Table-name vs FBDI-tab audit (backlog #90, 2026-10-01)

Backlog #90 asks whether every STG/TFM table name mirrors the FBDI CSV tab
(record type) it loads. The rule is "one object = one FBDI zip = one tab per
record type". The Items object is the Item Import FBDI: **one zip carrying TWO
CSVs** — the item master and its categories — submitted under one import job
(`ItemImportJobDef`). Item Categories is therefore a *tab of the Items zip*, not
a separate zip (confirmed by the generator body and the 2026-05-21 ESS-discovery
note: `ItemCategoryImportJobDef` is not standalone). The catalog lists both
record types ("Item Master", "Item Categories") under the single `Items` CEMLI.

**The mapping (from `DMT_EGP_ITEM_FBDI_GEN_PKG` + `DMT_EGP_ITEM_CAT_FBDI_GEN_PKG` + the two `.ctl`):**

| FBDI tab / CSV | Interface table | Source STG table | Source TFM table | Verdict |
|---|---|---|---|---|
| EgpSystemItemsInterface.csv | EGP_SYSTEM_ITEMS_INTERFACE | DMT_EGP_ITEM_STG_TBL | DMT_EGP_ITEM_TFM_TBL | ALIGNED |
| EgpItemCategoriesInterface.csv | EGP_ITEM_CATEGORIES_INTERFACE | DMT_EGP_ITEM_CAT_STG_TBL | DMT_EGP_ITEM_CAT_TFM_TBL | ALIGNED |

Both record types map 1:1 to their own STG/TFM pair, and each DMT name is the
`DMT_` + Fusion-interface-root form (`EGP_ITEM` ↔ EGP_SYSTEM_ITEMS_INTERFACE,
`EGP_ITEM_CAT` ↔ EGP_ITEM_CATEGORIES_INTERFACE). No misalignment.

**Findings:**
1. **FIXED (doc-only):** the generator spec/body header of
   `dmt_egp_item_fbdi_gen_pkg` said the Items zip holds "ONE CSV:
   EgpSystemItemsInterface.csv". The zip actually bundles TWO CSVs — the item
   master plus the categories CSV produced by
   `DMT_EGP_ITEM_CAT_FBDI_GEN_PKG.GENERATE_CSV` — under the one import job.
   Header corrected to list both. No runtime change.
2. **No physical rename needed** — both tables already mirror their tab.
