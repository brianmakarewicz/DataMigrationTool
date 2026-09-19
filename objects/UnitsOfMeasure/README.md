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
- Match: config UOM codes are 3 chars and are NOT run-prefixed, so the reconciler
  passes the run's exact codes as the comma-delimited parameter `P_UOM_CODES`; the
  report matches on `UOM_CODE` with a comma-boundary `INSTR`.
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
