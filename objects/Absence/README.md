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
