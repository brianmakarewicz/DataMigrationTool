# TaxRates

## Overview
Tax rate definitions within a tax regime, specifying the percentage rate applied to transactions. Each rate is tied to a parent Tax Regime and carries effective dating for rate changes over time.

## Load Method
REST API
- Endpoint: `fscmRestApi/resources/11.13.18.05/taxRegimes/{TaxRegimeId}/child/taxRates`
- Pipeline: REST pipeline (child resource POST, requires parent TaxRegimeId)

## Parent/Child
- Parent: TaxRegimes
- Linkage: SOURCE_GROUP_ID links tax rates to their parent Tax Regime

## Staging Tables
- STG: `DMT_TAX_RATES_STG_TBL`
- TFM: `DMT_TAX_RATES_TFM_TBL`

## Key Columns
- TAX_RATE_CODE
- PERCENTAGE_RATE
- EFFECTIVE_FROM
- ACTIVE_FLAG
- DESCRIPTION

## Reconciliation
REST response: HTTP 201 = LOADED, HTTP 4xx/5xx = FAILED. Each rate validated against parent regime's Fusion TaxRegimeId.

## Status
NOT BUILT — DDL deployed, pipeline packages not yet created.
