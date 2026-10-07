# LookupTypes

## Overview
Lookup Type definitions that serve as containers for sets of lookup codes used across Fusion modules. These define the lookup category, module association, and meaning before individual values are loaded.

## Load Method
FBL (File-Based Loader)
- Endpoint/Template: LookupType FBL template
- Pipeline: FBL pipeline

## Parent/Child
- Parent: None (standalone, acts as parent for LookupValues)
- Linkage: N/A

## Staging Tables
- STG: `DMT_LOOKUP_TYPES_STG_TBL`
- TFM: `DMT_LOOKUP_TYPES_TFM_TBL`

## Key Columns
- LOOKUP_TYPE
- MEANING
- MODULE_TYPE
- MODULE_KEY
- CUSTOMIZATION_LEVEL

## Reconciliation
FBL import ESS job response. Success determined by ESS job completion status and absence of error rows in the import log.

## Status
NOT BUILT — DDL deployed, pipeline packages not yet created.

## Current implementation and run prefix (2026-10-06)
Lookups (CEMLI `Lookups`) is REST-loaded (`standardLookups`) by `DMT_FND_LOOKUP_RESULTS_PKG`
and reconciled against `FND_LOOKUP_TYPES` / `FND_LOOKUP_VALUES_B`. The transform applies the
run prefix to `LOOKUP_TYPE` (Fusion limit 30) and to the type `MEANING` (limit 80): the
meaning is also unique among lookup types, and run 236's GOOD type `CONTACT` failed because
both already existed. Example: `CONTACT` / `Contact` with prefix 93300 becomes
`93300CONTACT` / `93300Contact`. A key that cannot carry the full prefix is not truncated;
the row is FAILED with a `[TRANSFORM_ERROR]` naming the limit.
