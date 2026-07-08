# PaymentTermLines

## Overview
Payment term installment lines that define the payment schedule within a parent Payment Term, including due percentages, due days, and early payment discount terms.

## Load Method
REST API
- Endpoint: `fscmRestApi/resources/11.13.18.05/standardTerms/{TermId}/child/lines`
- Pipeline: REST pipeline (child resource POST, requires parent TermId)

## Parent/Child
- Parent: PaymentTerms
- Linkage: SOURCE_GROUP_ID links installment lines to their parent Payment Term

## Staging Tables
- STG: `DMT_PAY_TERM_LINES_STG_TBL`
- TFM: `DMT_PAY_TERM_LINES_TFM_TBL`

## Key Columns
- SEQUENCE_NUM
- DUE_PERCENT
- DUE_DAYS
- DISCOUNT_PERCENT
- DISCOUNT_DAYS

## Reconciliation
REST response: HTTP 201 = LOADED, HTTP 4xx/5xx = FAILED. Each line validated against parent term's Fusion TermId.

## Status
NOT BUILT — DDL deployed, pipeline packages not yet created.
