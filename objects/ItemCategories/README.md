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
- Results/Reconciliation: `DMT_EGP_ITEM_RESULTS_PKG.APPLY_CONTRACT_V1_ITEMS` (record type ItemCategory). The separate `DMT_EGP_ITEM_CAT_RESULTS_PKG` was dropped (backlog #607).
- Runner (standalone dev/test): `packages/runners/dmt_egp_item_cat_runner_pkg`
- Loader wiring: Categories validation/transform runs as part of `RUN_ITEMS` — no separate `RUN_ITEM_CATEGORIES` ESS submission

## Pipeline Configuration
- CEMLI Code: `ItemCategories`
- Orchestration: P2P (processed within Items step — Items + Categories in one ZIP)
- UCM Account: pim/import (same as Items)
- ESS Job: `ItemImportJobDef` (bundled — see Items README for 7-arg ParameterList)
- ParameterList: N/A — uses Items ParameterList

## Reconciliation
Item categories reconcile through the Items report V3 (`/Custom/DMT2/Items/DMT_ITEM_RECON_V3_DM.xdm`, record type ItemCategory), which finds rows by the work item's Fusion job ids. Registry row 100000026 names that report. The old `ITEM_CAT_DM` / `ITEM_CAT_RPT` pair is retired (backlog #480) and its repo copies were removed (backlog #607); the Fusion catalog copies are left in place.

Reconciliation runs after the combined Items ESS job completes — Items reconciled first, then Categories.

## Status
BUNDLED WITH ITEMS. Packages built. FBDI generator produces CSV that is included in the Items ZIP.
BIP artifacts created. GOOD category assignment PROVEN LOADED to the base table live (2026-10-05).

## Target catalog must allow MULTIPLE assignment (EGP-2775085)

The regression GOOD rows target the **eCommerce Catalog** category set
(`category_set_id = 300000047481425`), which is configured
`MULT_ITEM_CAT_ASSIGN_FLAG = 'Y'` (multiple assignment) and has no default category.

Do NOT target the **Purchasing** category set for a GOOD row. Purchasing is
single-assignment (`MULT_ITEM_CAT_ASSIGN_FLAG = 'N'`) AND carries a default category,
so Fusion auto-assigns every newly-created item one Purchasing category at item
creation. A second Purchasing assignment from our run is then rejected with
**EGP-2775085** ("Items cannot be assigned to multiple categories for this catalog
because the catalog is configured for single assignment"). That is a real Fusion
functional rule, not a DMT bug. Use a multiple-assignment catalog (eCommerce Catalog,
UNSPSC, Fashion Catalog, Product Lines, etc.) for GOOD category test rows.

### Live base-table proof (run 228, 2026-10-05, scm_impl)
Scenario `RegressionTest2610051423`, prefixes 93282/93283. Direct read of the base
table `EGP_ITEM_CATEGORIES` (not our reconcile):

| Item (prefixed) | Category set | Category code | ITEM_CATEGORY_ASSIGNMENT_ID |
|---|---|---|---|
| 93283DMT-RT-PLAIN-001 | eCommerce Catalog | Canned_Fruit | 300000334887345 |
| 93282DMT-RT-SERIAL-001 | eCommerce Catalog | Industrial | 300000334887373 |

Both rows are physically present in `EGP_ITEM_CATEGORIES` under
`category_set_id = 300000047481425`. The BAD row (NONEXISTENT-DMT-ITEM / FAKE_SET /
ZZZ) was correctly rejected in the interface (process_status = 3) and is absent from
the base table.

## History
- DDL deployed initially.
- 2026-05-21: All packages built (validator, transformer, FBDI gen, results, runner).
- 2026-05-21: Wired into dmt_loader_pkg + dmt_scheduler_pkg P2P sequence.
  Added BIP reconciliation (RECONCILE_BATCH) to results package.
- 2026-05-21: ESS discovery confirmed ItemCategoryImportJobDef is NOT standalone.
  Redesigned to bundle with Items in single ZIP under ItemImportJobDef.
- 2026-10-05: GOOD category assignment PROVEN loaded to base table. Root-caused the
  blanket Item Categories failure to EGP-2775085 (single-assignment Purchasing catalog
  collides with the auto-assigned default). Retargeted the regression GOOD rows to the
  eCommerce Catalog category set (multiple-assignment). Live run 228 landed two GOOD
  assignments in EGP_ITEM_CATEGORIES (assignment ids 300000334887345, 300000334887373);
  BAD row correctly rejected.

## Table-name vs FBDI-tab audit (backlog #90, 2026-10-01)

Backlog #90 asks whether every STG/TFM table name mirrors the FBDI CSV tab
(record type) it loads. The rule is "one object = one FBDI zip = one tab per
record type". **Item Categories is not a standalone zip** — it is the *second
CSV tab of the Items zip* (Item Import, `ItemImportJobDef`). ESS discovery on
2026-05-21 confirmed `ItemCategoryImportJobDef` is not standalone, so the
categories CSV is generated by `DMT_EGP_ITEM_CAT_FBDI_GEN_PKG.GENERATE_CSV` and
bundled into the Items zip. In the catalog both record types ("Item Master",
"Item Categories") sit under the one `Items` CEMLI; see objects/Items/README.md
for the full two-tab audit.

**The mapping (from `DMT_EGP_ITEM_CAT_FBDI_GEN_PKG` + `EgpItemCategoriesInterface.ctl`):**

| FBDI tab / CSV | Interface table | Source STG table | Source TFM table | Verdict |
|---|---|---|---|---|
| EgpItemCategoriesInterface.csv | EGP_ITEM_CATEGORIES_INTERFACE | DMT_EGP_ITEM_CAT_STG_TBL | DMT_EGP_ITEM_CAT_TFM_TBL | ALIGNED |

The `DMT_EGP_ITEM_CAT` name mirrors the `EGP_ITEM_CATEGORIES_INTERFACE` root
(`CAT` = Categories). No misalignment, no rename needed.

**Finding:** the `DMT_EGP_ITEM_CAT_FBDI_GEN_PKG` spec already documents the CSV
and interface table correctly (`GENERATE_FBDI` is marked legacy; the live path
is `GENERATE_CSV`, bundled by the Items generator). No spec-header fix required
here; the sibling fix is recorded in objects/Items/README.md.
