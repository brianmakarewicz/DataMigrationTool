# ValueSets

## Overview
Flexfield Value Set definitions that define validation rules, format types, and value constraints used by key and descriptive flexfields throughout Fusion. Must be migrated before the values themselves.

## Load Method
FBL (File-Based Loader)
- Endpoint/Template: ValueSet FBL template
- Pipeline: FBL pipeline

## Parent/Child
- Parent: None (standalone, acts as parent for ValueSetValues)
- Linkage: N/A

## Staging Tables
- STG: `DMT_VALUE_SETS_STG_TBL`
- TFM: `DMT_VALUE_SETS_TFM_TBL`

## Key Columns
- VALUE_SET_CODE
- VALIDATION_TYPE
- VALUE_DATA_TYPE
- MAXIMUM_VALUE_LENGTH
- MODULE_KEY

## Reconciliation
FBL import ESS job response. Success determined by ESS job completion status and absence of error rows in the import log.

## Status
NOT BUILT — DDL deployed, pipeline packages not yet created.

## Run prefix (2026-10-06)
The transform applies the run prefix to `VALUE_SET_CODE` (Fusion limit 60) on the set row
and on each value's parent `VALUE_SET_CODE`. A code that cannot carry the full prefix is not
truncated; the row is FAILED with a `[TRANSFORM_ERROR]` naming the limit.
