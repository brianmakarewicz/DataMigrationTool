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
