# Absence

## Status
BLOCKED (2026-04-04)

## Pipeline
- Module: HCM
- HDL File: PersonAbsenceEntry.dat (NOT AbsenceEntry.dat — the V1 filename)
- Loader Type: HDL (REST upload/submit/poll)
- UCM Account: hcm$/dataloader$/import$
- Auth User: hcm_impl (password: m?CDa6^6)
- **V1 format** — this object uses V1 HDL format, not V2

## Critical Notes
- **DAT filename**: `PersonAbsenceEntry.dat` (not `AbsenceEntry.dat`)
- **Discriminator**: `PersonAbsenceEntry`
- **Attribute name**: `Employer` (V1 attribute name, not `EmployerName`)
- **STG column name**: `EMPLOYER_NAME` (the STG table column is EMPLOYER_NAME)

## BLOCKER: AbsenceStatus
**ALL AbsenceStatus values fail** with error: "conflicting processing and approval statuses"

Values tested (all fail):
- SUBMITTED
- APPROVED
- COMPLETED
- CONFIRMED
- ORA_SUBMITTED
- ORA_APPROVED
- ORA_COMPLETED
- ORA_CONFIRMED
- NULL

This is a Fusion configuration issue on the demo instance. The absence approval workflow configuration conflicts with every status value attempted.

## US Absence Plans (available on demo instance)
- Vacation
- Sick
- Compensatory Time
- Jury Duty
- Bereavement
- FMLA

## Code References
- STG Table DDL: `schema/tables/118_dmt_absence_stg_tbl.sql`
- TFM Table DDL: `schema/tables/119_dmt_absence_tfm_tbl.sql`
- Validator: `packages/validators/dmt_absence_validator_pkg.*`
- Transformer: `packages/transformers/dmt_absence_transform_pkg.*`
- HDL Generator: `packages/generators/hdl/dmt_absence_hdl_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_absence_results_pkg.*`

## Known Good Test Data
None — all records fail due to AbsenceStatus blocker.

## Known Bad Test Data
None verified — cannot distinguish data quality failures from the status blocker.

## Lessons Learned
- This is a V1 format object. The HDL template version matters — V1 and V2 have different filenames, discriminators, and attribute names.
- The DAT filename `PersonAbsenceEntry.dat` is critical. Using `AbsenceEntry.dat` will cause the load to silently fail (0 rows processed).
- The STG table column is `EMPLOYER_NAME`, but the V1 DAT attribute is `Employer` (no "Name" suffix). The HDL generator must map EMPLOYER_NAME -> Employer in the DAT output.
- Until the Fusion instance absence approval workflow is reconfigured, this object cannot be tested E2E.

## History
- 2026-04-04: All AbsenceStatus values tested. Every combination produces "conflicting processing and approval statuses" error. Object marked BLOCKED pending Fusion configuration investigation.

## Minimal test-data plan (2026-07-15)

Goal: add an absence entry to the existing proven worker `RT-WKR-G1` so it loads to the
absence base table (`ANC_PER_ABS_ENTRIES`). NOTE: this object is still BLOCKED — see
prerequisites below. The plan is written so it is ready the moment the blocker clears.

### STG table and required columns
Single table — `DMT_ABSENCE_STG_TBL`. Generator emits (V1 PersonAbsenceEntry discriminator):
SourceSystemOwner (constant HRC_SQLLOADER), SourceSystemId (`PERSON_NUMBER || '_ABS'`),
PersonId(SourceSystemId) (= PERSON_NUMBER), Employer (from EMPLOYER_NAME), AbsenceType,
AbsenceStatus, StartDate, EndDate, StartTime, EndTime, Duration, AbsenceReason, Comments.
Required columns to seed:
- PERSON_NUMBER (FK to the worker) — `RT-WKR-G1`
- EMPLOYER_NAME — `US1 Legal Entity` (the worker's legal employer)
- ABSENCE_TYPE — a real US absence type name (see below)
- ABSENCE_STATUS — see BLOCKER; every value tried fails on this instance
- START_DATE, END_DATE (YYYY/MM/DD strings)
- SOURCE_ID, STG_STATUS='NEW'
- DURATION optional; START_TIME/END_TIME optional for a day-level absence

### Real reference values (confirmed live 2026-07-15, hcm_impl)
- US absence types (`anc_absence_types_vl` WHERE legislation_code='US'): `Vacation`, `Sick`,
  `Bereavement`, `Short Term Disability`, `Long Term Disability`, and more.
- Query: `SELECT name, legislation_code FROM anc_absence_types_vl WHERE legislation_code='US'`.
- Legal employer `US1 Legal Entity` and BU `US1 Business Unit` are the worker's confirmed-live
  references (carried from Workers/Salaries).

### Proposed seed rows (dates as YYYY/MM/DD strings)
GOOD — one absence entry keyed to RT-WKR-G1:
- `DMT_ABSENCE_STG_TBL`: PERSON_NUMBER='RT-WKR-G1', EMPLOYER_NAME='US1 Legal Entity',
  ABSENCE_TYPE='Vacation', ABSENCE_STATUS=(pending blocker resolution — see below),
  START_DATE='2026/03/02', END_DATE='2026/03/03', SOURCE_ID='RT-ABS-G1', STG_STATUS='NEW'.

BAD — distinct record (different date range = different discriminator so no duplicate-line
error); fails on an invalid absence type:
- `DMT_ABSENCE_STG_TBL`: PERSON_NUMBER='RT-WKR-G1', EMPLOYER_NAME='US1 Legal Entity',
  ABSENCE_TYPE='NONEXISTENT ABSENCE TYPE', ABSENCE_STATUS=(same as GOOD),
  START_DATE='2026/04/06', END_DATE='2026/04/07', SOURCE_ID='RT-ABS-B1', STG_STATUS='NEW'.

### Prerequisites / blockers
BLOCKED — this is a Fusion instance configuration blocker, not a data blocker. Every
AbsenceStatus value (SUBMITTED, APPROVED, COMPLETED, CONFIRMED, their ORA_ variants, and NULL)
returns "conflicting processing and approval statuses". Until the demo instance's absence
approval workflow is reconfigured, GOOD rows cannot reach the base table, so Rule #1 cannot be
met. Do NOT seed/run this object for a live pass yet. The worker itself has no absence-plan
prerequisite for a plain absence-type entry; the blocker is purely the approval-status config.
Recommendation: keep BLOCKED; revisit only after the instance absence workflow is fixed, or
table this object behind TalentProfiles and TaxCards.
