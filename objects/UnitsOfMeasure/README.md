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

## Reconciliation
FBL/FBDI import ESS job response. BIP query against INV_UNITS_OF_MEASURE to confirm UOM codes exist with correct class assignments.

## Status
NOT BUILT — DDL deployed, pipeline packages not yet created.
