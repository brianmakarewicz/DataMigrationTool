# Item Categories

## Overview
Item category assignments that classify inventory items under specific category sets and codes in Fusion Product Information Management.

## Load Method
FBDI — **bundled with Items** (not a standalone ESS job)
- Template: EgpItemCategoriesImportTemplate.xlsm (EGP_ITEM_CATEGORIES_INTERFACE)
- Submitted as part of `ItemImportJobDef` — categories CSV is included in the Items FBDI ZIP
- `ItemCategoryImportJobDef` is NOT exposed as a standalone schedulable job on this Fusion instance

## Parent/Child
- Parent: Items (items must be loaded first — same ESS job processes both)
- Linkage: ITEM_NUMBER + ORGANIZATION_CODE

## Staging Tables
- STG: `DMT_ITEM_CATEGORIES_STG_TBL` (DDL: `schema/tables/192_dmt_egp_item_cat_stg_tbl.sql`)
- TFM: `DMT_ITEM_CATEGORIES_TFM_TBL` (DDL: `schema/tables/193_dmt_egp_item_cat_tfm_tbl.sql`)
- TFM status column: `TFM_STATUS` (not STATUS)

## Key Columns
- ITEM_NUMBER
- ORGANIZATION_CODE
- CATEGORY_SET_NAME
- CATEGORY_CODE

## Code References
- Validator: `packages/validators/dmt_egp_item_cat_validator_pkg`
- Transformer: `packages/transformers/dmt_egp_item_cat_transform_pkg`
- FBDI Generator: `packages/generators/fbdi/inventory/dmt_egp_item_cat_fbdi_gen_pkg`
  - Called by the Items FBDI generator to produce the categories CSV for the combined ZIP
- Results/Reconciliation: `packages/reconciliation/dmt_egp_item_cat_results_pkg`
- Runner (standalone dev/test): `packages/runners/dmt_egp_item_cat_runner_pkg`
- Loader wiring: Categories validation/transform runs as part of `RUN_ITEMS` — no separate `RUN_ITEM_CATEGORIES` ESS submission

## Pipeline Configuration
- CEMLI Code: `ItemCategories`
- Orchestration: P2P (processed within Items step — Items + Categories in one ZIP)
- UCM Account: pim/import (same as Items)
- ESS Job: `ItemImportJobDef` (bundled — see Items README for 7-arg ParameterList)
- ParameterList: N/A — uses Items ParameterList

## Reconciliation
BIP report at `/Custom/DMT/ItemCategories/ITEM_CAT_DM.xdm`.
Queries `EGP_ITEM_CATEGORIES_INTERFACE` by BATCH_ID.
Match key: ITEM_NUMBER + ORGANIZATION_CODE + CATEGORY_SET_NAME.
PROCESS_FLAG null/0 = success, 7 = error.

Reconciliation runs after the combined Items ESS job completes — Items reconciled first, then Categories.

## Status
BUNDLED WITH ITEMS. Packages built. FBDI generator produces CSV that is included in the Items ZIP.
BIP artifacts created. Needs E2E test with real data.

## History
- DDL deployed initially.
- 2026-05-21: All packages built (validator, transformer, FBDI gen, results, runner).
- 2026-05-21: Wired into dmt_loader_pkg + dmt_scheduler_pkg P2P sequence.
  Added BIP reconciliation (RECONCILE_BATCH) to results package.
- 2026-05-21: ESS discovery confirmed ItemCategoryImportJobDef is NOT standalone.
  Redesigned to bundle with Items in single ZIP under ItemImportJobDef.
