# Banks

## Overview
Cash Management bank records representing financial institutions. This is the top level of a three-level hierarchy: Bank > Branch > Account.

## Load Method
REST API
- Endpoint: `fscmRestApi/resources/.../cashBanks`
- Pipeline: REST pipeline

## Parent/Child
- Parent: None (standalone, top of hierarchy)
- Linkage: N/A (parent to BankBranches via SOURCE_GROUP_ID)

## Staging Tables
- STG: `DMT_BANKS_STG_TBL`
- TFM: `DMT_BANKS_TFM_TBL`

## Key Columns
- BANK_NAME
- BANK_NUMBER
- COUNTRY_CODE

## Reconciliation
REST response — success or failure determined directly from the API response payload for each record.

## Status
NOT BUILT — DDL deployed, pipeline packages not yet created.
