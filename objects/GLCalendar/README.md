# GLCalendar

## Overview
Accounting calendar period definitions that control which periods are open for journal entry and financial reporting. Migrated to establish the fiscal calendar structure in Fusion before any transactional data is loaded.

## Load Method
FBL (File-Based Loader)
- Endpoint/Template: AccountingCalendar FBDI template
- Pipeline: Standard FBDI pipeline

## Parent/Child
- Parent: None (standalone)
- Linkage: PERIOD_SET_NAME groups all periods belonging to a single calendar

## Staging Tables
- STG: `DMT_GL_CALENDAR_STG_TBL`
- TFM: `DMT_GL_CALENDAR_TFM_TBL`

## Key Columns
- PERIOD_SET_NAME
- PERIOD_NAME
- START_DATE
- END_DATE
- PERIOD_TYPE

## Reconciliation
FBL import ESS job response. BIP query against GL_PERIOD_STATUSES to confirm periods exist with correct dates.

## Status
NOT BUILT — DDL deployed, pipeline packages not yet created.
