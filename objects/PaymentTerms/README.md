# PaymentTerms

## Overview
AP Payment Terms header definitions that specify standard payment conditions (Net 30, 2/10 Net 30, etc.) used on invoices and purchase orders. Must be created before PaymentTermLines.

## Load Method
REST API
- Endpoint: `fscmRestApi/resources/11.13.18.05/standardTerms`
- Pipeline: REST pipeline (POST per record)

## Parent/Child
- Parent: None (standalone, acts as parent for PaymentTermLines)
- Linkage: N/A

## Staging Tables
- STG: `DMT_PAY_TERMS_STG_TBL`
- TFM: `DMT_PAY_TERMS_TFM_TBL`

## Key Columns
- NAME
- PAY_TERM_TYPE
- ENABLED_FLAG
- DESCRIPTION
- START_DATE_ACTIVE

## Reconciliation
REST response: HTTP 201 = LOADED, HTTP 4xx/5xx = FAILED. Fusion-assigned TermId captured from response payload for child linkage.

## Status
NOT BUILT — DDL deployed, pipeline packages not yet created.
