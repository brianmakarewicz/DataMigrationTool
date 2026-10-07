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

## Upload poll timeout and job-level errors (2026-10-07)
The load step (`DMT_FND_VS_RESULTS_PKG.LOAD_VIA_FBDI`) never marks a row FAILED. When the
upload ESS job is still running after DMT's 1800-second poll window, the poll returns
EXPIRED. That is DMT's own timeout, not a Fusion state, so the rows are left for base-table
reconciliation and any row not found there ends UNACCOUNTED (Fusion's own state is written
to the log). A Fusion terminal ERROR on the upload job is a job-level outcome with no
per-row Fusion message in this step, so it is logged and handled the same way. PR #591
(2026-10-06) stamped every row `[LOAD_ERROR] ... did not finish within DMT's 1800s poll
window ...` and marked it FAILED; that was a composed sentence, not a Fusion error, and was
removed. Outcomes are no longer copied back to the staging tables.
