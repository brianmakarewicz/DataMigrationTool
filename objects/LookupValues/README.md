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

## Current implementation, run prefix and parent-failed rule (2026-10-06)
The value's parent `LOOKUP_TYPE` carries the same run prefix as the type row; `LOOKUP_CODE`
is unique only within its (now run-unique) type, so it is unchanged. When this run also
sent the parent type and Fusion did not create it, the value is not sent (posting it only
drew a blank-bodied HTTP 404, which left run 236's `DMT2_BAD_LKP/BADVAL` UNACCOUNTED). It is
stamped `[PARENT_FAILED] ... parent lookup type "<type>" was not created in Fusion. Parent
lookup type error: <the type's real Fusion error>` and lands FAILED.
