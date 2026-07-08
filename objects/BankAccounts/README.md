# Bank Accounts

## Overview
Cash Management bank account records at the bottom of the three-level bank hierarchy. Each account is linked to both a parent bank and a parent branch.

## Load Method
REST API
- Endpoint: `fscmRestApi/resources/.../cashBankAccounts`
- Pipeline: REST pipeline

## Parent/Child
- Parent: BankBranches (and grandparent Banks)
- Linkage: SOURCE_GROUP_ID (links to Bank), SOURCE_LINE_ID (links to Branch)

## Staging Tables
- STG: `DMT_BANK_ACCOUNTS_STG_TBL`
- TFM: `DMT_BANK_ACCOUNTS_TFM_TBL`

## Key Columns
- ACCOUNT_NAME
- ACCOUNT_NUMBER
- CURRENCY_CODE
- LEGAL_ENTITY_NAME

## Reconciliation
REST response — success or failure determined directly from the API response payload for each record.

## Status
NOT BUILT — DDL deployed, pipeline packages not yet created.
