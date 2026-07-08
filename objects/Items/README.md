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

## History
- DDL deployed initially.
- 2026-05-21: All packages built (validator, transformer, FBDI gen, results, runner).
- 2026-05-21: Wired into dmt_loader_pkg + dmt_scheduler_pkg P2P sequence.
  Added BIP reconciliation (RECONCILE_BATCH) to results package.
