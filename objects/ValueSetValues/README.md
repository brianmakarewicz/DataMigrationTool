# ValueSetValues

## Overview
Individual values within a Flexfield Value Set. Each value belongs to a parent Value Set and carries attributes like description, enabled flag, and effective dates. Loaded after ValueSets are established.

## Load Method
FBL (File-Based Loader)
- Endpoint/Template: ValueSetValues FBL template
- Pipeline: FBL pipeline

## Parent/Child
- Parent: ValueSets
- Linkage: SOURCE_GROUP_ID links values to their parent Value Set definition

## Staging Tables
- STG: `DMT_VALUE_SET_VALUES_STG_TBL`
- TFM: `DMT_VALUE_SET_VALUES_TFM_TBL`

## Key Columns
- VALUE_SET_CODE
- VALUE
- DESCRIPTION
- ENABLED_FLAG
- EFFECTIVE_START_DATE

## Reconciliation
FBL import ESS job response. Verify values exist in Fusion by querying the value set values API or BIP report post-load.

## Status
NOT BUILT — DDL deployed, pipeline packages not yet created.
