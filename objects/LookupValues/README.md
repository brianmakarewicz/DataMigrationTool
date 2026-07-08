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
