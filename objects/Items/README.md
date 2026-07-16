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
- Default ParameterList: `BATCH_ID,null,CREATE,Y,ORA_ER,N,Y`
- Discovery: Request ID 9542220, fin_impl, 2026-05-21
- Note: Item Categories (EgpItemCategoriesImportTemplate.csv) loads in the same ZIP — not a separate ESS job

## FBDI ZIP Contents
This job bundles two CSVs in one ZIP:
1. `EgpItemImportTemplate.csv` — items (EGP_SYSTEM_ITEMS_INTERFACE)
2. `EgpItemCategoriesImportTemplate.csv` — item categories (EGP_ITEM_CATEGORIES_INTERFACE)

Both are submitted under `ItemImportJobDef` in a single ESS call.

## Reconciliation
BIP report at `/Custom/DMT/Items/ITEM_DM.xdm`.
Queries `EGP_SYSTEM_ITEMS_INTERFACE` by BATCH_ID.
Match key: ITEM_NUMBER + ORGANIZATION_CODE.
PROCESS_FLAG null/0 = success, 7 = error.

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
- DDL deployed initially.
- 2026-05-21: All packages built (validator, transformer, FBDI gen, results, runner).
- 2026-05-21: Wired into dmt_loader_pkg + dmt_scheduler_pkg P2P sequence.
  Added BIP reconciliation (RECONCILE_BATCH) to results package.
