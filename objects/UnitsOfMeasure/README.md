# UnitsOfMeasure

## Overview
Units of Measure definitions used across procurement, inventory, and order management. Each UOM belongs to a UOM class, and one UOM per class is designated as the base unit for conversions.

## Load Method
FBL (File-Based Loader) / FBDI
- Endpoint/Template: UnitOfMeasure FBDI template
- Pipeline: Standard FBDI pipeline

## Parent/Child
- Parent: None (standalone)
- Linkage: UOM_CLASS groups related units; BASE_UOM_FLAG=Y identifies the class base unit

## Staging Tables
- STG: `DMT_UOM_STG_TBL`
- TFM: `DMT_UOM_TFM_TBL`

## Key Columns
- UOM_CODE
- UOM_CLASS
- UNIT_OF_MEASURE
- BASE_UOM_FLAG
- DESCRIPTION

## Load Method (actual)
REST POST to the `unitsOfMeasure` resource (`/fscmRestApi/resources/11.13.18.05/unitsOfMeasure`),
one call per UOM. Not FBDI/ESS. Driven by `DMT_INV_UOM_RESULTS_PKG.LOAD_AND_RECONCILE`.

## Reconciliation (new base-table standard)
Reconciliation is a BIP report over the Fusion **base table**, not the REST response.
A load-call HTTP 200 is NOT reconciliation.

- Report: `/Custom/DMT2/UnitsOfMeasure/DMT_UOM_RECON_RPT.xdo` (data model
  `DMT_UOM_RECON_DM.xdm`), registered in `DMT_BIP_REPORT_TBL` under CEMLI_CODE
  `UnitsOfMeasure` (BIP_REPORT_ID 100000041). Mirror SQL: `bip/UnitsOfMeasure/query.sql`.
- Base table: `INV_UNITS_OF_MEASURE_B`. Surrogate id: `UNIT_OF_MEASURE_ID`
  (== the REST `UOMId`), written to `DMT_INV_UOM_TFM_TBL.FUSION_UOM_ID`.
- Match: the reconciler passes the run's exact TFM codes (the run-prefixed form, see
  below) as the comma-delimited parameter `P_UOM_CODES`; the report matches on
  `UOM_CODE` with a comma-boundary `INSTR`.

## Run prefix (2026-10-06, owner decision)
Like every other DMT data object, UnitsOfMeasure applies the run prefix to its
user-facing unique keys so the scenario can be re-loaded run after run.
- **UOM name** (`UNIT_OF_MEASURE`, Fusion limit 25) carries the full prefix:
  `DMT2 Test Dozen8` with prefix 93300 becomes `93300DMT2 Test Dozen8`.
- **UOM code** is limited to **3 characters** in Fusion (unitsOfMeasure REST describe:
  `UOMCode` maxLength 3; every code in `INV_UNITS_OF_MEASURE_B` is 1-3 chars), so the
  5-digit prefix cannot be prepended and must not be truncated into a collision.
  The transform derives the code deterministically with
  `DMT_INV_UOM_TRANSFORM_PKG.DERIVE_UOM_CODE(prefix, ordinal, source_code)`:
  `n = MOD(prefix*4 + ordinal-1, 8*1296)`, code = one lead digit from `12345679`
  (digits no seeded Fusion UOM code starts with; the pod only has codes starting 0 and
  8) followed by two base-36 characters. Unique within a run for up to 10,368 UOMs, and
  unique across runs while a run carries at most 4 UOMs (the code space wraps after
  2,592 prefixes). Past those bounds a collision is never silent: Fusion rejects the
  duplicate code and the row is FAILED with that real error. With no prefix
  (production cutover) the source code is used unchanged.
- A name that cannot carry the full prefix within 25 characters is not truncated; the
  row is recorded FAILED with a `[TRANSFORM_ERROR]` naming the limit.
- Before/after example: STG `UOM_CODE='DZ8'`, `UNIT_OF_MEASURE='DMT2 Test Dozen8'`,
  prefix 93292 → TFM `UOM_CODE='9XS'` (derived), `UNIT_OF_MEASURE='93292DMT2 Test Dozen8'`;
  the reconciler queries `INV_UNITS_OF_MEASURE_B` for `9XS`.
- Verdicts: a code found in the base table -> LOADED with FUSION_UOM_ID = the real
  UNIT_OF_MEASURE_ID. A code not found -> FAILED on the real REST rejection stashed
  at load time; if there is no stashed error the row is left GENERATED (unaccounted),
  never a fabricated verdict. The REST POST is the LOAD step only; the base-table
  report is the sole authority for LOADED.

Known limitation: Fusion gzip-compresses some REST error bodies, so a BAD row's
ERROR_TEXT can be a compressed (real) HTTP 400 rather than plain text. The rejection
is genuine; making it human-readable needs a shared gzip-decode in the REST transport
(applies to all REST config objects), tracked separately.

## Status
BUILT and proven end-to-end on local Docker (2026-09-19). GOOD row 'DZ8' LOADED with
FUSION_UOM_ID 300000333812175 (real base-table id); BAD row 'DZ7' (nonexistent class)
FAILED with a real Fusion HTTP 400; zero unaccounted. Regression VERDICT: PASS (run 275).
Proof-of-recipe for converting the other five REST config objects.
