# LookupValues

## Overview
Individual lookup code values within a Lookup Type. Each value carries a code, display meaning, and enabled flag. Loaded after the parent LookupTypes are established in Fusion.

## Load Method
FBL (File-Based Loader)
- Endpoint/Template: LookupValues FBL template
- Pipeline: FBL pipeline

## Parent/Child
- Parent: LookupTypes
- Linkage: SOURCE_GROUP_ID links values to their parent Lookup Type definition

## Staging Tables
- STG: `DMT_LOOKUP_VALUES_STG_TBL`
- TFM: `DMT_LOOKUP_VALUES_TFM_TBL`

## Key Columns
- LOOKUP_TYPE
- LOOKUP_CODE
- MEANING
- ENABLED_FLAG
- TAG

## Reconciliation
FBL import ESS job response. Verify lookup codes exist in Fusion by querying FND_LOOKUP_VALUES via BIP post-load.

## Status
NOT BUILT — DDL deployed, pipeline packages not yet created.

## Current implementation, run prefix and parent-not-created rule (revised 2026-10-07)
The value's parent `LOOKUP_TYPE` carries the same run prefix as the type row; `LOOKUP_CODE`
is unique only within its (now run-unique) type, so it is unchanged. When this run also
sent the parent type and Fusion did not create it, the value is not sent (posting it only
draws a blank-bodied HTTP 404 with no message). Fusion returns no error for the value, so no
error text is written and it ends UNACCOUNTED. The 2026-10-06 `[PARENT_FAILED]` stamp was a
composed sentence, not a Fusion error, and was removed; quoting the parent type's real error
in the shared cross-grain format waits for `DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR`.
