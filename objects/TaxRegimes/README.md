# TaxRegimes

## Overview
Tax regime configuration that defines the top-level tax authority structure by country. Regimes establish the legal framework under which taxes, tax statuses, and tax rates are organized in Fusion Tax.

## Load Method
REST API
- Endpoint: `fscmRestApi/resources/11.13.18.05/taxRegimes`
- Pipeline: REST pipeline (POST per record)

## Parent/Child
- Parent: None (standalone, acts as parent for TaxRates)
- Linkage: N/A

## Staging Tables
- STG: `DMT_TAX_REGIMES_STG_TBL`
- TFM: `DMT_TAX_REGIMES_TFM_TBL`

## Key Columns
- TAX_REGIME_CODE
- COUNTRY_CODE
- EFFECTIVE_FROM
- REGIME_TYPE
- DESCRIPTION

## Reconciliation
REST response: HTTP 201 = LOADED, HTTP 4xx/5xx = FAILED. Fusion-assigned TaxRegimeId captured from response payload for child linkage.

## Status
NOT BUILT — DDL deployed, pipeline packages not yet created.
