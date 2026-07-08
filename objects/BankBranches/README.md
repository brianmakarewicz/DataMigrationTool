# Bank Branches

## Overview
Bank branch records within the Cash Management bank hierarchy. Each branch belongs to a parent bank and can itself be a parent to bank accounts.

## Load Method
REST API
- Endpoint: Child resource of `fscmRestApi/resources/.../cashBanks`
- Pipeline: REST pipeline

## Parent/Child
- Parent: Banks
- Linkage: SOURCE_GROUP_ID (links to parent Bank); SOURCE_LINE_ID (links to grandchild BankAccounts)

## Staging Tables
- STG: `DMT_BANK_BRANCHES_STG_TBL`
- TFM: `DMT_BANK_BRANCHES_TFM_TBL`

## Key Columns
- BRANCH_NAME
- BRANCH_NUMBER
- BIC_CODE

## Reconciliation
REST response — success or failure determined directly from the API response payload for each record.

## Status
NOT BUILT — DDL deployed, pipeline packages not yet created.
